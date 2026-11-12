-- PHASE 6C: run this ONE script in Supabase SQL Editor.
-- Supports both a fresh project and the previous Phase 6A schema; preserves rows.
-- Old app builds using sync_progress must be upgraded together with this schema.
begin;

create table if not exists public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '' check (length(display_name) <= 120),
  updated_at timestamptz not null default now()
);
create table if not exists public.user_stats (
  user_id uuid primary key references auth.users(id) on delete cascade,
  xp bigint not null default 0 check (xp >= 0),
  streak integer not null default 0 check (streak >= 0),
  last_active_date timestamptz,
  updated_at timestamptz not null default 'epoch'
);
create table if not exists public.lesson_progress (
  user_id uuid not null references auth.users(id) on delete cascade,
  lesson_id text not null check (length(lesson_id) > 0),
  completed boolean not null default false,
  best_score integer not null default 0 check (best_score between 0 and 100),
  completed_at timestamptz,
  updated_at timestamptz not null default 'epoch',
  primary key (user_id, lesson_id)
);
create table if not exists public.word_progress (
  user_id uuid not null references auth.users(id) on delete cascade,
  word_id text not null check (length(word_id) > 0),
  ease_factor double precision not null default 2.5
    check (ease_factor >= 1.3 and ease_factor <> 'NaN'::float8 and ease_factor <> 'Infinity'::float8),
  interval_days integer not null default 0 check (interval_days >= 0),
  repetitions integer not null default 0 check (repetitions >= 0),
  due_date timestamptz not null,
  updated_at timestamptz not null default 'epoch',
  primary key (user_id, word_id)
);

drop function if exists public.sync_progress(uuid, jsonb, jsonb, jsonb);
-- Convert Phase 6A microseconds without rounding through a floating-point epoch.
do $$
declare t text;
begin
  foreach t in array array['user_stats', 'lesson_progress', 'word_progress'] loop
    if exists (select 1 from information_schema.columns where table_schema = 'public'
      and table_name = t and column_name = 'updated_at' and data_type = 'bigint') then
      execute format('alter table public.%I drop constraint if exists %I', t, t || '_updated_at_check');
      execute format('alter table public.%I alter column updated_at drop default', t);
      execute format('alter table public.%I alter column updated_at type timestamptz using
        (timestamptz ''epoch'' + (updated_at / 1000000) * interval ''1 second''
          + (updated_at %% 1000000) * interval ''1 microsecond'')', t);
      execute format('alter table public.%I alter column updated_at set default ''epoch''', t);
    end if;
  end loop;
end $$;

-- Internal revision protects incremental downloads from late offline uploads.
-- Per-user transaction locks make revision order match visible commit order.
create sequence if not exists public.progress_sync_version;
revoke all on sequence public.progress_sync_version from public, anon, authenticated;
do $$
declare t text; p record;
begin
  foreach t in array array['profiles', 'user_stats', 'lesson_progress', 'word_progress'] loop
    execute format('alter table public.%I add column if not exists sync_version bigint not null default 0', t);
    execute format('update public.%I set sync_version = nextval(''public.progress_sync_version'') where sync_version = 0', t);
    execute format('alter table public.%I enable row level security', t);
    -- These four application tables use a single ownership policy each.
    for p in select policyname from pg_policies where schemaname = 'public' and tablename = t loop
      execute format('drop policy %I on public.%I', p.policyname, t);
    end loop;
    execute format('revoke all on public.%I from public, anon', t);
    execute format('grant select, insert, update, delete on public.%I to authenticated', t);
    execute format('create policy own_rows on public.%I for all to authenticated
      using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id)', t);
    execute format('create index if not exists %I on public.%I (user_id, updated_at)', t || '_sync_time', t);
    execute format('create index if not exists %I on public.%I (user_id, sync_version)', t || '_sync_revision', t);
  end loop;
end $$;

create or replace function public.guard_progress_write()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(new.user_id::text, 0));
  if tg_op = 'UPDATE' then
    if new.user_id <> old.user_id then
      raise exception 'Row ownership cannot change' using errcode = '42501';
    end if;
    if new.updated_at <= old.updated_at then
      return old; -- Existing cloud row wins ties; RETURNING supplies its value.
    end if;
  end if;
  new.sync_version := pg_catalog.nextval('public.progress_sync_version'::regclass);
  return new;
end $$;
revoke all on function public.guard_progress_write() from public, anon, authenticated;
do $$
declare t text;
begin
  foreach t in array array['profiles', 'user_stats', 'lesson_progress', 'word_progress'] loop
    execute format('drop trigger if exists guard_progress_write on public.%I', t);
    execute format('create trigger guard_progress_write before insert or update on public.%I
      for each row execute function public.guard_progress_write()', t);
  end loop;
end $$;

create or replace function public.create_signup_rows()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles(user_id, display_name)
  values (new.id, left(coalesce(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name', ''), 120))
  on conflict (user_id) do nothing;
  -- Empty stats use epoch so they cannot replace actual offline progress.
  insert into public.user_stats(user_id) values (new.id) on conflict (user_id) do nothing;
  return new;
end $$;
revoke all on function public.create_signup_rows() from public, anon, authenticated;
drop trigger if exists create_signup_rows on auth.users;
create trigger create_signup_rows after insert on auth.users
  for each row execute function public.create_signup_rows();
-- Also repair accounts created before this phase without replacing their data.
insert into public.profiles(user_id, display_name)
  select id, left(coalesce(raw_user_meta_data->>'full_name', raw_user_meta_data->>'name', ''), 120)
  from auth.users on conflict (user_id) do nothing;
insert into public.user_stats(user_id) select id from auth.users on conflict (user_id) do nothing;

-- Pull a consistent per-account delta. Invoker privileges preserve RLS.
-- Returning JSON avoids PostgREST's default SELECT row-count cap.
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
      select updated_at, sync_version from public.profiles where user_id = uid
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
    'words', coalesce((select jsonb_agg(to_jsonb(r) order by word_id) from public.word_progress r
      where user_id = uid and (updated_at > p_since or sync_version > p_after_version)), '[]'::jsonb)
  ) into result;
  return result;
end $$;
revoke all on function public.pull_progress(timestamptz, bigint) from public, anon;
grant execute on function public.pull_progress(timestamptz, bigint) to authenticated;
notify pgrst, 'reload schema';
commit;
