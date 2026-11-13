// Requires the ignored PGlite install described in PHASE9_IMPLEMENTATION.md.
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
const require = createRequire(resolve('.dart_tool/sqlcheck/package.json'));
const { PGlite } = require('@electric-sql/pglite');
const db = new PGlite();
const A = '11111111-1111-4111-8111-111111111111', B = '22222222-2222-4222-8222-222222222222';
let assertions = 0;
async function check(name, fn) { await fn(); assertions++; console.log(`PASS: ${name}`); }
async function identity(uid, role = 'authenticated') {
  await db.exec(`reset role; set role ${role}`);
  await db.query("select set_config('request.jwt.claim.sub', $1, false)", [uid]);
}
try {
  await db.exec(`create role anon; create role authenticated; create schema auth;
    create table auth.users(id uuid primary key, raw_user_meta_data jsonb default '{}'::jsonb);
    create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
    grant usage on schema auth, public to anon, authenticated;
    grant execute on function auth.uid() to anon, authenticated;`);
  for (const file of ['202611120001_phase6c.sql','202611130001_phase7.sql','202611130002_phase9.sql']) {
    await db.exec(await readFile(`supabase/migrations/${file}`, 'utf8'));
  }
  await db.exec(await readFile('supabase/migrations/202611130002_phase9.sql','utf8'));
  await db.query('insert into auth.users(id) values($1),($2)', [A,B]);
  await identity(A);
  await check('quota allows ten requests then rejects further calls', async () => {
    for (let i = 0; i < 10; i++) assert.equal((await db.query('select public.take_chat_slot() as quota')).rows[0].quota.allowed, true);
    const quota = (await db.query('select public.take_chat_slot() as quota')).rows[0].quota;
    assert.equal(quota.allowed, false); assert.ok(quota.retry_after >= 1 && quota.retry_after <= 60);
  });
  await check('clients cannot read, reset or forge their quota counters', async () => {
    for (const query of ['select * from public.chat_rate_limits','delete from public.chat_rate_limits','update public.chat_rate_limits set minute_count=0']) {
      await assert.rejects(db.query(query), /permission denied/);
    }
  });
  await identity(B);
  await check('rate limits are isolated by verified user identity', async () => {
    assert.equal((await db.query('select public.take_chat_slot() as quota')).rows[0].quota.allowed, true);
  });
  await identity(A);
  await check('saved vocabulary appears in incremental progress pulls', async () => {
    await db.query(`insert into public.saved_words(user_id,word_id,course_id,text,translation,example,example_translation,updated_at)
      values($1,'ai_hello','ja_basics_en','hello','greeting','hello there','a greeting','2026-11-13')`, [A]);
    const data = (await db.query('select public.pull_progress() as data')).rows[0].data;
    assert.equal(data.saved_words[0].word_id, 'ai_hello');
  });
  await identity(B);
  await check('another user cannot read, edit, delete or insert vocabulary for A', async () => {
    assert.equal((await db.query('select * from public.saved_words')).rows.length, 0);
    assert.equal((await db.query("update public.saved_words set text='stolen' returning *")).rows.length, 0);
    assert.equal((await db.query('delete from public.saved_words returning *')).rows.length, 0);
    await assert.rejects(db.query(`insert into public.saved_words(user_id,word_id,course_id,text,translation,example,example_translation)
      values($1,'other','course','x','x','x','x')`, [A]), /row-level security/);
  });
  await identity(A);
  await check('vocabulary tombstones survive stale writes', async () => {
    await db.query("update public.saved_words set deleted=true,updated_at='2026-11-14' where user_id=$1", [A]);
    await db.query("update public.saved_words set deleted=false,updated_at='2026-11-13' where user_id=$1", [A]);
    assert.equal((await db.query('select deleted from public.saved_words')).rows[0].deleted, true);
  });
  await db.exec('reset role');
  await check('daily quota applies even after the minute window resets', async () => {
    await db.query("update public.chat_rate_limits set minute_start='epoch',day_count=100 where user_id=$1", [A]);
    await identity(A);
    const quota = (await db.query('select public.take_chat_slot() as quota')).rows[0].quota;
    assert.equal(quota.allowed,false); assert.ok(quota.retry_after > 0 && quota.retry_after <= 86400);
  });
  await identity('', 'anon');
  await check('anonymous callers cannot consume a chat slot or read words', async () => {
    await assert.rejects(db.query('select public.take_chat_slot()'), /permission denied/);
    await assert.rejects(db.query('select * from public.saved_words'), /permission denied/);
  });
  console.log(`${assertions} Phase 9 SQL checks passed.`);
} finally { await db.close(); }
