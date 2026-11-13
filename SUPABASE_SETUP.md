# Phase 6C: Supabase Auth and offline sync

**Phase 7 update:** after the Phase 6C migration below, run
[202611130001_phase7.sql](supabase/migrations/202611130001_phase7.sql) for daily
activity, longest streaks and synced progress resets. See
[Phase 7 run instructions](PHASE7_IMPLEMENTATION.md). Existing progress is preserved.

The app uses supabase_flutter ^2.18.3. Supabase replaces the Firebase backend
requested initially. Email/password, Google OAuth, password recovery, local
account isolation, and incremental background sync are implemented. Your project
URL and publishable key are already in ignored config.local.json. Dashboard
changes below must be made in your project; the public app key cannot run DDL.

For browser testing, run `flutter run -d edge --web-port=7357
--dart-define-from-file=config.local.json` as one command. The bundled database
worker and SQLite WebAssembly module enable local progress in Chrome/Edge.
Keep the same port between runs to preserve that origin's local storage.
See [browser troubleshooting](BROWSER_DATABASE_FIX.md) if opening progress fails.

## 1. Create your Supabase project

1. Sign in at [Supabase Dashboard](https://supabase.com/dashboard).
2. Create a project in your organization. Enter its name, choose a database
   password, and select a region near your users. Keep the database password
   outside the Flutter app.
3. Once ready, open the project's Connect panel / App Frameworks for the project
   URL. In Settings / API Keys, copy its publishable key, or the legacy anon key
   under Legacy API Keys. Use your existing project if you already created one.
4. From C:\Langunge_flutter\myapp, create the local config file once:

```powershell
if (-not (Test-Path config.local.json)) {
  Copy-Item config.example.json config.local.json
}
```

Edit config.local.json with your values:

```json
{
  "SUPABASE_URL": "https://YOUR_PROJECT_REF.supabase.co",
  "SUPABASE_PUBLISHABLE_KEY": "YOUR_PUBLISHABLE_KEY",
  "AUTH_REDIRECT_URL": "io.languagelearning.app://auth-callback"
}
```

The publishable key is a public client identifier; auth and row-level security
control access. Legacy anon keys also work. Secret keys, service_role keys,
Google client secrets, and database passwords do not belong in this file.
Configuration rejects service-role keys. The local file is ignored by Git.
SUPABASE_ANON_KEY is supported as an alternative to SUPABASE_PUBLISHABLE_KEY;
use one key setting. Never use a service_role or sb_secret_ key in Flutter.
Dart defines take priority. For plain `flutter run`, run
`python tool/prepare_local_config.py` first to copy public client settings into
the ignored `assets/local/client.env` asset. Regenerate it after changing the JSON.
Only public client settings are copied; server secrets are rejected. Neither local
file is committed. Fully stop and rebuild after configuration changes; hot reload
does not update Dart defines or add new bundled assets. Alternatively, always use
`flutter run --dart-define-from-file=config.local.json`. The VS Code launch profile
uses this flag automatically when you open the `myapp` folder.

See [Supabase's Flutter setup](https://supabase.com/docs/guides/getting-started/quickstarts/flutter).
FlutterFire and Firebase configuration are not used.

## 2. Run the one Phase 6C SQL script

Open [202611120001_phase6c.sql](supabase/migrations/202611120001_phase6c.sql).
Copy the entire script into SQL Editor / New query and click Run. It creates a
fresh schema or upgrades Phase 6A without dropping progress; do not run the old
Phase 6A script separately on a fresh project. Re-running this script is safe.
It replaces the earlier sync RPC, so update old app builds with this schema.

| Table | Key | Synced data |
| --- | --- | --- |
| public.profiles | user_id | display_name, updated_at |
| public.user_stats | user_id | xp, streak, last_active_date, updated_at |
| public.word_progress | user_id, word_id | ease factor, interval, repetitions, due date, updated_at |
| public.lesson_progress | user_id, lesson_id | completion, best score, completion date, updated_at |

All user_id values reference the managed auth.users table. Lesson progress is
included so another device restores completed/unlocked lessons too. updated_at
is timestamptz on every table. Flutter converts its internal UTC microsecond
integers to ISO timestamps at the API boundary without losing microseconds.
The signup trigger creates profiles and empty user_stats rows for email and
Google accounts; existing accounts are backfilled. Empty signup stats use epoch
timestamps so they cannot replace actual offline learning progress.

Row-level security is enabled on all four tables. Each policy permits access
only when the authenticated user's ID equals the row's user_id:

```sql
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id)
```

Anonymous access is revoked. sync_progress is executable only by authenticated
users, runs with their permissions, and checks p_user_id against auth.uid().
It atomically merges rows with a greater timestamp and returns the winning
values. Existing remote rows win exact timestamp ties. This avoids a
read-then-upsert race between devices.

The executable tables, policies, and function are in the migration; the snippet
above just explains the policy condition.
See [Supabase row-level security](https://supabase.com/docs/guides/database/postgres/row-level-security).

## 3. Configure email authentication and callbacks

1. In Authentication / Sign In Providers, enable Email. Keep email confirmation
   enabled if you want users to verify their addresses.
2. Set the minimum new-password length to 8, matching the app's registration and
   reset validation. Existing shorter passwords still work at sign-in.
3. In Authentication / URL Configuration / Redirect URLs, add this exact URL:

```text
io.languagelearning.app://auth-callback
```

4. Keep the default confirmation/reset email templates, or ensure custom
   templates retain Supabase's confirmation URL and redirect target.
5. Configure custom SMTP for real learners. Supabase's default email service
   restricts delivery and has low rate limits; use an authorized project-team
   address for initial tests when SMTP has not been configured.

The Android manifest already handles that scheme/host. Flutter's built-in
handler is disabled so the Supabase SDK can process the callback. If you change
the callback, update the manifest, local config, and redirect allowlist together.

Registration explains email confirmation when no session is returned. Forgot
Password sends an email without disclosing whether an account exists. Opening
the recovery link emits a password-recovery event; the router opens
/reset-password and asks for a new password. Test the link on the same Android
installation that requested it because PKCE stores its verifier locally.
First sign-in, registration, and sending reset emails require internet.

References: [mobile deep links](https://supabase.com/docs/guides/auth/native-mobile-deep-linking?platform=flutter),
[redirect URLs](https://supabase.com/docs/guides/auth/redirect-urls),
[custom SMTP](https://supabase.com/docs/guides/auth/auth-smtp).

## 4. Enable Google sign-in

This implementation uses Supabase's browser-based OAuth flow. It does not
require google_sign_in or an Android OAuth credential in the app.

1. Open Authentication / Sign In Providers / Google in Supabase.
2. Copy the provider's callback URL, normally:

```text
https://YOUR_PROJECT_REF.supabase.co/auth/v1/callback
```

3. In Google Cloud Console, configure the OAuth consent screen and create an
   OAuth client of type Web application. Add the Supabase callback as an
   Authorized redirect URI. Add your Google account as a test user if the
   consent application is still in testing.
4. Put that Web client ID and client secret in Supabase's Google provider
   settings, enable the provider, and save. The secret stays in Supabase.
5. Confirm the app callback from step 3 is in Supabase's redirect allowlist.
6. Run Android and tap Continue with Google. The browser signs in through
   Supabase and returns through the app's custom scheme.

Use the Supabase callback in Google Cloud, and the app callback in Supabase's
allowlist: they serve different steps of the flow.
See [Supabase Google OAuth setup](https://supabase.com/docs/guides/auth/social-sign-in/auth-google).

## 5. Run on Android

```powershell
cd C:\Langunge_flutter\myapp
flutter pub get
flutter doctor -v
flutter emulators
flutter emulators --launch Medium_Phone_API_37.0
flutter devices
flutter run -d emulator-5554 --dart-define-from-file=config.local.json
```

Use the actual device ID printed by flutter devices. Existing Android SDK and
license setup in the README still applies. The app opens Login; an unconfigured
build shows a sign-in-unavailable message instead of crashing. After signing in,
onboarding runs when this device's language/goal preferences are not set yet.

To set the display name as well:

```powershell
flutter run -d emulator-5554 --dart-define-from-file=config.local.json --dart-define="APP_NAME=My Language App"
```

Android callbacks are configured here. Other native platforms need their URL
scheme configuration before OAuth/email callbacks can work.

## 6. Offline and merge behavior

- Screens read from Drift and lesson/review actions save locally first. Sync
  never blocks gameplay on a network request.
- Each account has a separate SQLite file. Switching accounts switches the
  active database. Token refreshes for the same account do not reopen it.
- The legacy Phase 1-5 database is claimed by the first account to sign in and
  imported once. Another account cannot import it. Untimestamped legacy rows
  are older than timestamped cloud rows.
- Language/goal preferences remain device settings and are not synced.
- Progress rows have updatedAt and a durable dirty flag. Dirty rows represent
  edits since their last successful acknowledgement, even if their timestamps
  predate the cursor. Schema version 3 adds a local profiles cache and preserves
  progress from versions 1 and 2.
- Sync starts after local account preparation, coalesces changes, retries every
  30 seconds while the app is active, and retries on resume. Profile provides
  Sync now and Sign out.
- Failed requests leave pending rows on disk so a new process can retry.
- Timestamps advance beyond the previous row timestamp even if the device clock
  goes backwards. Exact timestamp ties consistently prefer remote values.
- Applying responses rechecks current local timestamps. A newer edit made while
  an upload was in flight remains pending instead of being overwritten/acknowledged.
- Disposed account services do not apply late responses. Upserts use the primary
  key in onConflict. An ownership policy protects every request, and a database
  trigger keeps newer cloud rows when a stale device attempts to replace them.
- Each account stores lastSyncedAt and a server revision in SQLite. The pull RPC
  returns rows with updated_at > lastSyncedAt, plus rows with a newer revision.
  The revision catches late offline uploads whose old timestamps would otherwise
  be missed. Per-account transaction locks serialize server writes and pulls so
  the revision boundary cannot skip an uncommitted write.
- Downloaded rows and the cursor commit together locally. Failed or interrupted
  requests retain dirty flags and the previous cursor for a safe retry. Upload
  responses also include the cloud winners to acknowledge stale attempted edits.
- A cached account can keep learning offline when network token refresh fails.
  Logged-out users go to Login.

Background means work outside screen actions while the app is running/resumed;
it is not an OS job that runs after the app is killed. This phase does not
synchronize deletions/tombstones.

LWW applies to whole rows. Concurrent offline XP changes from two devices are
not added together: the later row wins. Word schedules follow the same rule.
Device-clock differences can affect which concurrent edit is later. This is the
requested LWW policy rather than an event-based counter merge.

## 7. Verify

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Optional local Postgres policy/RPC checks use Node and a test-only engine in the
ignored Dart tool directory:

```powershell
npm.cmd install --prefix .dart_tool/sqlcheck --no-save --no-audit --no-fund @electric-sql/pglite@0.5.15
node.exe supabase/tests/sync_security.mjs
node.exe supabase/tests/phase6c_security.mjs
```

The SQL test uses Postgres semantics with a stubbed auth.users/auth.uid context.
It verifies policies, ownership, timestamp comparisons, and rollback. It does
not replace testing live Supabase Auth and Google OAuth in your project.

Manual checks after setup:

1. Register, confirm the email, and sign in.
2. Complete a lesson and review a card. Inspect cloud rows under your UID.
3. Go offline, make more progress, and restart. The cached account should still
   have its local progress.
4. Reconnect/resume and use Profile / Sync now. Confirm pending changes upload.
5. Use a second device to verify downloaded progress and unlocked lessons.
6. Sign out and use another account; its local and remote progress stay separate.
7. Exercise Forgot Password and Google sign-in on the Android installation.

The earlier Android build reached Login and passed empty-field validation. The
new Phase 6C build and automated checks are recorded in PHASE6C_FILES.md. A
successful public-key health check does not verify a live account login or sync.
Email delivery, confirmation/recovery links, Google OAuth and two-account cloud
sync must still be checked in your configured project.

## 8. Test that user A cannot read user B

Create two test accounts with distinct email addresses using the app and confirm
both. Copy their UUIDs from Authentication / Users. Confirm B has profiles and
user_stats rows in Table Editor; complete a lesson as B to populate the other
tables too. The SQL Editor normally uses an admin role that bypasses RLS, so
SELECT alone in that editor does not test client permissions.

Replace both UUID placeholders below, then run this entire read-only transaction
in SQL Editor. auth.uid() must show A and every visible_b_rows count must be 0.
The preceding admin counts should be nonzero for B's populated tables.

```sql
begin;
select 'profiles' as table_name, count(*) as actual_b_rows from public.profiles
  where user_id = 'USER_B_UUID'::uuid
union all select 'user_stats', count(*) from public.user_stats
  where user_id = 'USER_B_UUID'::uuid
union all select 'lesson_progress', count(*) from public.lesson_progress
  where user_id = 'USER_B_UUID'::uuid
union all select 'word_progress', count(*) from public.word_progress
  where user_id = 'USER_B_UUID'::uuid;

set local role authenticated;
select set_config('request.jwt.claim.sub', 'USER_A_UUID', true);
select auth.uid() as acting_as_a;
select 'profiles' as table_name, count(*) as visible_b_rows from public.profiles
  where user_id = 'USER_B_UUID'::uuid
union all select 'user_stats', count(*) from public.user_stats
  where user_id = 'USER_B_UUID'::uuid
union all select 'lesson_progress', count(*) from public.lesson_progress
  where user_id = 'USER_B_UUID'::uuid
union all select 'word_progress', count(*) from public.word_progress
  where user_id = 'USER_B_UUID'::uuid;
rollback;
```

Repeat with A and B swapped. Also sign in as A in the app and verify only A's
progress is restored. No private server key is needed for these client tests.

## 9. Flutter and session behavior explained

Phase 9 adds one migration, a server-only Groq secret and the `chat` Edge
Function. Follow [PHASE9_IMPLEMENTATION.md](PHASE9_IMPLEMENTATION.md) after the
Phase 6C and Phase 7 migrations. No LLM API key belongs in Flutter's config.

main() calls WidgetsFlutterBinding.ensureInitialized() before Supabase.initialize:
Flutter must prepare platform plugins before the SDK reads cached credentials.
ProviderScope then supplies the initialized client to Riverpod. A provider is a
shared dependency/state source, similar to React context with subscriptions.

authStateProvider subscribes to onAuthStateChange. go_router refreshes redirects
when that provider changes: signed-out users go to Login, password recovery goes
to Reset Password, and signed-in users open their local account database.
The SDK renews access tokens. Network renewal errors keep a cached account
usable offline; a cleared/revoked session emits signed-out state and safely opens
Login. Local rows stay in that account's database for the next sign-in.

In Profile, Sign out clears the local SDK session and triggers the same redirect.
Database changes after successful lessons and flashcard ratings request sync;
app resume requests it as well. Screens and gameplay always read Drift. Sync is
an app-lifecycle task, not a mobile OS service that runs while the app is killed.
