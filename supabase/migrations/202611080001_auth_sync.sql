-- Run once in Supabase SQL Editor, or apply with `supabase db push`.
create table public.user_stats (
  user_id uuid primary key references auth.users(id) on delete cascade,
  xp bigint not null default 0 check (xp >= 0),
  streak integer not null default 0 check (streak >= 0),
  last_active_date timestamptz,
  updated_at bigint not null default 0 check (updated_at >= 0)
);

create table public.word_progress (
  user_id uuid not null references auth.users(id) on delete cascade,
  word_id text not null check (length(word_id) > 0),
  ease_factor double precision not null default 2.5
    check (ease_factor >= 1.3 and ease_factor <> 'NaN'::float8 and ease_factor <> 'Infinity'::float8),
  interval_days integer not null default 0 check (interval_days >= 0),
  repetitions integer not null default 0 check (repetitions >= 0),
  due_date timestamptz not null,
  updated_at bigint not null default 0 check (updated_at >= 0),
  primary key (user_id, word_id)
);

create table public.lesson_progress (
  user_id uuid not null references auth.users(id) on delete cascade,
  lesson_id text not null check (length(lesson_id) > 0),
  completed boolean not null default false,
  best_score integer not null default 0 check (best_score between 0 and 100),
  completed_at timestamptz,
  updated_at bigint not null default 0 check (updated_at >= 0),
  primary key (user_id, lesson_id)
);

alter table public.user_stats enable row level security;
alter table public.word_progress enable row level security;
alter table public.lesson_progress enable row level security;

revoke all on public.user_stats, public.word_progress, public.lesson_progress from anon;
grant select, insert, update, delete on public.user_stats, public.word_progress, public.lesson_progress to authenticated;

create policy own_stats on public.user_stats for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy own_words on public.word_progress for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy own_lessons on public.lesson_progress for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

-- A single transaction performs compare-and-set merges and returns the winners.
-- Client timestamps are UTC epoch microseconds. Existing remote rows win ties.
create function public.sync_progress(
  p_user_id uuid,
  p_stats jsonb default null,
  p_words jsonb default '[]'::jsonb,
  p_lessons jsonb default '[]'::jsonb
) returns jsonb
language plpgsql security invoker set search_path = public, pg_temp
as $$
begin
  if auth.uid() is null or p_user_id is null or auth.uid() <> p_user_id then
    raise exception 'Account mismatch' using errcode = '42501';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(p_user_id::text, 0));

  if p_stats is not null and p_stats <> 'null'::jsonb then
    insert into public.user_stats(user_id, xp, streak, last_active_date, updated_at)
    values (p_user_id, (p_stats->>'xp')::bigint, (p_stats->>'streak')::integer,
      (p_stats->>'last_active_date')::timestamptz, (p_stats->>'updated_at')::bigint)
    on conflict (user_id) do update set xp = excluded.xp, streak = excluded.streak,
      last_active_date = excluded.last_active_date, updated_at = excluded.updated_at
    where excluded.updated_at > public.user_stats.updated_at;
  end if;

  insert into public.word_progress(user_id, word_id, ease_factor, interval_days, repetitions, due_date, updated_at)
  select p_user_id, r.word_id, r.ease_factor, r.interval_days, r.repetitions, r.due_date, r.updated_at
  from jsonb_to_recordset(coalesce(p_words, '[]'::jsonb)) as r(
    word_id text, ease_factor float8, interval_days integer, repetitions integer, due_date timestamptz, updated_at bigint)
  on conflict (user_id, word_id) do update set ease_factor = excluded.ease_factor,
    interval_days = excluded.interval_days, repetitions = excluded.repetitions,
    due_date = excluded.due_date, updated_at = excluded.updated_at
  where excluded.updated_at > public.word_progress.updated_at;

  insert into public.lesson_progress(user_id, lesson_id, completed, best_score, completed_at, updated_at)
  select p_user_id, r.lesson_id, r.completed, r.best_score, r.completed_at, r.updated_at
  from jsonb_to_recordset(coalesce(p_lessons, '[]'::jsonb)) as r(
    lesson_id text, completed boolean, best_score integer, completed_at timestamptz, updated_at bigint)
  on conflict (user_id, lesson_id) do update set completed = excluded.completed,
    best_score = excluded.best_score, completed_at = excluded.completed_at, updated_at = excluded.updated_at
  where excluded.updated_at > public.lesson_progress.updated_at;

  return jsonb_build_object(
    'schema_version', 1, 'user_id', p_user_id,
    'stats', (select to_jsonb(s) from public.user_stats s where s.user_id = p_user_id),
    'words', coalesce((select jsonb_agg(to_jsonb(w) order by w.word_id)
      from public.word_progress w where w.user_id = p_user_id), '[]'::jsonb),
    'lessons', coalesce((select jsonb_agg(to_jsonb(l) order by l.lesson_id)
      from public.lesson_progress l where l.user_id = p_user_id), '[]'::jsonb)
  );
end;
$$;

revoke all on function public.sync_progress(uuid, jsonb, jsonb, jsonb) from public, anon;
grant execute on function public.sync_progress(uuid, jsonb, jsonb, jsonb) to authenticated;
