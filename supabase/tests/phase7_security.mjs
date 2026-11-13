// Uses the same local PGlite install as phase6c_security.mjs; never contacts Supabase.
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
const require = createRequire(resolve('.dart_tool/sqlcheck/package.json'));
const { PGlite } = require('@electric-sql/pglite');
const db = new PGlite();
const A = '11111111-1111-4111-8111-111111111111';
const B = '22222222-2222-4222-8222-222222222222';
let count = 0;
async function check(name, callback) { await callback(); count++; console.log(`PASS: ${name}`); }
async function asUser(id, role = 'authenticated') {
  await db.exec(`reset role; set role ${role}`);
  await db.query("select set_config('request.jwt.claim.sub', $1, false)", [id]);
}
try {
  await db.exec(`create role anon; create role authenticated; create schema auth;
    create table auth.users(id uuid primary key, raw_user_meta_data jsonb default '{}'::jsonb);
    create function auth.uid() returns uuid language sql stable as
      $$select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid$$;
    grant usage on schema auth, public to anon, authenticated;
    grant execute on function auth.uid() to anon, authenticated;`);
  await db.exec(await readFile('supabase/migrations/202611120001_phase6c.sql', 'utf8'));
  await db.query('insert into auth.users(id) values ($1), ($2)', [A, B]);
  await db.query("update public.user_stats set streak=4, updated_at='2026-11-12' where user_id=$1", [A]);
  const migration = await readFile('supabase/migrations/202611130001_phase7.sql', 'utf8');
  await db.exec(migration);
  await db.exec(migration);
  await check('migration can rerun and seeds longest known streak', async () => {
    assert.equal((await db.query('select longest_streak from public.user_stats where user_id=$1', [A])).rows[0].longest_streak, 4);
  });
  await asUser(A);
  await check('owner can insert and pull activity', async () => {
    await db.query("insert into public.daily_activity(user_id,activity_date,xp,updated_at) values ($1,'2026-11-13',50,'2026-11-13')", [A]);
    const data = (await db.query('select public.pull_progress() as data')).rows[0].data;
    assert.equal(data.activities[0].xp, 50);
    assert.equal(data.activities[0].activity_date, '2026-11-13');
    assert.equal(data.stats.longest_streak, 4);
  });
  await asUser(B);
  await check('another account cannot read or change activity', async () => {
    assert.equal((await db.query('select * from public.daily_activity')).rows.length, 0);
    assert.equal((await db.query('update public.daily_activity set xp=999 returning *')).rows.length, 0);
    assert.equal((await db.query('delete from public.daily_activity returning *')).rows.length, 0);
    await assert.rejects(db.query("insert into public.daily_activity(user_id,activity_date) values ($1,'2026-11-14')", [A]), /row-level security/);
  });
  await asUser(A);
  await check('reset activity wins over older uploads', async () => {
    await db.query("update public.daily_activity set xp=0,updated_at='2026-11-14' where user_id=$1", [A]);
    await db.query("insert into public.daily_activity(user_id,activity_date,xp,updated_at) values ($1,'2026-11-13',90,'2026-11-13') on conflict(user_id,activity_date) do update set xp=excluded.xp,updated_at=excluded.updated_at", [A]);
    assert.equal((await db.query('select xp from public.daily_activity')).rows[0].xp, 0);
  });
  await check('word reset tombstone survives a stale device update', async () => {
    await db.query("insert into public.word_progress(user_id,word_id,ease_factor,interval_days,repetitions,due_date,updated_at,deleted) values ($1,'hello',2.5,0,0,'2026-11-13','2026-11-14',true)", [A]);
    await db.query("update public.word_progress set deleted=false,updated_at='2026-11-13' where user_id=$1", [A]);
    const row = (await db.query('select * from public.word_progress')).rows[0];
    assert.equal(row.deleted, true);
    await db.query("update public.word_progress set deleted=false,updated_at='2026-11-15' where user_id=$1", [A]);
    assert.equal((await db.query('select deleted from public.word_progress')).rows[0].deleted, false);
  });
  await asUser('', 'anon');
  await check('anonymous activity access is denied', async () => {
    await assert.rejects(db.query('select * from public.daily_activity'), /permission denied/);
  });
  console.log(`${count} Phase 7 SQL checks passed.`);
} finally { await db.close(); }
