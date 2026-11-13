-- Phase 7. Run after 202611120001_phase6c.sql. Re-runnable; preserves progress.
begin;
alter table public.user_stats add column if not exists longest_streak integer not null default 0 check (longest_streak >= 0);
alter table public.word_progress add column if not exists deleted boolean not null default false;
-- Preserve the best streak known before daily history became available.
update public.user_stats set longest_streak = streak, updated_at = updated_at + interval '1 microsecond'
  where streak > longest_streak;

create table if not exists public.daily_activity (
  user_id uuid not null references auth.users(id) on delete cascade,
  activity_date date not null,
  xp integer not null default 0 check (xp >= 0),
  updated_at timestamptz not null default 'epoch',
  sync_version bigint not null default 0,
  primary key (user_id, activity_date)
);
alter table public.daily_activity enable row level security;
revoke all on public.daily_activity from anon;
grant select, insert, update, delete on public.daily_activity to authenticated;
drop policy if exists own_activity on public.daily_activity;
create policy own_activity on public.daily_activity for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create index if not exists daily_activity_sync_revision on public.daily_activity (user_id, sync_version);
create index if not exists daily_activity_sync_timestamp on public.daily_activity (user_id, updated_at);
drop trigger if exists guard_progress_write on public.daily_activity;
create trigger guard_progress_write before insert or update on public.daily_activity
  for each row execute function public.guard_progress_write();

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
      select updated_at, sync_version from public.daily_activity where user_id = uid
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
    'words', coalesce((select jsonb_agg(to_jsonb(r) order by word_id) from public.word_progress r
      where user_id = uid and (updated_at > p_since or sync_version > p_after_version)), '[]'::jsonb)
  ) into result;
  return result;
end $$;
revoke all on function public.pull_progress(timestamptz, bigint) from public, anon;
grant execute on function public.pull_progress(timestamptz, bigint) to authenticated;
notify pgrst, 'reload schema';
commit;
