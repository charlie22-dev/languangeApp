# Phase 6A: Supabase Auth and offline sync

The app uses supabase_flutter ^2.18.3. Supabase replaces the Firebase backend
requested initially. Email/password, Google OAuth, password recovery, local
account isolation, and background sync are implemented. No cloud project has
been created or configured by this change.

## 1. Create your Supabase project

1. Sign in at [Supabase Dashboard](https://supabase.com/dashboard).
2. Create a project in your organization. Enter its name, choose a database
   password, and select a region near your users. Keep the database password
   outside the Flutter app.
3. Once ready, open the project's Connect panel or Settings / API Keys. Copy
   the project URL and publishable key.
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
Values are read through String.fromEnvironment and --dart-define-from-file;
stop and rerun the app after changing them.

See [Supabase's Flutter setup](https://supabase.com/docs/guides/getting-started/quickstarts/flutter).
FlutterFire and Firebase configuration are not used.

## 2. Create tables, policies, and the merge function

Open supabase/migrations/202611080001_auth_sync.sql. Copy its complete contents
into a new query in the project's SQL Editor and run it once on your new project.

| Table | Key | Synced data |
| --- | --- | --- |
| public.user_stats | user_id | xp, streak, last_active_date, updated_at |
| public.word_progress | user_id, word_id | ease factor, interval, repetitions, due date, updated_at |
| public.lesson_progress | user_id, lesson_id | completion, best score, completion date, updated_at |

All user_id values reference the managed auth.users table. Lesson progress is
included so another device restores completed/unlocked lessons too. updated_at
is an integer UTC epoch timestamp in microseconds, matching Drift's updatedAt
property. Other date columns are Postgres timestamptz values.

Row-level security is enabled on all three tables. Each policy permits access
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
- Progress rows have updatedAt and a durable dirty flag. Schema version 1
  upgrades to version 2 without dropping existing progress.
- Sync starts after local account preparation, coalesces changes, retries every
  30 seconds while the app is active, and retries on resume. Profile provides
  Sync now and Sign out.
- Failed requests leave pending rows on disk so a new process can retry.
- Timestamps advance beyond the previous row timestamp even if the device clock
  goes backwards. Exact timestamp ties consistently prefer remote values.
- Applying responses rechecks current local timestamps. A newer edit made while
  an upload was in flight remains pending instead of being overwritten/acknowledged.
- Disposed account services do not apply late responses. The RPC rejects a user
  ID that differs from the request's authenticated identity.
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

Local verification passed: 121 Flutter tests and 11 SQL security/merge checks.
Live project setup, email delivery, Google OAuth, and an Android emulator run
have not been performed because no project configuration was supplied.
