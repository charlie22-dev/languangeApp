// npm.cmd install --prefix .dart_tool/sqlcheck --no-save @electric-sql/pglite@0.5.15
// node.exe supabase/tests/phase6c_security.mjs
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
const require = createRequire(resolve('.dart_tool/sqlcheck/package.json'));
const { PGlite } = require('@electric-sql/pglite');
const migration = await readFile('supabase/migrations/202611120001_phase6c.sql', 'utf8');
const A = '11111111-1111-4111-8111-111111111111';
const B = '22222222-2222-4222-8222-222222222222';
const tables = ['profiles', 'user_stats', 'lesson_progress', 'word_progress'];
let assertions = 0;
async function check(name, run) { await run(); assertions++; console.log(`PASS: ${name}`); }
async function setup(db) {
  await db.exec(`create role anon; create role authenticated;
    create schema auth;
    create table auth.users(id uuid primary key, raw_user_meta_data jsonb default '{}'::jsonb);
    create function auth.uid() returns uuid language sql stable as
      $$select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid$$;
    grant usage on schema auth, public to anon, authenticated;
    grant execute on function auth.uid() to anon, authenticated;`);
}
async function identity(db, uid, role = 'authenticated') {
  await db.exec(`reset role; set role ${role}`);
  await db.query("select set_config('request.jwt.claim.sub', $1, false)", [uid ?? '']);
}
async function pull(db, cursor) {
  const result = await db.query('select public.pull_progress($1::timestamptz, $2::bigint) as data',
    [cursor?.last_synced_at ?? '1970-01-01T00:00:00Z', cursor?.revision ?? 0]);
  return result.rows[0].data;
}
async function upsertStats(db, uid, xp, timestamp) {
  return (await db.query(`insert into public.user_stats(user_id, xp, updated_at) values ($1,$2,$3)
    on conflict(user_id) do update set xp=excluded.xp, updated_at=excluded.updated_at returning *`,
  [uid, xp, timestamp])).rows[0];
}
const db = new PGlite();
try {
  await setup(db);
  await db.exec(migration);
  await db.query(`insert into auth.users(id, raw_user_meta_data) values ($1, '{"full_name":"Learner A"}'),($2,'{}')`, [A,B]);
  await check('signup creates profiles and empty stats for both accounts', async () => {
    assert.equal((await db.query('select * from public.profiles where user_id=$1', [A])).rows[0].display_name, 'Learner A');
    assert.equal((await db.query('select * from public.user_stats')).rows.length, 2);
  });
  await check('all four tables use timestamptz and RLS', async () => {
    for (const table of tables) {
      const result = await db.query(`select data_type from information_schema.columns
        where table_schema='public' and table_name=$1 and column_name='updated_at'`, [table]);
      assert.equal(result.rows[0].data_type, 'timestamp with time zone');
      assert.equal((await db.query('select relrowsecurity from pg_class where oid=$1::regclass', [`public.${table}`])).rows[0].relrowsecurity, true);
    }
  });
  await identity(db, A);
  const initial = await pull(db);
  await check('second pull without changes is empty', async () => {
    const delta = await pull(db, initial);
    assert.equal(delta.profile, null); assert.equal(delta.stats, null);
    assert.deepEqual(delta.words, []); assert.deepEqual(delta.lessons, []);
  });
  await check('upsert retains newer cloud values and returns them for stale/tied writes', async () => {
    const stamp = '2026-11-12T10:00:00.123456Z';
    await upsertStats(db, A, 50, stamp);
    assert.equal((await upsertStats(db, A, 99, stamp)).xp, 50);
    assert.equal((await upsertStats(db, A, 99, '2026-11-11T10:00:00Z')).xp, 50);
    assert.equal((await upsertStats(db, A, 30, '2026-11-12T10:00:00.123457Z')).xp, 30);
  });
  await check('late offline row with older updated_at is still downloaded via revision', async () => {
    const cursor = await pull(db, initial);
    await db.query(`insert into public.word_progress(user_id,word_id,due_date,updated_at)
      values ($1,'late-word',now(),'2020-01-01')`, [A]);
    const delta = await pull(db, cursor);
    assert.equal(delta.words[0].word_id, 'late-word');
    assert.ok(delta.revision > cursor.revision);
    const empty = await pull(db, delta);
    assert.deepEqual(empty.words, []);
  });
  await check('RLS prevents A reading any rows belonging to B', async () => {
    for (const table of tables) {
      assert.equal((await db.query(`select * from public.${table} where user_id=$1`, [B])).rows.length, 0);
    }
  });
  await check('RLS blocks inserts for B and changes of owner', async () => {
    const sql = [
      `insert into public.profiles(user_id) values ($1)`,
      `insert into public.user_stats(user_id) values ($1)`,
      `insert into public.lesson_progress(user_id,lesson_id) values ($1,'stolen')`,
      `insert into public.word_progress(user_id,word_id,due_date) values ($1,'stolen',now())`,
    ];
    for (const statement of sql) await assert.rejects(db.query(statement, [B]), { code: '42501' });
    await assert.rejects(db.query(`update public.user_stats set user_id=$1, updated_at=now() where user_id=$2`, [B,A]), {code: '42501'});
  });
  await check('RLS hides B from updates and deletes across all tables', async () => {
    for (const table of tables) {
      assert.equal((await db.query(`update public.${table} set updated_at=now() where user_id=$1 returning *`, [B])).rows.length, 0);
      assert.equal((await db.query(`delete from public.${table} where user_id=$1 returning *`, [B])).rows.length, 0);
    }
  });
  await check('owner can insert, update and delete own lesson and word rows', async () => {
    await db.query(`insert into public.lesson_progress(user_id,lesson_id) values ($1,'own')`, [A]);
    assert.equal((await db.query(`update public.lesson_progress set completed=true,updated_at=now() where user_id=$1 returning *`, [A])).rows[0].completed, true);
    assert.equal((await db.query('delete from public.lesson_progress where user_id=$1 returning *', [A])).rows.length, 1);
    assert.equal((await db.query('delete from public.word_progress where user_id=$1 returning *', [A])).rows.length, 1);
  });
  await check('clients cannot forge the revision counter', async () => {
    const row = (await db.query(`update public.user_stats set sync_version=99999999,
      updated_at='2027-01-01' where user_id=$1 returning *`, [A])).rows[0];
    assert.notEqual(row.sync_version, 99999999);
  });
  await identity(db, null, 'anon');
  await check('anonymous access is blocked for all tables and pull RPC', async () => {
    for (const table of tables) await assert.rejects(db.query(`select * from public.${table}`), {code:'42501'});
    await assert.rejects(pull(db), {code:'42501'});
  });
  await identity(db, null);
  await check('expired session cannot pull progress', async () => {
    await assert.rejects(pull(db), {code:'42501'});
  });
  await db.exec('reset role');
  await check('script can be run twice without losing existing progress', async () => {
    await db.exec(migration);
    assert.equal((await db.query('select xp from public.user_stats where user_id=$1', [A])).rows[0].xp, 30);
  });
} finally { await db.close(); }

const upgrade = new PGlite();
try {
  await setup(upgrade);
  await upgrade.query('insert into auth.users(id) values ($1)', [A]);
  await upgrade.exec(await readFile('supabase/migrations/202611080001_auth_sync.sql', 'utf8'));
  await upgrade.query(`insert into public.user_stats(user_id,xp,updated_at) values ($1,99,1794477600123456)`, [A]);
  await upgrade.exec(migration);
  await check('Phase 6A upgrade preserves XP and exact microsecond timestamp', async () => {
    const result = await upgrade.query(`select xp, (extract(epoch from updated_at)*1000000)::bigint as stamp
      from public.user_stats where user_id=$1`, [A]);
    assert.equal(result.rows[0].xp, 99);
    assert.equal(result.rows[0].stamp, 1794477600123456);
    assert.equal((await upgrade.query('select * from public.profiles')).rows.length, 1);
  });
} finally { await upgrade.close(); }
console.log(`${assertions} Phase 6C SQL checks passed.`);
