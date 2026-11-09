// Uses real Postgres semantics through PGlite; only the Supabase auth schema is stubbed.
// npm install --prefix .dart_tool/sqlcheck --no-save @electric-sql/pglite
// node supabase/tests/sync_security.mjs
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';

const require = createRequire(resolve('.dart_tool/sqlcheck/package.json'));
const { PGlite } = require('@electric-sql/pglite');
const db = new PGlite();
const A = '11111111-1111-4111-8111-111111111111';
const B = '22222222-2222-4222-8222-222222222222';
let assertions = 0;
async function check(name, action) {
  await action();
  assertions++;
  console.log(`PASS: ${name}`);
}
async function identity(uid, role = 'authenticated') {
  await db.exec(`reset role; set role ${role};`);
  await db.query("select set_config('request.jwt.claim.sub', $1, false)", [uid ?? '']);
}
async function rpc(uid, stats = null, words = [], lessons = []) {
  const result = await db.query('select public.sync_progress($1::uuid, $2::jsonb, $3::jsonb, $4::jsonb) as result',
    [uid, JSON.stringify(stats), JSON.stringify(words), JSON.stringify(lessons)]);
  return result.rows[0].result;
}
const stats = (xp, updated_at) => ({ xp, streak: 2, last_active_date: null, updated_at });
const word = (updated_at, repetitions = 1) => ({ word_id: 'ja_hello', ease_factor: 2.5,
  interval_days: 1, repetitions, due_date: '2026-11-09T12:00:00Z', updated_at });
const lesson = (updated_at, best_score = 90) => ({ lesson_id: 'ja_greetings', completed: true,
  best_score, completed_at: '2026-11-08T12:00:00Z', updated_at });

try {
  await db.exec(`create role anon; create role authenticated;
    create schema auth; grant usage on schema auth to anon, authenticated;
    create table auth.users(id uuid primary key);
    create function auth.uid() returns uuid language sql stable as
      $$select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid$$;
    insert into auth.users values ('${A}'), ('${B}');`);
  await db.exec(await readFile('supabase/migrations/202611080001_auth_sync.sql', 'utf8'));
  await identity(A);
  await check('owner can sync stats, words, and lesson progress', async () => {
    const result = await rpc(A, stats(50, 100), [word(100)], [lesson(100)]);
    assert.equal(result.user_id, A);
    assert.equal(result.stats.xp, 50);
    assert.equal(result.words.length, 1);
    assert.equal(result.lessons.length, 1);
  });
  await check('older timestamps cannot replace newer rows', async () => {
    const result = await rpc(A, stats(1, 99), [word(99, 0)], [lesson(99, 10)]);
    assert.equal(result.stats.xp, 50);
    assert.equal(result.words[0].repetitions, 1);
    assert.equal(result.lessons[0].best_score, 90);
  });
  await check('remote rows win equal timestamp ties', async () => {
    const result = await rpc(A, stats(500, 100), [word(100, 10)], [lesson(100, 100)]);
    assert.equal(result.stats.xp, 50);
    assert.equal(result.words[0].repetitions, 1);
    assert.equal(result.lessons[0].best_score, 90);
  });
  await check('newer rows win even when a counter is lower', async () => {
    const result = await rpc(A, stats(30, 101), [word(101, 2)], [lesson(101, 80)]);
    assert.equal(result.stats.xp, 30);
    assert.equal(result.words[0].repetitions, 2);
    assert.equal(result.lessons[0].best_score, 80);
  });
  await check('invalid progress rolls back the entire exchange', async () => {
    await assert.rejects(rpc(A, stats(70, 102), [{ ...word(102), ease_factor: 0 }]), { code: '23514' });
    assert.equal((await rpc(A)).stats.xp, 30);
  });
  await check('RPC rejects a different account ID', async () => {
    await assert.rejects(rpc(B, stats(999, 500)), { code: '42501' });
  });
  await identity(B);
  await rpc(B, stats(7, 100), [{ ...word(100), word_id: 'private-b' }], [lesson(100)]);
  await check('RLS hides another account across all three tables', async () => {
    for (const table of ['user_stats', 'word_progress', 'lesson_progress']) {
      const result = await db.query(`select * from public.${table}`);
      assert.ok(result.rows.length > 0);
      assert.ok(result.rows.every(row => row.user_id === B));
    }
  });
  await check('RLS blocks inserting rows owned by someone else', async () => {
    await assert.rejects(db.query('insert into public.word_progress(user_id, word_id, due_date) values ($1, $2, now())',
      [A, 'stolen']), { code: '42501' });
  });
  await check('RLS prevents cross-account updates and deletes', async () => {
    assert.equal((await db.query('update public.user_stats set xp = 999 where user_id = $1 returning *', [A])).rows.length, 0);
    assert.equal((await db.query('delete from public.word_progress where user_id = $1 returning *', [A])).rows.length, 0);
  });
  await identity(null);
  await check('missing JWT identity cannot call the merge function', async () => {
    await assert.rejects(rpc(A), { code: '42501' });
  });
  await identity(null, 'anon');
  await check('anonymous clients cannot read tables or execute sync', async () => {
    for (const table of ['user_stats', 'word_progress', 'lesson_progress']) {
      await assert.rejects(db.query(`select * from public.${table}`), { code: '42501' });
    }
    await assert.rejects(rpc(A), { code: '42501' });
  });
  console.log(`${assertions} SQL security and merge checks passed.`);
} finally {
  await db.close();
}
