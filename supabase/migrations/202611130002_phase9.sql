-- Phase 9. Apply after Phase 6C and Phase 7. Re-runnable, preserves existing data.
begin;
create table if not exists public.saved_words (
  user_id uuid not null references auth.users(id) on delete cascade,
  word_id text not null check (length(word_id) between 1 and 128),
  course_id text not null check (length(course_id) between 1 and 128),
  text text not null check (length(text) between 1 and 100),
  translation text not null check (length(translation) between 1 and 150),
  example text not null check (length(example) between 1 and 300),
  example_translation text not null check (length(example_translation) between 1 and 300),
  deleted boolean not null default false,
  updated_at timestamptz not null default 'epoch',
  sync_version bigint not null default 0,
  primary key (user_id, word_id)
);
alter table public.saved_words enable row level security;
revoke all on public.saved_words from anon;
grant select, insert, update, delete on public.saved_words to authenticated;
drop policy if exists own_saved_words on public.saved_words;
create policy own_saved_words on public.saved_words for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create index if not exists saved_words_sync_revision on public.saved_words(user_id,sync_version);
create index if not exists saved_words_sync_timestamp on public.saved_words(user_id,updated_at);
drop trigger if exists guard_progress_write on public.saved_words;
create trigger guard_progress_write before insert or update on public.saved_words
  for each row execute function public.guard_progress_write();

-- Atomic per-user limits, shared by all Edge Function instances. No client writes.
create table if not exists public.chat_rate_limits (
  user_id uuid primary key references auth.users(id) on delete cascade,
  minute_start timestamptz not null,
  minute_count integer not null default 0,
  day_start timestamptz not null,
  day_count integer not null default 0
);
alter table public.chat_rate_limits enable row level security;
revoke all on public.chat_rate_limits from public, anon, authenticated;
create or replace function public.take_chat_slot() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  uid uuid := auth.uid();
  instant timestamptz := clock_timestamp();
  minute_boundary timestamptz := date_trunc('minute', instant);
  day_boundary timestamptz := date_trunc('day', instant at time zone 'UTC') at time zone 'UTC';
  limiter public.chat_rate_limits;
  allowed boolean;
  retry integer;
begin
  if uid is null then raise exception 'Sign in required' using errcode = '42501'; end if;
  insert into public.chat_rate_limits(user_id,minute_start,day_start)
    values(uid,minute_boundary,day_boundary) on conflict(user_id) do nothing;
  select * into limiter from public.chat_rate_limits where user_id=uid for update;
  if limiter.minute_start <> minute_boundary then limiter.minute_count := 0; end if;
  if limiter.day_start <> day_boundary then limiter.day_count := 0; end if;
  allowed := limiter.minute_count < 10 and limiter.day_count < 100;
  retry := case when limiter.day_count >= 100 then
    ceil(extract(epoch from day_boundary + interval '1 day' - instant))::integer
    else ceil(extract(epoch from minute_boundary + interval '1 minute' - instant))::integer end;
  update public.chat_rate_limits set minute_start=minute_boundary, day_start=day_boundary,
    minute_count=limiter.minute_count + case when allowed then 1 else 0 end,
    day_count=limiter.day_count + case when allowed then 1 else 0 end where user_id=uid;
  return jsonb_build_object('allowed',allowed,'retry_after',greatest(1,retry));
end $$;
revoke all on function public.take_chat_slot() from public, anon;
grant execute on function public.take_chat_slot() to authenticated;

create or replace function public.pull_progress(
  p_since timestamptz default 'epoch', p_after_version bigint default 0
) returns jsonb language plpgsql security invoker set search_path = '' as $$
declare uid uuid := auth.uid(); result jsonb; boundary bigint; stamp timestamptz;
begin
  if uid is null then raise exception 'Sign in required' using errcode = '42501'; end if;
  if p_since is null or p_since < timestamptz 'epoch' or p_after_version is null or p_after_version < 0 then
    raise exception 'Invalid sync cursor' using errcode = '22023';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(uid::text, 0));
  select greatest(p_after_version, coalesce(max(sync_version), 0)),
         greatest(p_since, coalesce(max(updated_at), timestamptz 'epoch'))
    into boundary, stamp from (
      select updated_at, sync_version from public.saved_words where user_id = uid
      union all select updated_at, sync_version from public.daily_activity where user_id = uid
      union all select updated_at, sync_version from public.profiles where user_id = uid
      union all select updated_at, sync_version from public.user_stats where user_id = uid
      union all select updated_at, sync_version from public.lesson_progress where user_id = uid
      union all select updated_at, sync_version from public.word_progress where user_id = uid
    ) as versions;
  select jsonb_build_object(
    'schema_version', 2, 'user_id', uid, 'last_synced_at', stamp, 'revision', boundary,
    'profile', (select to_jsonb(r) from public.profiles r where user_id = uid
      and (updated_at > p_since or sync_version > p_after_version)),
    'stats', (select to_jsonb(r) from public.user_stats r where user_id = uid
      and (updated_at > p_since or sync_version > p_after_version)),
    'lessons', coalesce((select jsonb_agg(to_jsonb(r) order by lesson_id) from public.lesson_progress r
      where user_id = uid and (updated_at > p_since or sync_version > p_after_version)), '[]'::jsonb),
    'activities', coalesce((select jsonb_agg(to_jsonb(r) order by activity_date) from public.daily_activity r
      where user_id = uid and (updated_at > p_since or sync_version > p_after_version)), '[]'::jsonb),
    'saved_words', coalesce((select jsonb_agg(to_jsonb(r) order by word_id) from public.saved_words r
      where user_id = uid and (updated_at > p_since or sync_version > p_after_version)), '[]'::jsonb),
    'words', coalesce((select jsonb_agg(to_jsonb(r) order by word_id) from public.word_progress r
      where user_id = uid and (updated_at > p_since or sync_version > p_after_version)), '[]'::jsonb)
  ) into result;
  return result;
end $$;
revoke all on function public.pull_progress(timestamptz, bigint) from public, anon;
grant execute on function public.pull_progress(timestamptz, bigint) to authenticated;
notify pgrst, 'reload schema';
commit;
