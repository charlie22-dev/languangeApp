# Phase 6A: Supabase Auth and offline sync - full file contents

Supabase replaces the originally requested Firebase backend. The implementation
includes validated email/password and Google OAuth screens, password recovery,
auth redirects, per-account Drift databases, a schema-preserving migration,
durable pending changes, and timestamp-based background sync. PostgreSQL row-level
security and the owner-checked merge function are included in the SQL migration.

Validation: 121 Flutter tests and 11 local Postgres security/merge checks passed.
Flutter analysis and formatting passed. Live Supabase setup, email delivery,
Google OAuth, and an Android emulator run have not been performed.

Start with [SUPABASE_SETUP.md](SUPABASE_SETUP.md) for all project setup and run steps.
Use config.example.json as a template; config.local.json is ignored by Git.
Sync is per-row last-write-wins, with existing remote rows winning timestamp ties.
Concurrent offline XP deltas are not added together. Cached users can learn
offline; initial sign-in needs internet. Background sync runs while the app is
running/resumed, rather than as an OS job after termination.

## Created files

- [SUPABASE_SETUP.md](SUPABASE_SETUP.md)
- [config.example.json](config.example.json)
- [lib/core/config/supabase_config.dart](lib/core/config/supabase_config.dart)
- [lib/core/utils/sync_timestamp.dart](lib/core/utils/sync_timestamp.dart)
- [lib/features/auth/data/auth_repository.dart](lib/features/auth/data/auth_repository.dart)
- [lib/features/auth/domain/auth_models.dart](lib/features/auth/domain/auth_models.dart)
- [lib/features/auth/presentation/account_controller.dart](lib/features/auth/presentation/account_controller.dart)
- [lib/features/auth/presentation/auth_controller.dart](lib/features/auth/presentation/auth_controller.dart)
- [lib/features/auth/presentation/auth_loading_screen.dart](lib/features/auth/presentation/auth_loading_screen.dart)
- [lib/features/auth/presentation/auth_screens.dart](lib/features/auth/presentation/auth_screens.dart)
- [lib/features/sync/data/local_sync_store.dart](lib/features/sync/data/local_sync_store.dart)
- [lib/features/sync/data/remote_sync_store.dart](lib/features/sync/data/remote_sync_store.dart)
- [lib/features/sync/data/sync_service.dart](lib/features/sync/data/sync_service.dart)
- [lib/features/sync/domain/sync_record.dart](lib/features/sync/domain/sync_record.dart)
- [lib/features/sync/presentation/sync_providers.dart](lib/features/sync/presentation/sync_providers.dart)
- [lib/shared/widgets/password_field.dart](lib/shared/widgets/password_field.dart)
- [supabase/migrations/202611080001_auth_sync.sql](supabase/migrations/202611080001_auth_sync.sql)
- [supabase/tests/sync_security.mjs](supabase/tests/sync_security.mjs)
- [test/account_database_test.dart](test/account_database_test.dart)
- [test/auth_repository_test.dart](test/auth_repository_test.dart)
- [test/auth_validation_test.dart](test/auth_validation_test.dart)
- [test/auth_widget_test.dart](test/auth_widget_test.dart)
- [test/support/auth_fixtures.dart](test/support/auth_fixtures.dart)
- [test/sync_service_test.dart](test/sync_service_test.dart)
- PHASE6A_FILES.md (this manifest and snapshot)

## Edited files

- [.gitignore](.gitignore)
- [README.md](README.md)
- [android/app/src/main/AndroidManifest.xml](android/app/src/main/AndroidManifest.xml)
- [lib/app/app.dart](lib/app/app.dart)
- [lib/core/constants/app_routes.dart](lib/core/constants/app_routes.dart)
- [lib/core/database/app_database.dart](lib/core/database/app_database.dart)
- [lib/core/database/app_database.g.dart](lib/core/database/app_database.g.dart)
- [lib/core/router/app_router.dart](lib/core/router/app_router.dart)
- [lib/features/flashcards/data/review_repository.dart](lib/features/flashcards/data/review_repository.dart)
- [lib/features/flashcards/data/word_enrollment.dart](lib/features/flashcards/data/word_enrollment.dart)
- [lib/features/lessons/data/lesson_completion_repository.dart](lib/features/lessons/data/lesson_completion_repository.dart)
- [lib/features/profile/presentation/profile_screen.dart](lib/features/profile/presentation/profile_screen.dart)
- [linux/flutter/generated_plugin_registrant.cc](linux/flutter/generated_plugin_registrant.cc)
- [linux/flutter/generated_plugins.cmake](linux/flutter/generated_plugins.cmake)
- [macos/Flutter/GeneratedPluginRegistrant.swift](macos/Flutter/GeneratedPluginRegistrant.swift)
- [pubspec.lock](pubspec.lock)
- [pubspec.yaml](pubspec.yaml)
- [test/widget_test.dart](test/widget_test.dart)
- [windows/flutter/generated_plugin_registrant.cc](windows/flutter/generated_plugin_registrant.cc)
- [windows/flutter/generated_plugins.cmake](windows/flutter/generated_plugins.cmake)

Full contents follow. Drift-generated code, the dependency lockfile, and platform plugin registrations are generated artifacts; do not edit them manually.

## SUPABASE_SETUP.md

````markdown
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
````

## config.example.json

```json
{
  "SUPABASE_URL": "https://YOUR_PROJECT_REF.supabase.co",
  "SUPABASE_PUBLISHABLE_KEY": "YOUR_PUBLISHABLE_KEY",
  "AUTH_REDIRECT_URL": "io.languagelearning.app://auth-callback"
}
```

## lib/core/config/supabase_config.dart

```dart
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final class SupabaseConfig {
  const SupabaseConfig({
    this.url = const String.fromEnvironment('SUPABASE_URL'),
    this.publishableKey = const String.fromEnvironment(
      'SUPABASE_PUBLISHABLE_KEY',
    ),
    this.authRedirect = const String.fromEnvironment(
      'AUTH_REDIRECT_URL',
      defaultValue: 'io.languagelearning.app://auth-callback',
    ),
  });
  final String url;
  final String publishableKey;
  final String authRedirect;
  bool get isConfigured {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !uri.hasAuthority ||
        !{'https', 'http'}.contains(uri.scheme)) {
      return false;
    }
    if (publishableKey.startsWith('sb_publishable_')) return true;
    // Legacy anon JWTs are also public client keys; service-role keys are rejected.
    try {
      final parts = publishableKey.split('.');
      if (parts.length != 3) return false;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      return payload is Map && payload['role'] == 'anon';
    } catch (_) {
      return false;
    }
  }
}

final supabaseConfigProvider = Provider<SupabaseConfig>(
  (ref) => const SupabaseConfig(),
);

final supabaseClientProvider = FutureProvider<SupabaseClient>((ref) async {
  final config = ref.watch(supabaseConfigProvider);
  if (!config.isConfigured) {
    throw StateError('Supabase configuration is missing');
  }
  final instance = await Supabase.initialize(
    url: config.url,
    publishableKey: config.publishableKey,
    debug: false,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );
  return instance.client;
}, retry: (count, error) => null);
```

## lib/core/utils/sync_timestamp.dart

```dart
int nextSyncTimestamp(int previous, DateTime now) {
  final current = now.toUtc().microsecondsSinceEpoch;
  return current > previous ? current : previous + 1;
}
```

## lib/features/auth/data/auth_repository.dart

```dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../domain/auth_models.dart';

abstract interface class AuthRepository {
  Stream<AuthIdentity?> watchIdentity();
  Future<void> signIn(String email, String password);
  Future<bool> register(String email, String password);
  Future<void> resetPassword(String email);
  Future<void> updatePassword(String password);
  Future<void> signInGoogle();
  Future<void> signOut();
}

final authRepositoryProvider = FutureProvider<AuthRepository>((ref) async {
  final config = ref.watch(supabaseConfigProvider);
  final client = await ref.watch(supabaseClientProvider.future);
  return SupabaseAuthRepository(client, redirectTo: config.authRedirect);
}, retry: (count, error) => null);

final authStateProvider = StreamProvider<AuthIdentity?>((ref) async* {
  final repository = await ref.watch(authRepositoryProvider.future);
  yield* repository.watchIdentity();
}, retry: (count, error) => null);

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this.client, {required this.redirectTo});
  final SupabaseClient client;
  final String redirectTo;
  bool _recovering = false;

  AuthIdentity? _identity(Session? session) => session == null
      ? null
      : AuthIdentity(
          id: session.user.id,
          email: session.user.email ?? '',
          needsPasswordReset: _recovering,
        );

  @override
  Stream<AuthIdentity?> watchIdentity() =>
      client.auth.onAuthStateChange.transform(
        StreamTransformer.fromHandlers(
          handleData: (event, sink) {
            if (event.event == AuthChangeEvent.passwordRecovery) {
              _recovering = true;
            }
            if (event.event == AuthChangeEvent.signedOut ||
                event.event == AuthChangeEvent.userUpdated) {
              _recovering = false;
            }
            sink.add(_identity(event.session));
          },
          handleError: (Object error, StackTrace stack, sink) {
            // Network refresh failures must not lock a cached account out of local lessons.
            final cached = client.auth.currentSession;
            if (cached != null) {
              sink.add(_identity(cached));
            } else {
              sink.addError(error, stack);
            }
          },
        ),
      );

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AuthFailure {
      rethrow;
    } on AuthException catch (error) {
      throw AuthFailure(authMessageForCode(error.code));
    } catch (_) {
      throw AuthFailure(authMessageForCode('network'));
    }
  }

  @override
  Future<void> signIn(String email, String password) => _guard(() async {
    await client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  });
  @override
  Future<bool> register(String email, String password) => _guard(() async {
    final response = await client.auth.signUp(
      email: email.trim(),
      password: password,
      emailRedirectTo: redirectTo,
    );
    return response.session != null;
  });
  @override
  Future<void> resetPassword(String email) => _guard(
    () =>
        client.auth.resetPasswordForEmail(email.trim(), redirectTo: redirectTo),
  );
  @override
  Future<void> updatePassword(String password) => _guard(() async {
    await client.auth.updateUser(UserAttributes(password: password));
  });
  @override
  Future<void> signInGoogle() => _guard(() async {
    final launched = await client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: redirectTo,
    );
    if (!launched) {
      throw const AuthFailure('The sign-in browser could not be opened.');
    }
  });
  @override
  Future<void> signOut() async {
    try {
      await client.auth
          .signOut(scope: SignOutScope.local)
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      if (client.auth.currentSession != null) rethrow;
    }
  }
}
```

## lib/features/auth/domain/auth_models.dart

```dart
final class AuthIdentity {
  const AuthIdentity({
    required this.id,
    required this.email,
    this.needsPasswordReset = false,
  });
  final String id;
  final String email;
  final bool needsPasswordReset;
}

final class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;
}

enum AuthFormMode { login, register, forgotPassword, resetPassword }

abstract final class AuthValidation {
  static String? email(String? value) {
    final text = value?.trim() ?? '';
    return text.length <= 254 &&
            RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(text)
        ? null
        : 'Enter a valid email address.';
  }

  static String? password(String? value, {bool creating = false}) {
    if (value == null || value.isEmpty) return 'Enter your password.';
    if (creating && value.length < 8) return 'Use at least 8 characters.';
    return null;
  }

  static String? confirmation(String? value, String password) =>
      value == password ? null : 'Passwords do not match.';
}

String authMessageForCode(String? code) => switch (code) {
  'invalid_credentials' => 'The email or password is incorrect.',
  'email_not_confirmed' => 'Confirm your email before signing in.',
  'user_already_exists' ||
  'email_exists' => 'An account already uses this email. Try signing in.',
  'weak_password' => 'Choose a stronger password with at least 8 characters.',
  'over_request_rate_limit' || 'over_email_send_rate_limit' =>
    'Too many requests. Please wait and try again.',
  'signup_disabled' => 'Registration is currently unavailable.',
  'provider_disabled' ||
  'oauth_provider_not_supported' => 'Google sign-in is currently unavailable.',
  'same_password' => 'Choose a different password.',
  'network' => 'Check your connection and try again.',
  _ => 'We could not complete this request. Please try again.',
};
```

## lib/features/auth/presentation/account_controller.dart

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository.dart';
import 'auth_controller.dart';

final accountControllerProvider =
    NotifierProvider.autoDispose<AccountController, AuthActionState>(
      AccountController.new,
    );

class AccountController extends Notifier<AuthActionState> {
  @override
  AuthActionState build() => const AuthActionState();

  Future<void> signOut() async {
    if (state.busy) return;
    state = const AuthActionState(busy: true);
    try {
      final repository = await ref.read(authRepositoryProvider.future);
      await repository.signOut();
      if (ref.mounted) state = const AuthActionState();
    } catch (_) {
      if (ref.mounted) {
        state = const AuthActionState(
          error: 'We could not sign you out. Please try again.',
        );
      }
    }
  }
}
```

## lib/features/auth/presentation/auth_controller.dart

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository.dart';
import '../domain/auth_models.dart';

final class AuthActionState {
  const AuthActionState({this.busy = false, this.message, this.error});
  final bool busy;
  final String? message;
  final String? error;
}

final authControllerProvider = NotifierProvider.autoDispose
    .family<AuthController, AuthActionState, AuthFormMode>(AuthController.new);

class AuthController extends Notifier<AuthActionState> {
  AuthController(this.mode);
  final AuthFormMode mode;
  @override
  AuthActionState build() => const AuthActionState();

  Future<void> submit(String email, String password) async {
    await _run((repository) async {
      switch (mode) {
        case AuthFormMode.login:
          await repository.signIn(email, password);
          return null;
        case AuthFormMode.register:
          final signedIn = await repository.register(email, password);
          return signedIn
              ? null
              : 'Check your email to confirm your account, then sign in.';
        case AuthFormMode.forgotPassword:
          await repository.resetPassword(email);
          return 'If an account exists for this email, a password reset link has been sent.';
        case AuthFormMode.resetPassword:
          await repository.updatePassword(password);
          return 'Your password has been updated.';
      }
    });
  }

  Future<void> google() => _run((repository) async {
    await repository.signInGoogle();
    return 'Finish signing in in the browser.';
  });

  Future<void> _run(Future<String?> Function(AuthRepository) action) async {
    if (state.busy) return;
    state = const AuthActionState(busy: true);
    try {
      final repository = await ref.read(authRepositoryProvider.future);
      final message = await action(repository);
      if (ref.mounted) state = AuthActionState(message: message);
    } on AuthFailure catch (error) {
      if (ref.mounted) state = AuthActionState(error: error.message);
    } catch (_) {
      if (ref.mounted) {
        state = const AuthActionState(
          error:
              'Sign-in is unavailable on this build. Please try again later.',
        );
      }
    }
  }
}
```

## lib/features/auth/presentation/auth_loading_screen.dart

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/async_status_view.dart';
import '../../sync/presentation/sync_providers.dart';
import '../data/auth_repository.dart';

class AuthLoadingScreen extends ConsumerWidget {
  const AuthLoadingScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identity = ref.watch(authStateProvider).asData?.value;
    final ready = identity == null
        ? const AsyncLoading<void>()
        : ref.watch(accountReadyProvider);
    return Scaffold(
      body: AsyncStatusView(
        loading: !ready.hasError,
        message: ready.hasError
            ? 'Your local progress could not be opened.'
            : 'Opening your local progress…',
        onRetry: ready.hasError
            ? () => ref.invalidate(accountReadyProvider)
            : null,
      ),
    );
  }
}
```

## lib/features/auth/presentation/auth_screens.dart

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/constants/app_routes.dart';
import '../../../shared/widgets/password_field.dart';
import '../../../shared/widgets/responsive_body.dart';
import '../data/auth_repository.dart';
import '../domain/auth_models.dart';
import 'auth_controller.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const AuthFormScreen(mode: AuthFormMode.login);
}

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const AuthFormScreen(mode: AuthFormMode.register);
}

class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const AuthFormScreen(mode: AuthFormMode.forgotPassword);
}

class ResetPasswordScreen extends StatelessWidget {
  const ResetPasswordScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const AuthFormScreen(mode: AuthFormMode.resetPassword);
}

class AuthFormScreen extends ConsumerStatefulWidget {
  const AuthFormScreen({super.key, required this.mode});
  final AuthFormMode mode;
  @override
  ConsumerState<AuthFormScreen> createState() => _AuthFormScreenState();
}

class _AuthFormScreenState extends ConsumerState<AuthFormScreen> {
  final _key = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  void _submit() {
    if (_key.currentState?.validate() != true) return;
    FocusScope.of(context).unfocus();
    ref
        .read(authControllerProvider(widget.mode).notifier)
        .submit(_email.text, _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final mode = widget.mode;
    final action = ref.watch(authControllerProvider(mode));
    final unavailable = ref.watch(authStateProvider).hasError;
    final creating =
        mode == AuthFormMode.register || mode == AuthFormMode.resetPassword;
    final title = switch (mode) {
      AuthFormMode.login => 'Welcome back',
      AuthFormMode.register => 'Create your account',
      AuthFormMode.forgotPassword => 'Forgot password?',
      AuthFormMode.resetPassword => 'Set a new password',
    };
    final label = switch (mode) {
      AuthFormMode.login => 'Sign in',
      AuthFormMode.register => 'Register',
      AuthFormMode.forgotPassword => 'Send reset link',
      AuthFormMode.resetPassword => 'Update password',
    };
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(mode == AuthFormMode.login ? 'Account' : label),
        leading:
            mode == AuthFormMode.login || mode == AuthFormMode.resetPassword
            ? null
            : BackButton(onPressed: () => context.go(AppRoutes.login)),
      ),
      body: ResponsiveBody(
        child: Form(
          key: _key,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 12),
                Text(
                  mode == AuthFormMode.login
                      ? 'Keep your progress with your account.'
                      : 'Your learning journey belongs to you.',
                ),
                const SizedBox(height: 28),
                if (unavailable) ...[
                  const Text('Sign-in is unavailable on this build.'),
                  TextButton(
                    onPressed: () => ref.invalidate(supabaseClientProvider),
                    child: const Text('Retry connection'),
                  ),
                  const SizedBox(height: 16),
                ],
                if (mode != AuthFormMode.resetPassword) ...[
                  TextFormField(
                    key: const ValueKey('auth-email'),
                    controller: _email,
                    enabled: !action.busy,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    textInputAction: mode == AuthFormMode.forgotPassword
                        ? TextInputAction.done
                        : TextInputAction.next,
                    validator: AuthValidation.email,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      errorMaxLines: 3,
                      border: OutlineInputBorder(),
                    ),
                    onFieldSubmitted: mode == AuthFormMode.forgotPassword
                        ? (_) => _submit()
                        : null,
                  ),
                  const SizedBox(height: 16),
                ],
                if (mode != AuthFormMode.forgotPassword) ...[
                  PasswordField(
                    key: const ValueKey('auth-password'),
                    controller: _password,
                    label: 'Password',
                    enabled: !action.busy,
                    validator: (value) =>
                        AuthValidation.password(value, creating: creating),
                    onSubmitted: creating ? null : (_) => _submit(),
                  ),
                  const SizedBox(height: 16),
                ],
                if (creating) ...[
                  PasswordField(
                    key: const ValueKey('auth-confirmation'),
                    controller: _confirmation,
                    label: 'Confirm password',
                    enabled: !action.busy,
                    validator: (value) =>
                        AuthValidation.confirmation(value, _password.text),
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 16),
                ],
                _AuthNotice(action: action),
                FilledButton(
                  onPressed: action.busy ? null : _submit,
                  child: Text(action.busy ? 'Please wait…' : label),
                ),
                if (mode == AuthFormMode.login ||
                    mode == AuthFormMode.register) ...[
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: action.busy
                        ? null
                        : ref
                              .read(authControllerProvider(mode).notifier)
                              .google,
                    child: const Text('Continue with Google'),
                  ),
                ],
                if (mode == AuthFormMode.login) ...[
                  TextButton(
                    onPressed: action.busy
                        ? null
                        : () => context.go(AppRoutes.register),
                    child: const Text('Create an account'),
                  ),
                  TextButton(
                    onPressed: action.busy
                        ? null
                        : () => context.go(AppRoutes.forgotPassword),
                    child: const Text('Forgot password?'),
                  ),
                ] else if (mode != AuthFormMode.resetPassword)
                  TextButton(
                    onPressed: action.busy
                        ? null
                        : () => context.go(AppRoutes.login),
                    child: const Text('Back to sign in'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthNotice extends StatelessWidget {
  const _AuthNotice({required this.action});
  final AuthActionState action;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (action.error != null)
        Semantics(
          liveRegion: true,
          child: Text(
            action.error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      if (action.message != null)
        Semantics(liveRegion: true, child: Text(action.message!)),
      if (action.error != null || action.message != null)
        const SizedBox(height: 16),
    ],
  );
}
```

## lib/features/sync/data/local_sync_store.dart

```dart
import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../domain/sync_record.dart';

class LocalSyncStore {
  const LocalSyncStore(this.database);
  final AppDatabase database;

  Future<SyncSnapshot> snapshot({bool dirtyOnly = true}) =>
      database.transaction(() async {
        final statsQuery = database.select(database.userStats);
        final wordsQuery = database.select(database.wordProgress);
        final lessonsQuery = database.select(database.lessonProgress);
        if (dirtyOnly) {
          statsQuery.where((row) => row.dirty.equals(true));
          wordsQuery.where((row) => row.dirty.equals(true));
          lessonsQuery.where((row) => row.dirty.equals(true));
        }
        final stats = await statsQuery.get();
        final words = await wordsQuery.get();
        final lessons = await lessonsQuery.get();
        return SyncSnapshot([
          for (final row in stats)
            SyncRecord.fromJson(SyncKind.stats, {
              'xp': row.xp,
              'streak': row.streak,
              'last_active_date': row.lastActiveDate?.toUtc().toIso8601String(),
              'updated_at': row.updatedAt,
            }),
          for (final row in words)
            SyncRecord.fromJson(SyncKind.word, {
              'word_id': row.wordId,
              'ease_factor': row.easeFactor,
              'interval_days': row.intervalDays,
              'repetitions': row.repetitions,
              'due_date': row.dueDate.toUtc().toIso8601String(),
              'updated_at': row.updatedAt,
            }),
          for (final row in lessons)
            SyncRecord.fromJson(SyncKind.lesson, {
              'lesson_id': row.lessonId,
              'completed': row.completed,
              'best_score': row.bestScore,
              'completed_at': row.completedAt?.toUtc().toIso8601String(),
              'updated_at': row.updatedAt,
            }),
        ]);
      });

  Future<void> merge(
    SyncSnapshot remote, {
    bool imported = false,
  }) => database.transaction(() async {
    for (final row in remote.records) {
      final data = row.data;
      DateTime? date(String key) => data[key] == null
          ? null
          : DateTime.parse(data[key] as String).toUtc();
      switch (row.kind) {
        case SyncKind.stats:
          final current = await database
              .select(database.userStats)
              .getSingleOrNull();
          if (!remoteWins(current?.updatedAt, row.updatedAt)) continue;
          if (current != null &&
              current.updatedAt == row.updatedAt &&
              current.dirty == imported &&
              current.xp == data['xp'] &&
              current.streak == data['streak'] &&
              current.lastActiveDate?.toUtc() == date('last_active_date')) {
            continue;
          }
          await database
              .into(database.userStats)
              .insertOnConflictUpdate(
                UserStatsCompanion.insert(
                  id: const Value(1),
                  xp: Value(data['xp'] as int),
                  streak: Value(data['streak'] as int),
                  lastActiveDate: Value(date('last_active_date')),
                  updatedAt: Value(row.updatedAt),
                  dirty: Value(imported),
                ),
              );
        case SyncKind.word:
          final current = await (database.select(
            database.wordProgress,
          )..where((table) => table.wordId.equals(row.id))).getSingleOrNull();
          if (!remoteWins(current?.updatedAt, row.updatedAt)) continue;
          if (current != null &&
              current.updatedAt == row.updatedAt &&
              current.dirty == imported &&
              current.easeFactor == data['ease_factor'] &&
              current.intervalDays == data['interval_days'] &&
              current.repetitions == data['repetitions'] &&
              current.dueDate.toUtc() == date('due_date')) {
            continue;
          }
          await database
              .into(database.wordProgress)
              .insertOnConflictUpdate(
                WordProgressCompanion.insert(
                  wordId: row.id,
                  easeFactor: Value(data['ease_factor'] as double),
                  intervalDays: Value(data['interval_days'] as int),
                  repetitions: Value(data['repetitions'] as int),
                  dueDate: date('due_date')!,
                  updatedAt: Value(row.updatedAt),
                  dirty: Value(imported),
                ),
              );
        case SyncKind.lesson:
          final current = await (database.select(
            database.lessonProgress,
          )..where((table) => table.lessonId.equals(row.id))).getSingleOrNull();
          if (!remoteWins(current?.updatedAt, row.updatedAt)) continue;
          if (current != null &&
              current.updatedAt == row.updatedAt &&
              current.dirty == imported &&
              current.completed == data['completed'] &&
              current.bestScore == data['best_score'] &&
              current.completedAt?.toUtc() == date('completed_at')) {
            continue;
          }
          await database
              .into(database.lessonProgress)
              .insertOnConflictUpdate(
                LessonProgressCompanion.insert(
                  lessonId: row.id,
                  completed: Value(data['completed'] as bool),
                  bestScore: Value(data['best_score'] as int),
                  completedAt: Value(date('completed_at')),
                  updatedAt: Value(row.updatedAt),
                  dirty: Value(imported),
                ),
              );
      }
    }
  });

  Future<void> importLegacy(AppDatabase legacy, String uid) async {
    final done = await (database.select(
      database.syncMetadata,
    )..where((row) => row.key.equals('legacyImported'))).getSingleOrNull();
    if (done != null) return;
    // Claim first. A failed copy can resume only for this account, never another user.
    final ownsLegacy = await legacy.transaction(() async {
      await legacy
          .into(legacy.syncMetadata)
          .insert(
            SyncMetadataCompanion.insert(key: 'legacyOwner', value: uid),
            mode: InsertMode.insertOrIgnore,
          );
      return (await (legacy.select(
                legacy.syncMetadata,
              )..where((row) => row.key.equals('legacyOwner'))).getSingle())
              .value ==
          uid;
    });
    await database.transaction(() async {
      if (ownsLegacy) {
        await merge(
          await LocalSyncStore(legacy).snapshot(dirtyOnly: false),
          imported: true,
        );
      }
      await database
          .into(database.syncMetadata)
          .insertOnConflictUpdate(
            SyncMetadataCompanion.insert(key: 'legacyImported', value: '1'),
          );
    });
  }

  Stream<void> watchChanges() => database
      .customSelect(
        '''SELECT 'stats' AS kind, CAST(id AS TEXT) AS row_id, updated_at, dirty FROM user_stats
           UNION ALL SELECT 'word', word_id, updated_at, dirty FROM word_progress
           UNION ALL SELECT 'lesson', lesson_id, updated_at, dirty FROM lesson_progress''',
        readsFrom: {
          database.userStats,
          database.wordProgress,
          database.lessonProgress,
        },
      )
      .watch()
      .map((rows) {});
}
```

## lib/features/sync/data/remote_sync_store.dart

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/json_reader.dart';
import '../domain/sync_record.dart';

abstract interface class RemoteSyncStore {
  Future<SyncSnapshot> exchange(String userId, SyncSnapshot local);
}

class SupabaseSyncStore implements RemoteSyncStore {
  const SupabaseSyncStore(this.client);
  final SupabaseClient client;

  @override
  Future<SyncSnapshot> exchange(String userId, SyncSnapshot local) async {
    if (client.auth.currentUser?.id != userId) {
      throw StateError('Account changed');
    }
    final result = await client.rpc(
      'sync_progress',
      params: {'p_user_id': userId, ...local.payload},
    );
    if (client.auth.currentUser?.id != userId) {
      throw StateError('Account changed');
    }
    return SyncSnapshot.fromJson(
      JsonReader.object(result, 'sync'),
      userId: userId,
    );
  }
}
```

## lib/features/sync/data/sync_service.dart

```dart
import 'dart:async';

import 'local_sync_store.dart';
import 'remote_sync_store.dart';

enum SyncStatus { idle, syncing, offline }

class SyncService {
  SyncService({
    required this.userId,
    required this.local,
    required this.remote,
    this.onStatus,
    this.retryInterval = const Duration(seconds: 30),
  });
  final String userId;
  final LocalSyncStore local;
  final RemoteSyncStore remote;
  final void Function(SyncStatus)? onStatus;
  final Duration retryInterval;
  StreamSubscription<void>? _changes;
  Timer? _retry;
  Timer? _debounce;
  bool _disposed = false;
  bool _running = false;
  bool _pending = false;

  void start() {
    if (_changes != null || _disposed) return;
    _changes = local.watchChanges().listen(
      (_) => request(),
      onError: (Object error) => onStatus?.call(SyncStatus.offline),
    );
    _retry = Timer.periodic(retryInterval, (_) => request());
    request();
  }

  void request() {
    if (_disposed) return;
    if (_running) {
      _pending = true;
      return;
    }
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => unawaited(syncOnce()),
    );
  }

  Future<void> syncOnce() async {
    if (_disposed || _running) return;
    _running = true;
    _pending = false;
    onStatus?.call(SyncStatus.syncing);
    try {
      final changes = await local.snapshot();
      if (_disposed) return;
      final merged = await remote
          .exchange(userId, changes)
          .timeout(const Duration(seconds: 15));
      if (_disposed) return;
      await local.merge(merged);
      if (!_disposed) onStatus?.call(SyncStatus.idle);
    } catch (_) {
      // Dirty rows stay on disk. Gameplay never waits for the network.
      if (!_disposed) onStatus?.call(SyncStatus.offline);
    } finally {
      _running = false;
      if (_pending && !_disposed) request();
    }
  }

  void dispose() {
    _disposed = true;
    _retry?.cancel();
    _debounce?.cancel();
    unawaited(_changes?.cancel());
  }
}
```

## lib/features/sync/domain/sync_record.dart

```dart
import '../../../core/utils/json_reader.dart';

enum SyncKind { stats, word, lesson }

final class SyncRecord {
  SyncRecord._(this.kind, this.id, this.updatedAt, JsonMap data)
    : data = Map.unmodifiable(data);
  final SyncKind kind;
  final String id;
  final int updatedAt;
  final JsonMap data;

  factory SyncRecord.fromJson(SyncKind kind, JsonMap json) {
    final stamp = JsonReader.integer(json, 'updated_at');
    if (stamp < 0) throw const FormatException('Invalid updated_at');
    String? date(String key, {bool optional = false}) {
      if (optional && json[key] == null) return null;
      final value = DateTime.tryParse(JsonReader.text(json, key));
      if (value == null) throw FormatException('Invalid $key');
      return value.toUtc().toIso8601String();
    }

    int count(String key) {
      final value = JsonReader.integer(json, key);
      if (value < 0) throw FormatException('Invalid $key');
      return value;
    }

    switch (kind) {
      case SyncKind.stats:
        return SyncRecord._(kind, 'stats', stamp, {
          'xp': count('xp'),
          'streak': count('streak'),
          'last_active_date': date('last_active_date', optional: true),
        });
      case SyncKind.word:
        final ease = json['ease_factor'];
        if (ease is! num || !ease.isFinite || ease < 1.3) {
          throw const FormatException('Invalid ease_factor');
        }
        return SyncRecord._(kind, JsonReader.text(json, 'word_id'), stamp, {
          'ease_factor': ease.toDouble(),
          'interval_days': count('interval_days'),
          'repetitions': count('repetitions'),
          'due_date': date('due_date'),
        });
      case SyncKind.lesson:
        final completed = json['completed'];
        final score = count('best_score');
        if (completed is! bool || score > 100) {
          throw const FormatException('Invalid lesson progress');
        }
        return SyncRecord._(kind, JsonReader.text(json, 'lesson_id'), stamp, {
          'completed': completed,
          'best_score': score,
          'completed_at': date('completed_at', optional: true),
        });
    }
  }

  JsonMap toJson() => {
    if (kind == SyncKind.word) 'word_id': id,
    if (kind == SyncKind.lesson) 'lesson_id': id,
    ...data,
    'updated_at': updatedAt,
  };
}

final class SyncSnapshot {
  SyncSnapshot(Iterable<SyncRecord> records)
    : records = List.unmodifiable(records);
  final List<SyncRecord> records;

  factory SyncSnapshot.fromJson(JsonMap json, {required String userId}) {
    if (json['schema_version'] != 1 || json['user_id'] != userId) {
      throw const FormatException('Sync response owner or version mismatch');
    }
    return SyncSnapshot([
      if (json['stats'] != null)
        SyncRecord.fromJson(
          SyncKind.stats,
          JsonReader.object(json['stats'], 'stats'),
        ),
      for (final value in JsonReader.list(json, 'words'))
        SyncRecord.fromJson(SyncKind.word, JsonReader.object(value, 'word')),
      for (final value in JsonReader.list(json, 'lessons'))
        SyncRecord.fromJson(
          SyncKind.lesson,
          JsonReader.object(value, 'lesson'),
        ),
    ]);
  }

  JsonMap get payload => {
    'p_stats': records
        .where((row) => row.kind == SyncKind.stats)
        .firstOrNull
        ?.toJson(),
    'p_words': records
        .where((row) => row.kind == SyncKind.word)
        .map((row) => row.toJson())
        .toList(),
    'p_lessons': records
        .where((row) => row.kind == SyncKind.lesson)
        .map((row) => row.toJson())
        .toList(),
  };
}

/// The remote value wins exact timestamp ties on every device.
bool remoteWins(int? localTimestamp, int remoteTimestamp) =>
    localTimestamp == null || remoteTimestamp >= localTimestamp;
```

## lib/features/sync/presentation/sync_providers.dart

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/database/app_database.dart';
import '../../auth/data/auth_repository.dart';
import '../data/local_sync_store.dart';
import '../data/remote_sync_store.dart';
import '../data/sync_service.dart';

final accountReadyProvider = FutureProvider<void>((ref) async {
  final uid = ref.watch(
    authStateProvider.select((value) => value.asData?.value?.id),
  );
  if (uid == null) return;
  final database = ref.watch(appDatabaseProvider);
  final legacy = AppDatabase();
  try {
    await LocalSyncStore(database).importLegacy(legacy, uid);
  } finally {
    await legacy.close();
  }
}, retry: (count, error) => null);

final syncStatusProvider = NotifierProvider<SyncStatusController, SyncStatus>(
  SyncStatusController.new,
);

class SyncStatusController extends Notifier<SyncStatus> {
  @override
  SyncStatus build() => SyncStatus.idle;
  void update(SyncStatus value) => state = value;
}

final syncServiceProvider = Provider<SyncService?>((ref) {
  final uid = ref.watch(
    authStateProvider.select((value) => value.asData?.value?.id),
  );
  final ready = ref.watch(accountReadyProvider);
  if (uid == null || !ready.hasValue || ready.hasError || ready.isLoading) {
    return null;
  }
  final client = ref.watch(supabaseClientProvider).asData?.value;
  if (client == null) return null;
  final service = SyncService(
    userId: uid,
    local: LocalSyncStore(ref.watch(appDatabaseProvider)),
    remote: SupabaseSyncStore(client),
    onStatus: (status) {
      if (ref.mounted) ref.read(syncStatusProvider.notifier).update(status);
    },
  );
  ref.onDispose(service.dispose);
  service.start();
  return service;
});
```

## lib/shared/widgets/password_field.dart

```dart
import 'package:flutter/material.dart';

class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.label,
    required this.validator,
    this.enabled = true,
    this.onSubmitted,
  });
  final TextEditingController controller;
  final String label;
  final FormFieldValidator<String> validator;
  final bool enabled;
  final ValueChanged<String>? onSubmitted;
  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscured = true;
  @override
  Widget build(BuildContext context) => TextFormField(
    controller: widget.controller,
    enabled: widget.enabled,
    obscureText: _obscured,
    autocorrect: false,
    enableSuggestions: false,
    validator: widget.validator,
    textInputAction: TextInputAction.done,
    onFieldSubmitted: widget.onSubmitted,
    decoration: InputDecoration(
      labelText: widget.label,
      errorMaxLines: 3,
      border: const OutlineInputBorder(),
      suffixIcon: IconButton(
        tooltip: _obscured ? 'Show password' : 'Hide password',
        onPressed: () => setState(() => _obscured = !_obscured),
        icon: Icon(
          _obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        ),
      ),
    ),
  );
}
```

## supabase/migrations/202611080001_auth_sync.sql

```sql
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
```

## supabase/tests/sync_security.mjs

```javascript
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
```

## test/account_database_test.dart

```dart
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/core/database/app_database.dart';
import 'package:myapp/features/sync/data/local_sync_store.dart';

void main() {
  setUp(() {
    // These tests intentionally open distinct in-memory executors for each account.
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });
  tearDown(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false);
  test(
    'schema version 1 migrates existing data to durable pending sync rows',
    () async {
      final database = AppDatabase.forTesting(
        NativeDatabase.memory(
          setup: (raw) {
            raw.execute('''
        CREATE TABLE lesson_progress (lesson_id TEXT PRIMARY KEY NOT NULL, completed INTEGER NOT NULL DEFAULT 0, best_score INTEGER NOT NULL DEFAULT 0, completed_at INTEGER);
        CREATE TABLE word_progress (word_id TEXT PRIMARY KEY NOT NULL, ease_factor REAL NOT NULL DEFAULT 2.5, interval_days INTEGER NOT NULL DEFAULT 0, repetitions INTEGER NOT NULL DEFAULT 0, due_date INTEGER NOT NULL);
        CREATE TABLE user_stats (id INTEGER PRIMARY KEY NOT NULL DEFAULT 1, xp INTEGER NOT NULL DEFAULT 0, streak INTEGER NOT NULL DEFAULT 0, last_active_date INTEGER);
        INSERT INTO user_stats(id, xp, streak) VALUES (1, 80, 3);
        INSERT INTO word_progress(word_id, due_date) VALUES ('ja_hello', 1000);
        INSERT INTO lesson_progress(lesson_id, completed, best_score) VALUES ('ja_greetings', 1, 90);
        PRAGMA user_version = 1;
      ''');
          },
        ),
      );
      addTearDown(database.close);
      final stats = await database.select(database.userStats).getSingle();
      expect(stats.xp, 80);
      expect(stats.streak, 3);
      expect(stats.updatedAt, 0);
      expect(stats.dirty, isTrue);
      expect(
        (await database.select(database.wordProgress).getSingle()).dirty,
        isTrue,
      );
      expect(
        (await database.select(database.lessonProgress).getSingle()).bestScore,
        90,
      );
      expect(await database.select(database.syncMetadata).get(), isEmpty);
    },
  );

  test(
    'legacy progress is claimed by one account and never copied to another',
    () async {
      final legacy = AppDatabase.forTesting(NativeDatabase.memory());
      final a = AppDatabase.forTesting(NativeDatabase.memory());
      final b = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(legacy.close);
      addTearDown(a.close);
      addTearDown(b.close);
      await legacy.select(legacy.userStats).getSingle();
      await legacy
          .update(legacy.userStats)
          .write(const UserStatsCompanion(xp: Value(80)));
      await legacy
          .into(legacy.wordProgress)
          .insert(
            WordProgressCompanion.insert(
              wordId: 'ja_hello',
              dueDate: DateTime.utc(2026, 11, 8),
            ),
          );
      await LocalSyncStore(a).importLegacy(legacy, 'A');
      await LocalSyncStore(b).importLegacy(legacy, 'B');
      expect((await a.select(a.userStats).getSingle()).xp, 80);
      expect((await a.select(a.wordProgress).get()).length, 1);
      expect((await b.select(b.userStats).getSingle()).xp, 0);
      expect(await b.select(b.wordProgress).get(), isEmpty);
      await a
          .update(a.userStats)
          .write(
            const UserStatsCompanion(xp: Value(100), updatedAt: Value(10)),
          );
      await LocalSyncStore(a).importLegacy(legacy, 'A');
      expect((await a.select(a.userStats).getSingle()).xp, 100);
    },
  );

  test(
    'account filenames are deterministic and cannot contain path separators',
    () {
      expect(AppDatabase.databaseName(null), 'language_learning');
      expect(
        AppDatabase.databaseName('A'),
        isNot(AppDatabase.databaseName('B')),
      );
      expect(AppDatabase.databaseName('a/b'), isNot(contains('/')));
      expect(AppDatabase.databaseName('A'), AppDatabase.databaseName('A'));
    },
  );
}
```

## test/auth_repository_test.dart

```dart
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myapp/features/auth/data/auth_repository.dart';
import 'package:myapp/features/auth/domain/auth_models.dart';

class MockClient extends Mock implements SupabaseClient {}

class MockAuth extends Mock implements GoTrueClient {}

class MockSession extends Mock implements Session {}

class MockUser extends Mock implements User {}

void main() {
  late MockClient client;
  late MockAuth auth;
  late MockSession session;
  late SupabaseAuthRepository repository;
  late StreamController<AuthState> events;
  setUp(() {
    client = MockClient();
    auth = MockAuth();
    session = MockSession();
    final user = MockUser();
    events = StreamController<AuthState>.broadcast(sync: true);
    when(() => client.auth).thenReturn(auth);
    when(() => auth.onAuthStateChange).thenAnswer((_) => events.stream);
    when(() => auth.currentSession).thenReturn(session);
    when(() => session.user).thenReturn(user);
    when(() => user.id).thenReturn('account-a');
    when(() => user.email).thenReturn('a@example.com');
    repository = SupabaseAuthRepository(
      client,
      redirectTo: 'io.languagelearning.app://auth-callback',
    );
  });
  tearDown(() => events.close());

  test(
    'refresh network errors retain a cached identity for offline lessons',
    () {
      final received = <AuthIdentity?>[];
      final subscription = repository.watchIdentity().listen(received.add);
      addTearDown(subscription.cancel);
      events.add(AuthState(AuthChangeEvent.initialSession, session));
      events.addError(const AuthException('Network unavailable'));
      expect(received.map((identity) => identity!.id), [
        'account-a',
        'account-a',
      ]);
    },
  );
  test('password recovery event routes to reset until password is updated', () {
    final received = <AuthIdentity?>[];
    final subscription = repository.watchIdentity().listen(received.add);
    addTearDown(subscription.cancel);
    events.add(AuthState(AuthChangeEvent.passwordRecovery, session));
    events.add(AuthState(AuthChangeEvent.userUpdated, session));
    expect(received.map((identity) => identity!.needsPasswordReset), [
      true,
      false,
    ]);
  });
  test('invalid credentials become a friendly domain failure', () async {
    when(
      () => auth.signInWithPassword(email: 'a@example.com', password: 'wrong'),
    ).thenThrow(
      const AuthException(
        'Invalid login credentials',
        code: 'invalid_credentials',
      ),
    );
    await expectLater(
      repository.signIn(' a@example.com ', 'wrong'),
      throwsA(
        isA<AuthFailure>().having(
          (error) => error.message,
          'message',
          contains('incorrect'),
        ),
      ),
    );
  });
}
```

## test/auth_validation_test.dart

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/core/config/supabase_config.dart';
import 'package:myapp/features/auth/domain/auth_models.dart';

void main() {
  test(
    'email validation accepts trimmed addresses and rejects malformed input',
    () {
      expect(AuthValidation.email(' learner@example.com '), isNull);
      for (final value in ['', 'missing-at', 'a@b', 'a b@example.com']) {
        expect(AuthValidation.email(value), isNotNull);
      }
    },
  );
  test('new passwords need eight characters; sign-in accepts existing shorter passwords', () {
    expect(AuthValidation.password(''), isNotNull);
    expect(AuthValidation.password('short', creating: true), isNotNull);
    expect(AuthValidation.password('short'), isNull);
    expect(AuthValidation.password('secret123', creating: true), isNull);
    expect(AuthValidation.confirmation('secret123', 'secret123'), isNull);
    expect(AuthValidation.confirmation('different', 'secret123'), isNotNull);
  });
  test('auth error codes map to clear messages', () {
    expect(authMessageForCode('invalid_credentials'), contains('incorrect'));
    expect(
      authMessageForCode('email_not_confirmed'),
      contains('Confirm your email'),
    );
    expect(authMessageForCode('over_email_send_rate_limit'), contains('wait'));
    expect(authMessageForCode('network'), contains('connection'));
    expect(authMessageForCode('unknown'), contains('try again'));
  });
  test('configuration accepts only public client keys and valid URLs', () {
    expect(const SupabaseConfig().isConfigured, isFalse);
    expect(
      const SupabaseConfig(
        url: 'https://example.supabase.co',
        publishableKey: 'sb_publishable_example',
      ).isConfigured,
      isTrue,
    );
    expect(
      const SupabaseConfig(
        url: 'https://example.supabase.co',
        publishableKey: 'sb_secret_private',
      ).isConfigured,
      isFalse,
    );
    String jwt(String role) =>
        'header.${base64Url.encode(utf8.encode(jsonEncode({'role': role})))}.signature';
    expect(
      SupabaseConfig(
        url: 'https://example.supabase.co',
        publishableKey: jwt('anon'),
      ).isConfigured,
      isTrue,
    );
    expect(
      SupabaseConfig(
        url: 'https://example.supabase.co',
        publishableKey: jwt('service_role'),
      ).isConfigured,
      isFalse,
    );
  });
}
```

## test/auth_widget_test.dart

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/core/router/app_router.dart';
import 'package:myapp/features/auth/domain/auth_models.dart';

import 'support/auth_fixtures.dart';
import 'support/phase3_fixtures.dart';
import 'widget_test.dart' show AppHarness, mount, tapText;

Future<void> enter(WidgetTester tester, String key, String value) async {
  final target = find.byKey(ValueKey(key));
  final field = key == 'auth-email'
      ? target
      : find.descendant(of: target, matching: find.byType(TextFormField));
  await tester.ensureVisible(field);
  await tester.enterText(field, value);
}

Future<void> submit(WidgetTester tester, String label) async {
  final button = find.widgetWithText(FilledButton, label);
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'missing Supabase configuration shows a login error instead of crashing',
    (tester) async {
      final harness = AppHarness(useRealAuth: true);
      await mount(tester, harness);
      expect(
        harness.container.read(appRouterProvider).state.uri.path,
        '/login',
      );
      expect(
        find.text('Sign-in is unavailable on this build.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'logged-out routes redirect to login; valid login returns to Learn',
    (tester) async {
      final repository = MemoryAuthRepository();
      addTearDown(repository.close);
      final harness = AppHarness(
        authRepository: repository,
        settings: completedSettings(),
      );
      await mount(tester, harness);
      final router = harness.container.read(appRouterProvider);
      expect(router.state.uri.path, '/login');
      router.go('/lesson/ja_greetings');
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/login');
      await submit(tester, 'Sign in');
      expect(find.text('Enter a valid email address.'), findsOneWidget);
      await enter(tester, 'auth-email', 'a@example.com');
      await enter(tester, 'auth-password', 'password123');
      await submit(tester, 'Sign in');
      expect(router.state.uri.path, '/home');
      await tester.tap(find.byType(NavigationDestination).at(2));
      await tester.pumpAndSettle();
      expect(find.text('a@example.com'), findsOneWidget);
      await tapText(tester, 'Sign out');
      expect(router.state.uri.path, '/login');
    },
  );

  testWidgets(
    'registration validates confirmation and explains email verification',
    (tester) async {
      final repository = MemoryAuthRepository();
      addTearDown(repository.close);
      final harness = AppHarness(authRepository: repository);
      await mount(tester, harness);
      await tapText(tester, 'Create an account');
      await enter(tester, 'auth-email', 'new@example.com');
      await enter(tester, 'auth-password', 'password123');
      await enter(tester, 'auth-confirmation', 'different');
      await submit(tester, 'Register');
      expect(find.text('Passwords do not match.'), findsOneWidget);
      await enter(tester, 'auth-confirmation', 'password123');
      await submit(tester, 'Register');
      expect(
        find.text('Check your email to confirm your account, then sign in.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'forgot-password email and recovery link complete the reset flow',
    (tester) async {
      final repository = MemoryAuthRepository();
      addTearDown(repository.close);
      final harness = AppHarness(
        authRepository: repository,
        settings: completedSettings(),
      );
      await mount(tester, harness);
      await tapText(tester, 'Forgot password?');
      await enter(tester, 'auth-email', 'reset@example.com');
      await submit(tester, 'Send reset link');
      expect(repository.resetEmail, 'reset@example.com');
      expect(find.textContaining('If an account exists'), findsOneWidget);
      repository.emit(
        const AuthIdentity(
          id: 'account-a',
          email: 'reset@example.com',
          needsPasswordReset: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        harness.container.read(appRouterProvider).state.uri.path,
        '/reset-password',
      );
      await enter(tester, 'auth-password', 'newpassword123');
      await enter(tester, 'auth-confirmation', 'newpassword123');
      await submit(tester, 'Update password');
      expect(repository.updatedPassword, 'newpassword123');
      expect(harness.container.read(appRouterProvider).state.uri.path, '/home');
    },
  );

  testWidgets(
    'login errors preserve input and in-flight submits cannot repeat',
    (tester) async {
      final repository = MemoryAuthRepository()..failLogin = true;
      addTearDown(repository.close);
      final harness = AppHarness(
        authRepository: repository,
        settings: completedSettings(),
      );
      await mount(tester, harness);
      await enter(tester, 'auth-email', 'a@example.com');
      await enter(tester, 'auth-password', 'password123');
      await submit(tester, 'Sign in');
      expect(find.text('The email or password is incorrect.'), findsOneWidget);
      repository.failLogin = false;
      repository.loginGate = Completer<void>();
      await submit(tester, 'Sign in');
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Please wait…'),
            )
            .onPressed,
        isNull,
      );
      expect(repository.loginCalls, 2);
      repository.loginGate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
    },
  );

  testWidgets('Google starts OAuth and its auth callback opens the app', (
    tester,
  ) async {
    final repository = MemoryAuthRepository();
    addTearDown(repository.close);
    final harness = AppHarness(
      authRepository: repository,
      settings: completedSettings(),
    );
    await mount(tester, harness);
    await tapText(tester, 'Continue with Google');
    expect(repository.googleCalls, 1);
    expect(find.text('Finish signing in in the browser.'), findsOneWidget);
    repository.emit(
      const AuthIdentity(id: 'google-account', email: 'google@example.com'),
    );
    await tester.pumpAndSettle();
    expect(harness.container.read(appRouterProvider).state.uri.path, '/home');
  });

  for (final brightness in Brightness.values) {
    testWidgets('auth forms fit 320px with 200% text in ${brightness.name}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final repository = MemoryAuthRepository();
      addTearDown(repository.close);
      final harness = AppHarness(authRepository: repository);
      await mount(tester, harness);
      for (final route in ['/login', '/register', '/forgot-password']) {
        harness.container.read(appRouterProvider).go(route);
        await tester.pumpAndSettle();
        await tester.drag(
          find.byType(SingleChildScrollView).first,
          const Offset(0, -600),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: route);
      }
      repository.emit(
        const AuthIdentity(
          id: 'account-a',
          email: 'a@example.com',
          needsPasswordReset: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Set a new password'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
```

## test/support/auth_fixtures.dart

```dart
import 'dart:async';

import 'package:myapp/features/auth/data/auth_repository.dart';
import 'package:myapp/features/auth/domain/auth_models.dart';

class MemoryAuthRepository implements AuthRepository {
  MemoryAuthRepository({this.identity});
  AuthIdentity? identity;
  final changes = StreamController<AuthIdentity?>.broadcast();
  bool failLogin = false;
  bool confirmEmail = true;
  int loginCalls = 0;
  int googleCalls = 0;
  String? resetEmail;
  String? updatedPassword;
  Completer<void>? loginGate;

  void emit(AuthIdentity? value) {
    identity = value;
    changes.add(value);
  }

  Future<void> close() => changes.close();
  @override
  Stream<AuthIdentity?> watchIdentity() async* {
    yield identity;
    yield* changes.stream;
  }

  @override
  Future<void> signIn(String email, String password) async {
    loginCalls++;
    await loginGate?.future;
    if (failLogin) {
      throw const AuthFailure('The email or password is incorrect.');
    }
    emit(AuthIdentity(id: 'account-a', email: email.trim()));
  }

  @override
  Future<bool> register(String email, String password) async {
    if (!confirmEmail) emit(AuthIdentity(id: 'account-a', email: email.trim()));
    return !confirmEmail;
  }

  @override
  Future<void> resetPassword(String email) async {
    resetEmail = email.trim();
  }

  @override
  Future<void> updatePassword(String password) async {
    updatedPassword = password;
    emit(AuthIdentity(id: identity!.id, email: identity!.email));
  }

  @override
  Future<void> signInGoogle() async {
    googleCalls++;
  }

  @override
  Future<void> signOut() async {
    emit(null);
  }
}
```

## test/sync_service_test.dart

```dart
import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/core/database/app_database.dart';
import 'package:myapp/core/utils/sync_timestamp.dart';
import 'package:myapp/features/sync/data/local_sync_store.dart';
import 'package:myapp/features/sync/data/remote_sync_store.dart';
import 'package:myapp/features/sync/data/sync_service.dart';
import 'package:myapp/features/sync/domain/sync_record.dart';

SyncRecord statsRecord(int xp, int timestamp) => SyncRecord.fromJson(
  SyncKind.stats,
  {'xp': xp, 'streak': 1, 'last_active_date': null, 'updated_at': timestamp},
);

class MemoryRemoteStore implements RemoteSyncStore {
  final users = <String, Map<String, SyncRecord>>{};
  bool fail = false;
  int calls = 0;
  Completer<void>? gate;
  final started = Completer<void>();
  @override
  Future<SyncSnapshot> exchange(String userId, SyncSnapshot local) async {
    calls++;
    if (!started.isCompleted) started.complete();
    await gate?.future;
    if (fail) throw StateError('Offline');
    final records = users.putIfAbsent(userId, () => {});
    for (final row in local.records) {
      final key = '${row.kind.name}/${row.id}';
      if (records[key] == null || row.updatedAt > records[key]!.updatedAt) {
        records[key] = row;
      }
    }
    return SyncSnapshot(records.values);
  }
}

void main() {
  late AppDatabase database;
  late LocalSyncStore local;
  late MemoryRemoteStore remote;
  late SyncService service;
  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    local = LocalSyncStore(database);
    remote = MemoryRemoteStore();
    service = SyncService(userId: 'A', local: local, remote: remote);
  });
  tearDown(() async {
    service.dispose();
    await database.close();
  });

  Future<void> editStats(int xp, int stamp) async {
    await database.select(database.userStats).getSingle();
    await database
        .update(database.userStats)
        .write(
          UserStatsCompanion(
            xp: Value(xp),
            updatedAt: Value(stamp),
            dirty: const Value(true),
          ),
        );
  }

  test(
    'newer remote data replaces local data and clears pending flags',
    () async {
      await editStats(10, 90);
      remote.users['A'] = {'stats/stats': statsRecord(50, 100)};
      await service.syncOnce();
      final row = await database.select(database.userStats).getSingle();
      expect(row.xp, 50);
      expect(row.updatedAt, 100);
      expect(row.dirty, isFalse);
    },
  );

  test(
    'newer local data uploads, including lower counters under LWW',
    () async {
      await editStats(20, 101);
      remote.users['A'] = {'stats/stats': statsRecord(50, 100)};
      await service.syncOnce();
      expect(remote.users['A']!['stats/stats']!.data['xp'], 20);
      expect(
        (await database.select(database.userStats).getSingle()).dirty,
        isFalse,
      );
    },
  );

  test('remote value consistently wins equal timestamps', () async {
    await editStats(10, 100);
    remote.users['A'] = {'stats/stats': statsRecord(50, 100)};
    await service.syncOnce();
    expect((await database.select(database.userStats).getSingle()).xp, 50);
  });

  test(
    'network failure preserves pending changes for a new service instance',
    () async {
      await editStats(35, 100);
      remote.fail = true;
      await service.syncOnce();
      expect(
        (await database.select(database.userStats).getSingle()).dirty,
        isTrue,
      );
      expect((await local.snapshot()).records, hasLength(1));
      service.dispose();
      remote.fail = false;
      service = SyncService(
        userId: 'A',
        local: LocalSyncStore(database),
        remote: remote,
      );
      await service.syncOnce();
      expect(remote.users['A']!['stats/stats']!.data['xp'], 35);
      expect((await local.snapshot()).records, isEmpty);
    },
  );

  test(
    'in-flight response cannot overwrite or acknowledge a newer local edit',
    () async {
      await editStats(10, 100);
      remote.gate = Completer<void>();
      final pending = service.syncOnce();
      await remote.started.future;
      await editStats(40, 101);
      remote.gate!.complete();
      await pending;
      var row = await database.select(database.userStats).getSingle();
      expect(row.xp, 40);
      expect(row.dirty, isTrue);
      await service.syncOnce();
      row = await database.select(database.userStats).getSingle();
      expect(row.dirty, isFalse);
      expect(remote.users['A']!['stats/stats']!.data['xp'], 40);
    },
  );

  test(
    'disposed account service does not apply a late network response',
    () async {
      await editStats(10, 100);
      remote.users['A'] = {'stats/stats': statsRecord(50, 200)};
      remote.gate = Completer<void>();
      final pending = service.syncOnce();
      await remote.started.future;
      service.dispose();
      remote.gate!.complete();
      await pending;
      final row = await database.select(database.userStats).getSingle();
      expect(row.xp, 10);
      expect(row.dirty, isTrue);
    },
  );

  test(
    'background merge acknowledgements do not create an endless sync loop',
    () async {
      await editStats(10, 100);
      final synced = Completer<void>();
      service = SyncService(
        userId: 'A',
        local: local,
        remote: remote,
        retryInterval: const Duration(hours: 1),
        onStatus: (status) {
          if (status == SyncStatus.idle && !synced.isCompleted) {
            synced.complete();
          }
        },
      );
      service.start();
      await synced.future.timeout(const Duration(seconds: 3));
      await Future<void>.delayed(const Duration(milliseconds: 1000));
      expect(remote.calls, inInclusiveRange(1, 2));
    },
  );

  test(
    'timestamp generator advances even when the device clock goes backwards',
    () {
      final now = DateTime.utc(2026, 11, 8);
      expect(nextSyncTimestamp(0, now), now.microsecondsSinceEpoch);
      expect(
        nextSyncTimestamp(
          now.microsecondsSinceEpoch,
          now.subtract(const Duration(days: 1)),
        ),
        now.microsecondsSinceEpoch + 1,
      );
      expect(remoteWins(100, 100), isTrue);
      expect(remoteWins(101, 100), isFalse);
    },
  );

  test('payload parser rejects wrong owners, versions and malformed dates', () {
    final valid = {
      'schema_version': 1,
      'user_id': 'A',
      'stats': statsRecord(1, 100).toJson(),
      'words': [],
      'lessons': [],
    };
    expect(
      () => SyncSnapshot.fromJson({...valid, 'user_id': 'B'}, userId: 'A'),
      throwsFormatException,
    );
    expect(
      () => SyncSnapshot.fromJson({...valid, 'schema_version': 2}, userId: 'A'),
      throwsFormatException,
    );
    expect(
      () => SyncRecord.fromJson(SyncKind.word, {
        'word_id': 'w',
        'updated_at': 0,
        'ease_factor': 2.5,
        'repetitions': 0,
        'interval_days': 0,
        'due_date': 'invalid',
      }),
      throwsFormatException,
    );
  });
}
```

## .gitignore

```text
# Miscellaneous
*.class
*.log
*.pyc
*.swp
.DS_Store
.atom/
.build/
.buildlog/
.history
.svn/
.swiftpm/
migrate_working_dir/

# IntelliJ related
*.iml
*.ipr
*.iws
.idea/

# The .vscode folder contains launch configuration and tasks you configure in
# VS Code which you may wish to be included in version control, so this line
# is commented out by default.
#.vscode/

# Flutter/Dart/Pub related
**/doc/api/
**/ios/Flutter/.last_build_id
.dart_tool/
.flutter-plugins-dependencies
.pub-cache/
.pub/
/build/
/coverage/

# Symbolication related
app.*.symbols

# Obfuscation related
app.*.map.json

# Android Studio will place build artifacts here
/android/app/debug
/android/app/profile
/android/app/release

# Widget Preview related
.widget_preview/

# Local configuration and credentials
.env
.env.*
!.env.example
/android/local.properties
/android/key.properties
*.jks
*.keystore

# Local Supabase client configuration and CLI state
config.local.json
/supabase/.temp/
/supabase/.branches/
```

## README.md

````markdown
# Language learning app - Phases 1 through 6A

This project contains Material 3 light/dark themes, Riverpod, go_router,
three-step onboarding, a learning path, an exercise engine, spaced-repetition flashcards,
Supabase authentication, background progress sync, and an account Profile screen.
Phase 2 adds course content, immutable models, asset loading, and Drift tables.
Phase 3 connects onboarding preferences and database progress to the interface.
Phase 4 adds playable lessons, feedback, results, XP awards, and progress saving.
Phase 5 adds SM-2 scheduling, card enrollment, review sessions, and review summaries.
Phase 6A adds Supabase Auth and row-level-secured Postgres synchronization.
Audio playback and AI conversation belong to later phases.

For current backend setup and Android run instructions, start with
[SUPABASE_SETUP.md](SUPABASE_SETUP.md). The app needs your project URL and public
client key in the ignored config.local.json before sign-in is available.

## Create a separate project

Replace MYHANDLE and app_name before running. Keep app_name lowercase_with_underscores.
Do not recreate the existing project to run it.

```powershell
flutter doctor -v
flutter create --org com.MYHANDLE --project-name app_name app_name
cd app_name
```

The existing project keeps package name myapp and its existing native identifiers.
Changing the org flag only affects newly created projects. In another package,
replace package:myapp/ imports in tests with package:app_name/.

## Android setup and run

Your current doctor output reports missing Android SDK Command-line Tools and
unknown Android license status. In Android Studio, open Tools > SDK Manager >
SDK Tools, install Android SDK Command-line Tools (latest), and then run:

```powershell
flutter doctor --android-licenses
flutter doctor -v
cd C:\Langunge_flutter\myapp
flutter pub get
flutter emulators
flutter emulators --launch Medium_Phone_API_37.0
flutter devices
```

Wait until the emulator boots. Use the Android device ID printed by flutter devices
(e.g. emulator-5554, which can vary):

```powershell
flutter run -d emulator-5554 --dart-define-from-file=config.local.json --dart-define="APP_NAME=My Language App" --dart-define="TARGET_LANGUAGE=Japanese" --dart-define="NATIVE_LANGUAGE=English"
```

Press r for hot reload, R for hot restart, and q to quit. Change dart-defines by
stopping and rerunning. AppConfig uses dart-defines; flutter_dotenv is installed
but no .env file or asset registration is needed in this phase.
Client configuration is not a place for private server credentials.

## Verify

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Widget tests cover welcome configuration, all bottom tabs, lesson IDs, back
navigation, direct routes, an unknown route, and 320x568 layouts at 200% text
scale in both light and dark themes. An Android build has not been verified.

## Structure

- lib/app: root app widget.
- lib/core/config: compile-time configuration.
- lib/core/theme: shared ColorScheme and typography.
- lib/core/constants: route constants.
- lib/core/router: go_router configuration.
- lib/core/utils: reserved for shared utilities.
- lib/features/{auth,sync,onboarding,home,lessons,exercises,flashcards,profile}/:
  each feature has data, domain, and presentation folders.
- lib/shared/widgets: reusable widgets.

Empty folders have empty .gitkeep files so Git can retain them.
ProviderScope supplies Riverpod providers, much like React context.
ConsumerWidget can watch those providers and rebuild when their values change.
StatefulShellRoute.indexedStack keeps each bottom tab's navigation state.
context.go changes location; context.push stacks a page so Back returns to Learn.
ThemeMode.system follows the device light/dark setting. The text theme inherits
platform fonts, then customizes weights and line heights.

## Dependencies and Git

Direct dependency versions were checked against pub.dev's latest stable metadata.
drift_dev and build_runner are dev dependencies for the Drift database generator;
see the Phase 2 commands below to regenerate it after schema edits.
Commit pubspec.lock in this application to reproduce resolved dependencies.
.gitignore excludes build output, local env files, SDK paths, and signing files.
The project is a Git repository on main; keep local credentials and tool caches excluded.
See PHASE1_FILES.md for complete setup file contents and the dependency lockfile.

## Phase 2: content and persistence

Sample language assumption: Japanese for English speakers. The registered asset
is assets/courses/japanese_basics.json: 1 course, 2 units, 3 lessons per unit,
6 exercises per lesson, and 60 common words/phrases (10 per lesson). Topics are
greetings, people, numbers, food, places, and actions. Example sentences may
include supporting vocabulary beyond the 60 study entries. Audio URLs are optional
and omitted because no recordings have been supplied.

All content models are handwritten immutable classes. Their lists are copied
into unmodifiable lists, and fromJson rejects missing/invalid required fields.
Exercises use a sealed hierarchy with a type discriminator in JSON.

CourseRepository loads the Flutter asset through an injectable AssetBundle.
courseProvider is a FutureProvider<Course>, so consumers receive an AsyncValue
that represents loading, data, or an error. Phase 3 uses the course catalog to
connect the selected course to Learn. Phase 4 renders its exercises in lesson screens.
The sample path can be overridden via COURSE_ASSET using --dart-define; any
replacement asset must also be registered in pubspec.yaml. App display language
configuration does not translate or select content automatically.

The Drift database lives in lib/core/database/app_database.dart and is exposed
through appDatabaseProvider. It opens lazily when a consumer first queries it.
Only Drift infrastructure uses code generation; the content models do not.
Tables use IDs matching content IDs, but no SQL foreign keys reference the JSON
asset. Word dueDate is required; completedAt and lastActiveDate are nullable.
bestScore is a percentage from 0 to 100. UserStats adds an internal primary key
restricted to 1, ensuring one local user's stats row, initialized on creation.
No XP, streak, scoring, or spaced-repetition algorithms are implemented yet.

After editing the database schema, regenerate its code:

```powershell
flutter pub get
dart run build_runner build
flutter analyze
flutter test
```

Keep app_database.g.dart with the source, and do not edit it manually. Phase 6A
upgrades schema version 1 to 2 with a migration that preserves existing progress.
The native database setup targets Android/iOS/desktop; running the database on
web requires Drift's separate web worker/WASM setup in a later phase.

Tests check every required sample field for missing and null values, JSON round
trips, optional audio, immutable collections, exercise validation, duplicate IDs,
broken word references, injected/registered asset loading, database defaults,
progress round trips, and database constraints. SQLite tests use an in-memory DB.
See PHASE2_FILES.md for the short JSON schema table and every Phase 2 file in full.

## Phase 3: onboarding and Learn

First launch follows /welcome -> /languages -> /daily-goal. A language must be
selected before continuing. Daily goals are 5, 10, or 15 minutes (default 10).
OnboardingRepository stores the selected course ID and goal in one versioned JSON
document using SharedPreferencesAsync. Completion is published to Riverpod only
after saving succeeds, so a failed save stays on the goal screen with a retry.
A startup screen handles asynchronous preference loading and read errors.
Returning launches redirect to /home; completed users cannot revisit onboarding
routes. System Back preserves choices when moving between onboarding steps.

The language list is driven by courseCatalogPathsProvider. It starts with the
Japanese asset selected by courseAssetPathProvider. Add another registered asset
to the catalog to extend the choices; labels come from the course metadata.
Course IDs are stable preference keys, so changing a label does not lose selection.

Learn displays unit sections and round lesson nodes. A pure LearningPath model
flattens lessons in JSON order: the first incomplete lesson is available; later
incomplete lessons are locked; completed lessons remain open. The database's
completed flag controls unlocking, even when an unfinished lesson has a score.
Completed scores earn 1 star below 70%, 2 at 70-89%, and 3 at 90-100%.
LessonProgress and UserStats are observed with Riverpod StreamProviders: new
records update the path, XP, and streak without restarting or manually refreshing.
No completion, XP award, streak calculation, or exercise gameplay is added here.
The tests insert progress records to exercise the unlocking behavior.

Tapping an available/completed node pushes /lesson/:id. Direct links to locked
or unknown lesson IDs show explanatory pages. Loading/error states have friendly
messages and retry actions; stats failures do not hide the learning path.

Shared widgets provide responsive page bodies, loading/error feedback, choice
cards, wrapping stat badges, and accessible lesson nodes. Tests exercise 320x568
screens at 200% text scale in light and dark themes, including scrolling to unit 2.

```powershell
cd C:\Langunge_flutter\myapp
flutter pub get
flutter analyze
flutter test
flutter devices
flutter run -d emulator-5554
```

Use your Android device ID in the final command. No dependency or database schema
changes were needed for Phase 3, so there is no new database generation step.
To manually test onboarding, complete the steps, quit, and reopen the app: Learn
should open directly. To see onboarding again in development, clear this app's
storage through Android Settings (this also clears its local database).
See PHASE3_FILES.md for the file manifest and full Phase 3 code.

## Phase 4: exercise engine

LessonController is an auto-disposed Riverpod Notifier family, keyed by the
loaded Lesson. A Notifier exposes immutable state and methods that change it;
widgets watch the state and invoke those methods rather than grade answers.
Auto-dispose releases a session after its lesson screen closes. Returning to the
same lesson starts a new attempt. Results are rendered on the existing lesson
route so there is no separate results URL that could lose the session.

The controller owns the exercise queue, current index, three hearts, answer draft,
pair selection, correct count, attempt count, first-try count, feedback, phase,
and save status. Phases are answering, feedback, and finished. Check stays
disabled until the answer is complete. Feedback locks the current answer.
Wrong answers cost one heart and append the whole exercise to the queue.
Continue advances after feedback, including the final correction when hearts
reach zero. Progress measures unique exercises cleared out of the original count.

The exercise grader and answer/result models contain no Flutter imports.
MultipleChoice and FillInBlank grade selected choices. MatchPairs shuffles the
right column, supports either tap direction, and allows unpairing by tapping a
paired card. Check grades a complete set of pairs as one exercise. TypeTranslation
trims leading/trailing whitespace, ignores case, and accepts any listed answer;
it does not ignore punctuation, accents, or internal spacing.

Scoring assumptions:

- Success means clearing the entire retry queue with at least one heart left.
- Accuracy is correct attempts divided by all checked attempts, rounded to a
  percentage for display and LessonProgress.bestScore.
- A perfect exercise is answered correctly on its first attempt.
- A successful run awards 10 base XP + 5 XP per perfect exercise. A perfect
  six-exercise sample lesson earns 40 XP. Failed or abandoned runs earn 0 XP.
- Each new successful replay awards its own XP. Repeated checks, Continue taps,
  and save taps in the same session cannot award XP twice.

LessonCompletionRepository writes progress and XP in one Drift transaction.
It marks the lesson complete, preserves its highest score and first completion
date, and increments UserStats.xp without changing the streak. The existing
progress streams unlock the next lesson immediately after commit. Failed saves
roll back both writes and leave the result available for retry. Successful
results allow Continue after saving; failed runs allow Continue immediately.
A close button or system Back asks before abandoning a lesson. Closing an unsaved
result also asks before discarding it; closing is disabled during the save.

The lesson layout keeps the progress/hearts header, scrolling exercise, and
Check/Continue area separate. Feedback is green/red with a correct-answer label,
including an independently scrollable list for match pairs. Header and action
areas can scroll when enlarged text or the keyboard reduces available height.

```powershell
cd C:\Langunge_flutter\myapp
flutter pub get
flutter analyze
flutter test
flutter devices
flutter run -d emulator-5554
```

Use the Android device ID shown by flutter devices. Complete onboarding if needed,
tap the first available lesson, answer all exercises, and Continue from results.
Check that XP increases and the next node unlocks. Also try three mistakes and
cancel/confirm the close dialog. No new dependencies or database schema changes
were needed, so the existing generated Drift file is unchanged.
See PHASE4_FILES.md for the complete file manifest and source snapshot.

## Phase 5: flashcards and spaced repetition

Sm2 in lib/features/flashcards/domain/sm2.dart is a pure Dart scheduler. Its
schedule method takes quality, repetitions, easeFactor, intervalDays, and an
explicit reviewedAt timestamp, and returns a Sm2Schedule with updated values
and dueDate. Using an explicit time makes the algorithm deterministic in tests.

- Quality below 3 resets repetitions to 0 and intervalDays to 1.
- A successful rating schedules 1 day, then 6 days, then round(interval * easeFactor).
  The interval uses the incoming ease factor; the updated factor is for the next rating.
- Every rating updates easeFactor using the requested formula, with a 1.3 floor.
- One scheduling day is 24 hours. Due dates are UTC instants; the interface
  formats the next due time in the device's local time.
- Again, Hard, Good, and Easy map to quality 1, 3, 4, and 5.
  Again schedules a card one day out rather than repeating it within this session.

Successful lesson saving now requires its wordIds and inserts missing WordProgress
rows in the same transaction as LessonProgress and XP. New cards start with ease
2.5, zero repetitions, zero interval, and a due time of now. Insert-or-ignore
preserves existing schedules during lesson replays and when words occur again.
The Review repository also backfills words from already completed lessons when
the review deck/session loads. Only vocabulary declared in lesson.wordIds is
enrolled; words merely used as supporting text in an example are not inferred.

Review shows cards due at or before now, including overdue cards. Future cards
become available at their exact scheduled time; the count does not include a card
that will only become due later today. A Drift stream and a timer for the next
due card keep the count current, and app resume rechecks it. The deck is filtered
to the selected course. An empty deck either explains how to add words or shows
the next scheduled due time.

Start opens /review/session with a snapshot of the due cards, ordered by due time
and word ID. Cards added after a session starts are left for a subsequent session.
The front shows the word; tapping flips to its translation and example. Rating
buttons are disabled until the answer is revealed. AnimatedSwitcher plus Transform
provides the flip using Flutter alone, with a 240ms transition and reduced-motion
support. Card contents and buttons scroll on small screens and with large text.

ReviewSessionController saves a rating before advancing. Repeated taps during a
save are ignored, and a failed save leaves the revealed card available to retry.
The repository re-reads the stored progress inside a transaction before applying
SM-2. Closing a session keeps all ratings already saved, while its unreviewed
cards remain due. The session summary shows the number reviewed and rating counts.
Review does not award XP or change streaks in this phase.

```powershell
cd C:\Langunge_flutter\myapp
flutter pub get
flutter analyze
flutter test
flutter devices
flutter run -d emulator-5554
```

Replace the device ID with yours. Complete a lesson, open Review, tap Start,
reveal each card, and choose a rating. After the summary, Continue should show
an empty state with the next due time if all currently due cards were reviewed.
Existing completed lessons also produce cards automatically on opening Review.
No dependencies, table definitions, generated database files, or schema version
changes were needed. clockProvider supplies an injectable UTC clock for tests.

Validation: all 94 tests pass, including 10 SM-2 tests, transactional enrollment,
backfill, schedule preservation, due-time updates without database writes, all
rating mappings, session save retry, partial sessions, app resume, reduced motion,
and 320px layouts at 200% text scale in light/dark themes. flutter analyze reports
no issues and formatting is clean. An Android emulator run was not performed.
See PHASE5_FILES.md for the file manifest and full Phase 5 source.

## Phase 6A: Supabase authentication and sync

See SUPABASE_SETUP.md for project creation, SQL migration/RLS, email and Google
provider configuration, Android callbacks, offline behavior, and manual testing.
The app uses supabase_flutter and reads config.local.json through dart-defines.
That local file is ignored; config.example.json is safe to commit.

Drift remains the source used by screens. Authenticated accounts have separate
local databases, and the first account can claim the pre-authentication database
once. Schema version 2 adds timestamp/dirty fields and ownership metadata without
clearing progress. Sync persists pending changes, retries in the background, and
merges each row by updatedAt through an owner-checked Postgres RPC. Newer local
edits made during an upload remain pending. Profile includes sync status and logout.

Validation: 121 Flutter tests and 11 local SQL/RLS checks passed. Cloud project
configuration, live OAuth/email delivery, and emulator verification remain setup
steps for your project. Full changed-file contents are in PHASE6A_FILES.md.
````

## android/app/src/main/AndroidManifest.xml

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET" />
    <application
        android:label="myapp"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:taskAffinity=""
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
            <!-- Specifies an Android theme to apply to this Activity as soon as
                 the Android process has started. This theme is visible to the user
                 while the Flutter UI initializes. After that, this theme continues
                 to determine the Window background behind the Flutter UI. -->
            <meta-data
              android:name="io.flutter.embedding.android.NormalTheme"
              android:resource="@style/NormalTheme"
              />
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
            <meta-data android:name="flutter_deeplinking_enabled" android:value="false" />
            <intent-filter android:autoVerify="false">
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="io.languagelearning.app" android:host="auth-callback" />
            </intent-filter>
        </activity>
        <!-- Don't delete the meta-data below.
             This is used by the Flutter tool to generate GeneratedPluginRegistrant.java -->
        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />
    </application>
    <!-- Required to query activities that can process text, see:
         https://developer.android.com/training/package-visibility and
         https://developer.android.com/reference/android/content/Intent#ACTION_PROCESS_TEXT.

         In particular, this is used by the Flutter engine in io.flutter.plugin.text.ProcessTextPlugin. -->
    <queries>
        <intent>
            <action android:name="android.intent.action.PROCESS_TEXT"/>
            <data android:mimeType="text/plain"/>
        </intent>
    </queries>
</manifest>
```

## lib/app/app.dart

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../core/router/app_router.dart';
import '../core/theme/app_theme.dart';
import '../features/sync/presentation/sync_providers.dart';

class LanguageApp extends ConsumerWidget {
  const LanguageApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    ref.watch(syncServiceProvider);
    return MaterialApp.router(
      title: config.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: ref.watch(appRouterProvider),
      builder: (context, child) => _SyncLifecycle(child: child!),
    );
  }
}

class _SyncLifecycle extends ConsumerStatefulWidget {
  const _SyncLifecycle({required this.child});
  final Widget child;
  @override
  ConsumerState<_SyncLifecycle> createState() => _SyncLifecycleState();
}

class _SyncLifecycleState extends ConsumerState<_SyncLifecycle>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(syncServiceProvider)?.request();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
```

## lib/core/constants/app_routes.dart

```dart
abstract final class AppRoutes {
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const resetPassword = '/reset-password';
  static const authLoading = '/auth-loading';
  static const welcome = '/welcome';
  static const startup = '/startup';
  static const languages = '/languages';
  static const dailyGoal = '/daily-goal';
  static const home = '/home';
  static const lesson = '/lesson/:id';
  static const review = '/review';
  static const reviewSession = '/review/session';
  static const profile = '/profile';

  static String lessonLocation(String id) =>
      '/lesson/${Uri.encodeComponent(id)}';
}
```

## lib/core/database/app_database.dart

```dart
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/auth_repository.dart';

part 'app_database.g.dart';

@DataClassName('LessonProgressRow')
class LessonProgress extends Table {
  TextColumn get lessonId => text()();
  BoolColumn get completed => boolean().withDefault(const Constant(false))();
  IntColumn get bestScore => integer().withDefault(const Constant(0))();
  DateTimeColumn get completedAt => dateTime().nullable()();
  IntColumn get updatedAt => integer().withDefault(const Constant(0))();
  BoolColumn get dirty => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {lessonId};

  @override
  List<String> get customConstraints => [
    'CHECK (best_score BETWEEN 0 AND 100)',
  ];
}

@DataClassName('WordProgressRow')
class WordProgress extends Table {
  TextColumn get wordId => text()();
  RealColumn get easeFactor => real().withDefault(const Constant(2.5))();
  IntColumn get intervalDays => integer().withDefault(const Constant(0))();
  IntColumn get repetitions => integer().withDefault(const Constant(0))();
  DateTimeColumn get dueDate => dateTime()();
  IntColumn get updatedAt => integer().withDefault(const Constant(0))();
  BoolColumn get dirty => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {wordId};

  @override
  List<String> get customConstraints => [
    'CHECK (ease_factor >= 1.3)',
    'CHECK (interval_days >= 0)',
    'CHECK (repetitions >= 0)',
  ];
}

@DataClassName('UserStatsRow')
class UserStats extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  IntColumn get xp => integer().withDefault(const Constant(0))();
  IntColumn get streak => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastActiveDate => dateTime().nullable()();
  IntColumn get updatedAt => integer().withDefault(const Constant(0))();
  BoolColumn get dirty => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK (id = 1)',
    'CHECK (xp >= 0)',
    'CHECK (streak >= 0)',
  ];
}

class SyncMetadata extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [LessonProgress, WordProgress, UserStats, SyncMetadata])
class AppDatabase extends _$AppDatabase {
  AppDatabase({String? userId})
    : super(driftDatabase(name: databaseName(userId)));

  static String databaseName(String? userId) => userId == null
      ? 'language_learning'
      : 'language_learning_${base64Url.encode(utf8.encode(userId)).replaceAll('=', '')}';

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await into(userStats).insert(UserStatsCompanion.insert());
    },
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.addColumn(lessonProgress, lessonProgress.updatedAt);
        await migrator.addColumn(lessonProgress, lessonProgress.dirty);
        await migrator.addColumn(wordProgress, wordProgress.updatedAt);
        await migrator.addColumn(wordProgress, wordProgress.dirty);
        await migrator.addColumn(userStats, userStats.updatedAt);
        await migrator.addColumn(userStats, userStats.dirty);
        await migrator.createTable(syncMetadata);
      }
    },
  );
}

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final uid = ref.watch(
    authStateProvider.select((value) => value.asData?.value?.id),
  );
  final database = AppDatabase(userId: uid);
  ref.onDispose(database.close);
  return database;
});
```

## lib/core/database/app_database.g.dart

```dart
// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $LessonProgressTable extends LessonProgress
    with TableInfo<$LessonProgressTable, LessonProgressRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LessonProgressTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _lessonIdMeta = const VerificationMeta(
    'lessonId',
  );
  @override
  late final GeneratedColumn<String> lessonId = GeneratedColumn<String>(
    'lesson_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedMeta = const VerificationMeta(
    'completed',
  );
  @override
  late final GeneratedColumn<bool> completed = GeneratedColumn<bool>(
    'completed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("completed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _bestScoreMeta = const VerificationMeta(
    'bestScore',
  );
  @override
  late final GeneratedColumn<int> bestScore = GeneratedColumn<int>(
    'best_score',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _dirtyMeta = const VerificationMeta('dirty');
  @override
  late final GeneratedColumn<bool> dirty = GeneratedColumn<bool>(
    'dirty',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("dirty" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [
    lessonId,
    completed,
    bestScore,
    completedAt,
    updatedAt,
    dirty,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'lesson_progress';
  @override
  VerificationContext validateIntegrity(
    Insertable<LessonProgressRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('lesson_id')) {
      context.handle(
        _lessonIdMeta,
        lessonId.isAcceptableOrUnknown(data['lesson_id']!, _lessonIdMeta),
      );
    } else if (isInserting) {
      context.missing(_lessonIdMeta);
    }
    if (data.containsKey('completed')) {
      context.handle(
        _completedMeta,
        completed.isAcceptableOrUnknown(data['completed']!, _completedMeta),
      );
    }
    if (data.containsKey('best_score')) {
      context.handle(
        _bestScoreMeta,
        bestScore.isAcceptableOrUnknown(data['best_score']!, _bestScoreMeta),
      );
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('dirty')) {
      context.handle(
        _dirtyMeta,
        dirty.isAcceptableOrUnknown(data['dirty']!, _dirtyMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {lessonId};
  @override
  LessonProgressRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LessonProgressRow(
      lessonId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lesson_id'],
      )!,
      completed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}completed'],
      )!,
      bestScore: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}best_score'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      dirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}dirty'],
      )!,
    );
  }

  @override
  $LessonProgressTable createAlias(String alias) {
    return $LessonProgressTable(attachedDatabase, alias);
  }
}

class LessonProgressRow extends DataClass
    implements Insertable<LessonProgressRow> {
  final String lessonId;
  final bool completed;
  final int bestScore;
  final DateTime? completedAt;
  final int updatedAt;
  final bool dirty;
  const LessonProgressRow({
    required this.lessonId,
    required this.completed,
    required this.bestScore,
    this.completedAt,
    required this.updatedAt,
    required this.dirty,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['lesson_id'] = Variable<String>(lessonId);
    map['completed'] = Variable<bool>(completed);
    map['best_score'] = Variable<int>(bestScore);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    map['updated_at'] = Variable<int>(updatedAt);
    map['dirty'] = Variable<bool>(dirty);
    return map;
  }

  LessonProgressCompanion toCompanion(bool nullToAbsent) {
    return LessonProgressCompanion(
      lessonId: Value(lessonId),
      completed: Value(completed),
      bestScore: Value(bestScore),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      updatedAt: Value(updatedAt),
      dirty: Value(dirty),
    );
  }

  factory LessonProgressRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LessonProgressRow(
      lessonId: serializer.fromJson<String>(json['lessonId']),
      completed: serializer.fromJson<bool>(json['completed']),
      bestScore: serializer.fromJson<int>(json['bestScore']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      dirty: serializer.fromJson<bool>(json['dirty']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'lessonId': serializer.toJson<String>(lessonId),
      'completed': serializer.toJson<bool>(completed),
      'bestScore': serializer.toJson<int>(bestScore),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'dirty': serializer.toJson<bool>(dirty),
    };
  }

  LessonProgressRow copyWith({
    String? lessonId,
    bool? completed,
    int? bestScore,
    Value<DateTime?> completedAt = const Value.absent(),
    int? updatedAt,
    bool? dirty,
  }) => LessonProgressRow(
    lessonId: lessonId ?? this.lessonId,
    completed: completed ?? this.completed,
    bestScore: bestScore ?? this.bestScore,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
    updatedAt: updatedAt ?? this.updatedAt,
    dirty: dirty ?? this.dirty,
  );
  LessonProgressRow copyWithCompanion(LessonProgressCompanion data) {
    return LessonProgressRow(
      lessonId: data.lessonId.present ? data.lessonId.value : this.lessonId,
      completed: data.completed.present ? data.completed.value : this.completed,
      bestScore: data.bestScore.present ? data.bestScore.value : this.bestScore,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      dirty: data.dirty.present ? data.dirty.value : this.dirty,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LessonProgressRow(')
          ..write('lessonId: $lessonId, ')
          ..write('completed: $completed, ')
          ..write('bestScore: $bestScore, ')
          ..write('completedAt: $completedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('dirty: $dirty')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    lessonId,
    completed,
    bestScore,
    completedAt,
    updatedAt,
    dirty,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LessonProgressRow &&
          other.lessonId == this.lessonId &&
          other.completed == this.completed &&
          other.bestScore == this.bestScore &&
          other.completedAt == this.completedAt &&
          other.updatedAt == this.updatedAt &&
          other.dirty == this.dirty);
}

class LessonProgressCompanion extends UpdateCompanion<LessonProgressRow> {
  final Value<String> lessonId;
  final Value<bool> completed;
  final Value<int> bestScore;
  final Value<DateTime?> completedAt;
  final Value<int> updatedAt;
  final Value<bool> dirty;
  final Value<int> rowid;
  const LessonProgressCompanion({
    this.lessonId = const Value.absent(),
    this.completed = const Value.absent(),
    this.bestScore = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.dirty = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LessonProgressCompanion.insert({
    required String lessonId,
    this.completed = const Value.absent(),
    this.bestScore = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.dirty = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : lessonId = Value(lessonId);
  static Insertable<LessonProgressRow> custom({
    Expression<String>? lessonId,
    Expression<bool>? completed,
    Expression<int>? bestScore,
    Expression<DateTime>? completedAt,
    Expression<int>? updatedAt,
    Expression<bool>? dirty,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (lessonId != null) 'lesson_id': lessonId,
      if (completed != null) 'completed': completed,
      if (bestScore != null) 'best_score': bestScore,
      if (completedAt != null) 'completed_at': completedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (dirty != null) 'dirty': dirty,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LessonProgressCompanion copyWith({
    Value<String>? lessonId,
    Value<bool>? completed,
    Value<int>? bestScore,
    Value<DateTime?>? completedAt,
    Value<int>? updatedAt,
    Value<bool>? dirty,
    Value<int>? rowid,
  }) {
    return LessonProgressCompanion(
      lessonId: lessonId ?? this.lessonId,
      completed: completed ?? this.completed,
      bestScore: bestScore ?? this.bestScore,
      completedAt: completedAt ?? this.completedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      dirty: dirty ?? this.dirty,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (lessonId.present) {
      map['lesson_id'] = Variable<String>(lessonId.value);
    }
    if (completed.present) {
      map['completed'] = Variable<bool>(completed.value);
    }
    if (bestScore.present) {
      map['best_score'] = Variable<int>(bestScore.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (dirty.present) {
      map['dirty'] = Variable<bool>(dirty.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LessonProgressCompanion(')
          ..write('lessonId: $lessonId, ')
          ..write('completed: $completed, ')
          ..write('bestScore: $bestScore, ')
          ..write('completedAt: $completedAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('dirty: $dirty, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WordProgressTable extends WordProgress
    with TableInfo<$WordProgressTable, WordProgressRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WordProgressTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _wordIdMeta = const VerificationMeta('wordId');
  @override
  late final GeneratedColumn<String> wordId = GeneratedColumn<String>(
    'word_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _easeFactorMeta = const VerificationMeta(
    'easeFactor',
  );
  @override
  late final GeneratedColumn<double> easeFactor = GeneratedColumn<double>(
    'ease_factor',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(2.5),
  );
  static const VerificationMeta _intervalDaysMeta = const VerificationMeta(
    'intervalDays',
  );
  @override
  late final GeneratedColumn<int> intervalDays = GeneratedColumn<int>(
    'interval_days',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _repetitionsMeta = const VerificationMeta(
    'repetitions',
  );
  @override
  late final GeneratedColumn<int> repetitions = GeneratedColumn<int>(
    'repetitions',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _dueDateMeta = const VerificationMeta(
    'dueDate',
  );
  @override
  late final GeneratedColumn<DateTime> dueDate = GeneratedColumn<DateTime>(
    'due_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _dirtyMeta = const VerificationMeta('dirty');
  @override
  late final GeneratedColumn<bool> dirty = GeneratedColumn<bool>(
    'dirty',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("dirty" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [
    wordId,
    easeFactor,
    intervalDays,
    repetitions,
    dueDate,
    updatedAt,
    dirty,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'word_progress';
  @override
  VerificationContext validateIntegrity(
    Insertable<WordProgressRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('word_id')) {
      context.handle(
        _wordIdMeta,
        wordId.isAcceptableOrUnknown(data['word_id']!, _wordIdMeta),
      );
    } else if (isInserting) {
      context.missing(_wordIdMeta);
    }
    if (data.containsKey('ease_factor')) {
      context.handle(
        _easeFactorMeta,
        easeFactor.isAcceptableOrUnknown(data['ease_factor']!, _easeFactorMeta),
      );
    }
    if (data.containsKey('interval_days')) {
      context.handle(
        _intervalDaysMeta,
        intervalDays.isAcceptableOrUnknown(
          data['interval_days']!,
          _intervalDaysMeta,
        ),
      );
    }
    if (data.containsKey('repetitions')) {
      context.handle(
        _repetitionsMeta,
        repetitions.isAcceptableOrUnknown(
          data['repetitions']!,
          _repetitionsMeta,
        ),
      );
    }
    if (data.containsKey('due_date')) {
      context.handle(
        _dueDateMeta,
        dueDate.isAcceptableOrUnknown(data['due_date']!, _dueDateMeta),
      );
    } else if (isInserting) {
      context.missing(_dueDateMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('dirty')) {
      context.handle(
        _dirtyMeta,
        dirty.isAcceptableOrUnknown(data['dirty']!, _dirtyMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {wordId};
  @override
  WordProgressRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WordProgressRow(
      wordId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}word_id'],
      )!,
      easeFactor: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}ease_factor'],
      )!,
      intervalDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}interval_days'],
      )!,
      repetitions: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}repetitions'],
      )!,
      dueDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}due_date'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      dirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}dirty'],
      )!,
    );
  }

  @override
  $WordProgressTable createAlias(String alias) {
    return $WordProgressTable(attachedDatabase, alias);
  }
}

class WordProgressRow extends DataClass implements Insertable<WordProgressRow> {
  final String wordId;
  final double easeFactor;
  final int intervalDays;
  final int repetitions;
  final DateTime dueDate;
  final int updatedAt;
  final bool dirty;
  const WordProgressRow({
    required this.wordId,
    required this.easeFactor,
    required this.intervalDays,
    required this.repetitions,
    required this.dueDate,
    required this.updatedAt,
    required this.dirty,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['word_id'] = Variable<String>(wordId);
    map['ease_factor'] = Variable<double>(easeFactor);
    map['interval_days'] = Variable<int>(intervalDays);
    map['repetitions'] = Variable<int>(repetitions);
    map['due_date'] = Variable<DateTime>(dueDate);
    map['updated_at'] = Variable<int>(updatedAt);
    map['dirty'] = Variable<bool>(dirty);
    return map;
  }

  WordProgressCompanion toCompanion(bool nullToAbsent) {
    return WordProgressCompanion(
      wordId: Value(wordId),
      easeFactor: Value(easeFactor),
      intervalDays: Value(intervalDays),
      repetitions: Value(repetitions),
      dueDate: Value(dueDate),
      updatedAt: Value(updatedAt),
      dirty: Value(dirty),
    );
  }

  factory WordProgressRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WordProgressRow(
      wordId: serializer.fromJson<String>(json['wordId']),
      easeFactor: serializer.fromJson<double>(json['easeFactor']),
      intervalDays: serializer.fromJson<int>(json['intervalDays']),
      repetitions: serializer.fromJson<int>(json['repetitions']),
      dueDate: serializer.fromJson<DateTime>(json['dueDate']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      dirty: serializer.fromJson<bool>(json['dirty']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'wordId': serializer.toJson<String>(wordId),
      'easeFactor': serializer.toJson<double>(easeFactor),
      'intervalDays': serializer.toJson<int>(intervalDays),
      'repetitions': serializer.toJson<int>(repetitions),
      'dueDate': serializer.toJson<DateTime>(dueDate),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'dirty': serializer.toJson<bool>(dirty),
    };
  }

  WordProgressRow copyWith({
    String? wordId,
    double? easeFactor,
    int? intervalDays,
    int? repetitions,
    DateTime? dueDate,
    int? updatedAt,
    bool? dirty,
  }) => WordProgressRow(
    wordId: wordId ?? this.wordId,
    easeFactor: easeFactor ?? this.easeFactor,
    intervalDays: intervalDays ?? this.intervalDays,
    repetitions: repetitions ?? this.repetitions,
    dueDate: dueDate ?? this.dueDate,
    updatedAt: updatedAt ?? this.updatedAt,
    dirty: dirty ?? this.dirty,
  );
  WordProgressRow copyWithCompanion(WordProgressCompanion data) {
    return WordProgressRow(
      wordId: data.wordId.present ? data.wordId.value : this.wordId,
      easeFactor: data.easeFactor.present
          ? data.easeFactor.value
          : this.easeFactor,
      intervalDays: data.intervalDays.present
          ? data.intervalDays.value
          : this.intervalDays,
      repetitions: data.repetitions.present
          ? data.repetitions.value
          : this.repetitions,
      dueDate: data.dueDate.present ? data.dueDate.value : this.dueDate,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      dirty: data.dirty.present ? data.dirty.value : this.dirty,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WordProgressRow(')
          ..write('wordId: $wordId, ')
          ..write('easeFactor: $easeFactor, ')
          ..write('intervalDays: $intervalDays, ')
          ..write('repetitions: $repetitions, ')
          ..write('dueDate: $dueDate, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('dirty: $dirty')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    wordId,
    easeFactor,
    intervalDays,
    repetitions,
    dueDate,
    updatedAt,
    dirty,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WordProgressRow &&
          other.wordId == this.wordId &&
          other.easeFactor == this.easeFactor &&
          other.intervalDays == this.intervalDays &&
          other.repetitions == this.repetitions &&
          other.dueDate == this.dueDate &&
          other.updatedAt == this.updatedAt &&
          other.dirty == this.dirty);
}

class WordProgressCompanion extends UpdateCompanion<WordProgressRow> {
  final Value<String> wordId;
  final Value<double> easeFactor;
  final Value<int> intervalDays;
  final Value<int> repetitions;
  final Value<DateTime> dueDate;
  final Value<int> updatedAt;
  final Value<bool> dirty;
  final Value<int> rowid;
  const WordProgressCompanion({
    this.wordId = const Value.absent(),
    this.easeFactor = const Value.absent(),
    this.intervalDays = const Value.absent(),
    this.repetitions = const Value.absent(),
    this.dueDate = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.dirty = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WordProgressCompanion.insert({
    required String wordId,
    this.easeFactor = const Value.absent(),
    this.intervalDays = const Value.absent(),
    this.repetitions = const Value.absent(),
    required DateTime dueDate,
    this.updatedAt = const Value.absent(),
    this.dirty = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : wordId = Value(wordId),
       dueDate = Value(dueDate);
  static Insertable<WordProgressRow> custom({
    Expression<String>? wordId,
    Expression<double>? easeFactor,
    Expression<int>? intervalDays,
    Expression<int>? repetitions,
    Expression<DateTime>? dueDate,
    Expression<int>? updatedAt,
    Expression<bool>? dirty,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (wordId != null) 'word_id': wordId,
      if (easeFactor != null) 'ease_factor': easeFactor,
      if (intervalDays != null) 'interval_days': intervalDays,
      if (repetitions != null) 'repetitions': repetitions,
      if (dueDate != null) 'due_date': dueDate,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (dirty != null) 'dirty': dirty,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WordProgressCompanion copyWith({
    Value<String>? wordId,
    Value<double>? easeFactor,
    Value<int>? intervalDays,
    Value<int>? repetitions,
    Value<DateTime>? dueDate,
    Value<int>? updatedAt,
    Value<bool>? dirty,
    Value<int>? rowid,
  }) {
    return WordProgressCompanion(
      wordId: wordId ?? this.wordId,
      easeFactor: easeFactor ?? this.easeFactor,
      intervalDays: intervalDays ?? this.intervalDays,
      repetitions: repetitions ?? this.repetitions,
      dueDate: dueDate ?? this.dueDate,
      updatedAt: updatedAt ?? this.updatedAt,
      dirty: dirty ?? this.dirty,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (wordId.present) {
      map['word_id'] = Variable<String>(wordId.value);
    }
    if (easeFactor.present) {
      map['ease_factor'] = Variable<double>(easeFactor.value);
    }
    if (intervalDays.present) {
      map['interval_days'] = Variable<int>(intervalDays.value);
    }
    if (repetitions.present) {
      map['repetitions'] = Variable<int>(repetitions.value);
    }
    if (dueDate.present) {
      map['due_date'] = Variable<DateTime>(dueDate.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (dirty.present) {
      map['dirty'] = Variable<bool>(dirty.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WordProgressCompanion(')
          ..write('wordId: $wordId, ')
          ..write('easeFactor: $easeFactor, ')
          ..write('intervalDays: $intervalDays, ')
          ..write('repetitions: $repetitions, ')
          ..write('dueDate: $dueDate, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('dirty: $dirty, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UserStatsTable extends UserStats
    with TableInfo<$UserStatsTable, UserStatsRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserStatsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _xpMeta = const VerificationMeta('xp');
  @override
  late final GeneratedColumn<int> xp = GeneratedColumn<int>(
    'xp',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _streakMeta = const VerificationMeta('streak');
  @override
  late final GeneratedColumn<int> streak = GeneratedColumn<int>(
    'streak',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastActiveDateMeta = const VerificationMeta(
    'lastActiveDate',
  );
  @override
  late final GeneratedColumn<DateTime> lastActiveDate =
      GeneratedColumn<DateTime>(
        'last_active_date',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _dirtyMeta = const VerificationMeta('dirty');
  @override
  late final GeneratedColumn<bool> dirty = GeneratedColumn<bool>(
    'dirty',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("dirty" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    xp,
    streak,
    lastActiveDate,
    updatedAt,
    dirty,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_stats';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserStatsRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('xp')) {
      context.handle(_xpMeta, xp.isAcceptableOrUnknown(data['xp']!, _xpMeta));
    }
    if (data.containsKey('streak')) {
      context.handle(
        _streakMeta,
        streak.isAcceptableOrUnknown(data['streak']!, _streakMeta),
      );
    }
    if (data.containsKey('last_active_date')) {
      context.handle(
        _lastActiveDateMeta,
        lastActiveDate.isAcceptableOrUnknown(
          data['last_active_date']!,
          _lastActiveDateMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('dirty')) {
      context.handle(
        _dirtyMeta,
        dirty.isAcceptableOrUnknown(data['dirty']!, _dirtyMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UserStatsRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserStatsRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      xp: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}xp'],
      )!,
      streak: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}streak'],
      )!,
      lastActiveDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_active_date'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      dirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}dirty'],
      )!,
    );
  }

  @override
  $UserStatsTable createAlias(String alias) {
    return $UserStatsTable(attachedDatabase, alias);
  }
}

class UserStatsRow extends DataClass implements Insertable<UserStatsRow> {
  final int id;
  final int xp;
  final int streak;
  final DateTime? lastActiveDate;
  final int updatedAt;
  final bool dirty;
  const UserStatsRow({
    required this.id,
    required this.xp,
    required this.streak,
    this.lastActiveDate,
    required this.updatedAt,
    required this.dirty,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['xp'] = Variable<int>(xp);
    map['streak'] = Variable<int>(streak);
    if (!nullToAbsent || lastActiveDate != null) {
      map['last_active_date'] = Variable<DateTime>(lastActiveDate);
    }
    map['updated_at'] = Variable<int>(updatedAt);
    map['dirty'] = Variable<bool>(dirty);
    return map;
  }

  UserStatsCompanion toCompanion(bool nullToAbsent) {
    return UserStatsCompanion(
      id: Value(id),
      xp: Value(xp),
      streak: Value(streak),
      lastActiveDate: lastActiveDate == null && nullToAbsent
          ? const Value.absent()
          : Value(lastActiveDate),
      updatedAt: Value(updatedAt),
      dirty: Value(dirty),
    );
  }

  factory UserStatsRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserStatsRow(
      id: serializer.fromJson<int>(json['id']),
      xp: serializer.fromJson<int>(json['xp']),
      streak: serializer.fromJson<int>(json['streak']),
      lastActiveDate: serializer.fromJson<DateTime?>(json['lastActiveDate']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      dirty: serializer.fromJson<bool>(json['dirty']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'xp': serializer.toJson<int>(xp),
      'streak': serializer.toJson<int>(streak),
      'lastActiveDate': serializer.toJson<DateTime?>(lastActiveDate),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'dirty': serializer.toJson<bool>(dirty),
    };
  }

  UserStatsRow copyWith({
    int? id,
    int? xp,
    int? streak,
    Value<DateTime?> lastActiveDate = const Value.absent(),
    int? updatedAt,
    bool? dirty,
  }) => UserStatsRow(
    id: id ?? this.id,
    xp: xp ?? this.xp,
    streak: streak ?? this.streak,
    lastActiveDate: lastActiveDate.present
        ? lastActiveDate.value
        : this.lastActiveDate,
    updatedAt: updatedAt ?? this.updatedAt,
    dirty: dirty ?? this.dirty,
  );
  UserStatsRow copyWithCompanion(UserStatsCompanion data) {
    return UserStatsRow(
      id: data.id.present ? data.id.value : this.id,
      xp: data.xp.present ? data.xp.value : this.xp,
      streak: data.streak.present ? data.streak.value : this.streak,
      lastActiveDate: data.lastActiveDate.present
          ? data.lastActiveDate.value
          : this.lastActiveDate,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      dirty: data.dirty.present ? data.dirty.value : this.dirty,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserStatsRow(')
          ..write('id: $id, ')
          ..write('xp: $xp, ')
          ..write('streak: $streak, ')
          ..write('lastActiveDate: $lastActiveDate, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('dirty: $dirty')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, xp, streak, lastActiveDate, updatedAt, dirty);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserStatsRow &&
          other.id == this.id &&
          other.xp == this.xp &&
          other.streak == this.streak &&
          other.lastActiveDate == this.lastActiveDate &&
          other.updatedAt == this.updatedAt &&
          other.dirty == this.dirty);
}

class UserStatsCompanion extends UpdateCompanion<UserStatsRow> {
  final Value<int> id;
  final Value<int> xp;
  final Value<int> streak;
  final Value<DateTime?> lastActiveDate;
  final Value<int> updatedAt;
  final Value<bool> dirty;
  const UserStatsCompanion({
    this.id = const Value.absent(),
    this.xp = const Value.absent(),
    this.streak = const Value.absent(),
    this.lastActiveDate = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.dirty = const Value.absent(),
  });
  UserStatsCompanion.insert({
    this.id = const Value.absent(),
    this.xp = const Value.absent(),
    this.streak = const Value.absent(),
    this.lastActiveDate = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.dirty = const Value.absent(),
  });
  static Insertable<UserStatsRow> custom({
    Expression<int>? id,
    Expression<int>? xp,
    Expression<int>? streak,
    Expression<DateTime>? lastActiveDate,
    Expression<int>? updatedAt,
    Expression<bool>? dirty,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (xp != null) 'xp': xp,
      if (streak != null) 'streak': streak,
      if (lastActiveDate != null) 'last_active_date': lastActiveDate,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (dirty != null) 'dirty': dirty,
    });
  }

  UserStatsCompanion copyWith({
    Value<int>? id,
    Value<int>? xp,
    Value<int>? streak,
    Value<DateTime?>? lastActiveDate,
    Value<int>? updatedAt,
    Value<bool>? dirty,
  }) {
    return UserStatsCompanion(
      id: id ?? this.id,
      xp: xp ?? this.xp,
      streak: streak ?? this.streak,
      lastActiveDate: lastActiveDate ?? this.lastActiveDate,
      updatedAt: updatedAt ?? this.updatedAt,
      dirty: dirty ?? this.dirty,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (xp.present) {
      map['xp'] = Variable<int>(xp.value);
    }
    if (streak.present) {
      map['streak'] = Variable<int>(streak.value);
    }
    if (lastActiveDate.present) {
      map['last_active_date'] = Variable<DateTime>(lastActiveDate.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (dirty.present) {
      map['dirty'] = Variable<bool>(dirty.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserStatsCompanion(')
          ..write('id: $id, ')
          ..write('xp: $xp, ')
          ..write('streak: $streak, ')
          ..write('lastActiveDate: $lastActiveDate, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('dirty: $dirty')
          ..write(')'))
        .toString();
  }
}

class $SyncMetadataTable extends SyncMetadata
    with TableInfo<$SyncMetadataTable, SyncMetadataData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncMetadataTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_metadata';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncMetadataData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SyncMetadataData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncMetadataData(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SyncMetadataTable createAlias(String alias) {
    return $SyncMetadataTable(attachedDatabase, alias);
  }
}

class SyncMetadataData extends DataClass
    implements Insertable<SyncMetadataData> {
  final String key;
  final String value;
  const SyncMetadataData({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SyncMetadataCompanion toCompanion(bool nullToAbsent) {
    return SyncMetadataCompanion(key: Value(key), value: Value(value));
  }

  factory SyncMetadataData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncMetadataData(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  SyncMetadataData copyWith({String? key, String? value}) =>
      SyncMetadataData(key: key ?? this.key, value: value ?? this.value);
  SyncMetadataData copyWithCompanion(SyncMetadataCompanion data) {
    return SyncMetadataData(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncMetadataData(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncMetadataData &&
          other.key == this.key &&
          other.value == this.value);
}

class SyncMetadataCompanion extends UpdateCompanion<SyncMetadataData> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SyncMetadataCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncMetadataCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<SyncMetadataData> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncMetadataCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SyncMetadataCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncMetadataCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $LessonProgressTable lessonProgress = $LessonProgressTable(this);
  late final $WordProgressTable wordProgress = $WordProgressTable(this);
  late final $UserStatsTable userStats = $UserStatsTable(this);
  late final $SyncMetadataTable syncMetadata = $SyncMetadataTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    lessonProgress,
    wordProgress,
    userStats,
    syncMetadata,
  ];
}

typedef $$LessonProgressTableCreateCompanionBuilder =
    LessonProgressCompanion Function({
      required String lessonId,
      Value<bool> completed,
      Value<int> bestScore,
      Value<DateTime?> completedAt,
      Value<int> updatedAt,
      Value<bool> dirty,
      Value<int> rowid,
    });
typedef $$LessonProgressTableUpdateCompanionBuilder =
    LessonProgressCompanion Function({
      Value<String> lessonId,
      Value<bool> completed,
      Value<int> bestScore,
      Value<DateTime?> completedAt,
      Value<int> updatedAt,
      Value<bool> dirty,
      Value<int> rowid,
    });

class $$LessonProgressTableFilterComposer
    extends Composer<_$AppDatabase, $LessonProgressTable> {
  $$LessonProgressTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get lessonId => $composableBuilder(
    column: $table.lessonId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bestScore => $composableBuilder(
    column: $table.bestScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LessonProgressTableOrderingComposer
    extends Composer<_$AppDatabase, $LessonProgressTable> {
  $$LessonProgressTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get lessonId => $composableBuilder(
    column: $table.lessonId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bestScore => $composableBuilder(
    column: $table.bestScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LessonProgressTableAnnotationComposer
    extends Composer<_$AppDatabase, $LessonProgressTable> {
  $$LessonProgressTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get lessonId =>
      $composableBuilder(column: $table.lessonId, builder: (column) => column);

  GeneratedColumn<bool> get completed =>
      $composableBuilder(column: $table.completed, builder: (column) => column);

  GeneratedColumn<int> get bestScore =>
      $composableBuilder(column: $table.bestScore, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get dirty =>
      $composableBuilder(column: $table.dirty, builder: (column) => column);
}

class $$LessonProgressTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LessonProgressTable,
          LessonProgressRow,
          $$LessonProgressTableFilterComposer,
          $$LessonProgressTableOrderingComposer,
          $$LessonProgressTableAnnotationComposer,
          $$LessonProgressTableCreateCompanionBuilder,
          $$LessonProgressTableUpdateCompanionBuilder,
          (
            LessonProgressRow,
            BaseReferences<
              _$AppDatabase,
              $LessonProgressTable,
              LessonProgressRow
            >,
          ),
          LessonProgressRow,
          PrefetchHooks Function()
        > {
  $$LessonProgressTableTableManager(
    _$AppDatabase db,
    $LessonProgressTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LessonProgressTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LessonProgressTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LessonProgressTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> lessonId = const Value.absent(),
                Value<bool> completed = const Value.absent(),
                Value<int> bestScore = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LessonProgressCompanion(
                lessonId: lessonId,
                completed: completed,
                bestScore: bestScore,
                completedAt: completedAt,
                updatedAt: updatedAt,
                dirty: dirty,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String lessonId,
                Value<bool> completed = const Value.absent(),
                Value<int> bestScore = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LessonProgressCompanion.insert(
                lessonId: lessonId,
                completed: completed,
                bestScore: bestScore,
                completedAt: completedAt,
                updatedAt: updatedAt,
                dirty: dirty,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LessonProgressTable, LessonProgressRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $LessonProgressTable,
                    LessonProgressRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LessonProgressTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LessonProgressTable,
      LessonProgressRow,
      $$LessonProgressTableFilterComposer,
      $$LessonProgressTableOrderingComposer,
      $$LessonProgressTableAnnotationComposer,
      $$LessonProgressTableCreateCompanionBuilder,
      $$LessonProgressTableUpdateCompanionBuilder,
      (
        LessonProgressRow,
        BaseReferences<_$AppDatabase, $LessonProgressTable, LessonProgressRow>,
      ),
      LessonProgressRow,
      PrefetchHooks Function()
    >;
typedef $$WordProgressTableCreateCompanionBuilder =
    WordProgressCompanion Function({
      required String wordId,
      Value<double> easeFactor,
      Value<int> intervalDays,
      Value<int> repetitions,
      required DateTime dueDate,
      Value<int> updatedAt,
      Value<bool> dirty,
      Value<int> rowid,
    });
typedef $$WordProgressTableUpdateCompanionBuilder =
    WordProgressCompanion Function({
      Value<String> wordId,
      Value<double> easeFactor,
      Value<int> intervalDays,
      Value<int> repetitions,
      Value<DateTime> dueDate,
      Value<int> updatedAt,
      Value<bool> dirty,
      Value<int> rowid,
    });

class $$WordProgressTableFilterComposer
    extends Composer<_$AppDatabase, $WordProgressTable> {
  $$WordProgressTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get wordId => $composableBuilder(
    column: $table.wordId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get easeFactor => $composableBuilder(
    column: $table.easeFactor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get intervalDays => $composableBuilder(
    column: $table.intervalDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get repetitions => $composableBuilder(
    column: $table.repetitions,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WordProgressTableOrderingComposer
    extends Composer<_$AppDatabase, $WordProgressTable> {
  $$WordProgressTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get wordId => $composableBuilder(
    column: $table.wordId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get easeFactor => $composableBuilder(
    column: $table.easeFactor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get intervalDays => $composableBuilder(
    column: $table.intervalDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get repetitions => $composableBuilder(
    column: $table.repetitions,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WordProgressTableAnnotationComposer
    extends Composer<_$AppDatabase, $WordProgressTable> {
  $$WordProgressTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get wordId =>
      $composableBuilder(column: $table.wordId, builder: (column) => column);

  GeneratedColumn<double> get easeFactor => $composableBuilder(
    column: $table.easeFactor,
    builder: (column) => column,
  );

  GeneratedColumn<int> get intervalDays => $composableBuilder(
    column: $table.intervalDays,
    builder: (column) => column,
  );

  GeneratedColumn<int> get repetitions => $composableBuilder(
    column: $table.repetitions,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get dueDate =>
      $composableBuilder(column: $table.dueDate, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get dirty =>
      $composableBuilder(column: $table.dirty, builder: (column) => column);
}

class $$WordProgressTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WordProgressTable,
          WordProgressRow,
          $$WordProgressTableFilterComposer,
          $$WordProgressTableOrderingComposer,
          $$WordProgressTableAnnotationComposer,
          $$WordProgressTableCreateCompanionBuilder,
          $$WordProgressTableUpdateCompanionBuilder,
          (
            WordProgressRow,
            BaseReferences<_$AppDatabase, $WordProgressTable, WordProgressRow>,
          ),
          WordProgressRow,
          PrefetchHooks Function()
        > {
  $$WordProgressTableTableManager(_$AppDatabase db, $WordProgressTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WordProgressTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WordProgressTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WordProgressTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> wordId = const Value.absent(),
                Value<double> easeFactor = const Value.absent(),
                Value<int> intervalDays = const Value.absent(),
                Value<int> repetitions = const Value.absent(),
                Value<DateTime> dueDate = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WordProgressCompanion(
                wordId: wordId,
                easeFactor: easeFactor,
                intervalDays: intervalDays,
                repetitions: repetitions,
                dueDate: dueDate,
                updatedAt: updatedAt,
                dirty: dirty,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String wordId,
                Value<double> easeFactor = const Value.absent(),
                Value<int> intervalDays = const Value.absent(),
                Value<int> repetitions = const Value.absent(),
                required DateTime dueDate,
                Value<int> updatedAt = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WordProgressCompanion.insert(
                wordId: wordId,
                easeFactor: easeFactor,
                intervalDays: intervalDays,
                repetitions: repetitions,
                dueDate: dueDate,
                updatedAt: updatedAt,
                dirty: dirty,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$WordProgressTable, WordProgressRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $WordProgressTable,
                    WordProgressRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WordProgressTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WordProgressTable,
      WordProgressRow,
      $$WordProgressTableFilterComposer,
      $$WordProgressTableOrderingComposer,
      $$WordProgressTableAnnotationComposer,
      $$WordProgressTableCreateCompanionBuilder,
      $$WordProgressTableUpdateCompanionBuilder,
      (
        WordProgressRow,
        BaseReferences<_$AppDatabase, $WordProgressTable, WordProgressRow>,
      ),
      WordProgressRow,
      PrefetchHooks Function()
    >;
typedef $$UserStatsTableCreateCompanionBuilder = UserStatsCompanion Function({
  Value<int> id,
  Value<int> xp,
  Value<int> streak,
  Value<DateTime?> lastActiveDate,
  Value<int> updatedAt,
  Value<bool> dirty,
});
typedef $$UserStatsTableUpdateCompanionBuilder = UserStatsCompanion Function({
  Value<int> id,
  Value<int> xp,
  Value<int> streak,
  Value<DateTime?> lastActiveDate,
  Value<int> updatedAt,
  Value<bool> dirty,
});

class $$UserStatsTableFilterComposer
    extends Composer<_$AppDatabase, $UserStatsTable> {
  $$UserStatsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get xp => $composableBuilder(
    column: $table.xp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get streak => $composableBuilder(
    column: $table.streak,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastActiveDate => $composableBuilder(
    column: $table.lastActiveDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UserStatsTableOrderingComposer
    extends Composer<_$AppDatabase, $UserStatsTable> {
  $$UserStatsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get xp => $composableBuilder(
    column: $table.xp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get streak => $composableBuilder(
    column: $table.streak,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastActiveDate => $composableBuilder(
    column: $table.lastActiveDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UserStatsTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserStatsTable> {
  $$UserStatsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get xp =>
      $composableBuilder(column: $table.xp, builder: (column) => column);

  GeneratedColumn<int> get streak =>
      $composableBuilder(column: $table.streak, builder: (column) => column);

  GeneratedColumn<DateTime> get lastActiveDate => $composableBuilder(
    column: $table.lastActiveDate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get dirty =>
      $composableBuilder(column: $table.dirty, builder: (column) => column);
}

class $$UserStatsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UserStatsTable,
          UserStatsRow,
          $$UserStatsTableFilterComposer,
          $$UserStatsTableOrderingComposer,
          $$UserStatsTableAnnotationComposer,
          $$UserStatsTableCreateCompanionBuilder,
          $$UserStatsTableUpdateCompanionBuilder,
          (
            UserStatsRow,
            BaseReferences<_$AppDatabase, $UserStatsTable, UserStatsRow>,
          ),
          UserStatsRow,
          PrefetchHooks Function()
        > {
  $$UserStatsTableTableManager(_$AppDatabase db, $UserStatsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserStatsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserStatsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserStatsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> xp = const Value.absent(),
                Value<int> streak = const Value.absent(),
                Value<DateTime?> lastActiveDate = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
              }) => UserStatsCompanion(
                id: id,
                xp: xp,
                streak: streak,
                lastActiveDate: lastActiveDate,
                updatedAt: updatedAt,
                dirty: dirty,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> xp = const Value.absent(),
                Value<int> streak = const Value.absent(),
                Value<DateTime?> lastActiveDate = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
              }) => UserStatsCompanion.insert(
                id: id,
                xp: xp,
                streak: streak,
                lastActiveDate: lastActiveDate,
                updatedAt: updatedAt,
                dirty: dirty,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$UserStatsTable, UserStatsRow>(table),
                  BaseReferences<_$AppDatabase, $UserStatsTable, UserStatsRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UserStatsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UserStatsTable,
      UserStatsRow,
      $$UserStatsTableFilterComposer,
      $$UserStatsTableOrderingComposer,
      $$UserStatsTableAnnotationComposer,
      $$UserStatsTableCreateCompanionBuilder,
      $$UserStatsTableUpdateCompanionBuilder,
      (
        UserStatsRow,
        BaseReferences<_$AppDatabase, $UserStatsTable, UserStatsRow>,
      ),
      UserStatsRow,
      PrefetchHooks Function()
    >;
typedef $$SyncMetadataTableCreateCompanionBuilder =
    SyncMetadataCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$SyncMetadataTableUpdateCompanionBuilder =
    SyncMetadataCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$SyncMetadataTableFilterComposer
    extends Composer<_$AppDatabase, $SyncMetadataTable> {
  $$SyncMetadataTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncMetadataTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncMetadataTable> {
  $$SyncMetadataTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncMetadataTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncMetadataTable> {
  $$SyncMetadataTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SyncMetadataTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncMetadataTable,
          SyncMetadataData,
          $$SyncMetadataTableFilterComposer,
          $$SyncMetadataTableOrderingComposer,
          $$SyncMetadataTableAnnotationComposer,
          $$SyncMetadataTableCreateCompanionBuilder,
          $$SyncMetadataTableUpdateCompanionBuilder,
          (
            SyncMetadataData,
            BaseReferences<_$AppDatabase, $SyncMetadataTable, SyncMetadataData>,
          ),
          SyncMetadataData,
          PrefetchHooks Function()
        > {
  $$SyncMetadataTableTableManager(_$AppDatabase db, $SyncMetadataTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncMetadataTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncMetadataTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncMetadataTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => SyncMetadataCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => SyncMetadataCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncMetadataTable, SyncMetadataData>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $SyncMetadataTable,
                    SyncMetadataData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncMetadataTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncMetadataTable,
      SyncMetadataData,
      $$SyncMetadataTableFilterComposer,
      $$SyncMetadataTableOrderingComposer,
      $$SyncMetadataTableAnnotationComposer,
      $$SyncMetadataTableCreateCompanionBuilder,
      $$SyncMetadataTableUpdateCompanionBuilder,
      (
        SyncMetadataData,
        BaseReferences<_$AppDatabase, $SyncMetadataTable, SyncMetadataData>,
      ),
      SyncMetadataData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$LessonProgressTableTableManager get lessonProgress =>
      $$LessonProgressTableTableManager(_db, _db.lessonProgress);
  $$WordProgressTableTableManager get wordProgress =>
      $$WordProgressTableTableManager(_db, _db.wordProgress);
  $$UserStatsTableTableManager get userStats =>
      $$UserStatsTableTableManager(_db, _db.userStats);
  $$SyncMetadataTableTableManager get syncMetadata =>
      $$SyncMetadataTableTableManager(_db, _db.syncMetadata);
}
```

## lib/core/router/app_router.dart

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/presentation/auth_screens.dart';
import '../../features/auth/presentation/auth_loading_screen.dart';
import '../../features/sync/presentation/sync_providers.dart';

import '../../features/flashcards/presentation/review_screen.dart';
import '../../features/flashcards/presentation/review_session_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/home/presentation/learn_screen.dart';
import '../../features/lessons/presentation/lesson_screen.dart';
import '../../features/onboarding/presentation/welcome_screen.dart';
import '../../features/onboarding/presentation/daily_goal_screen.dart';
import '../../features/onboarding/presentation/language_screen.dart';
import '../../features/onboarding/presentation/onboarding_controller.dart';
import '../../features/onboarding/presentation/startup_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../shared/widgets/placeholder_page.dart';
import '../constants/app_routes.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  // Refresh redirects when preferences change without rebuilding the router.
  final refresh = ValueNotifier(0);
  ref.listen(authStateProvider, (previous, next) => refresh.value++);
  ref.listen(accountReadyProvider, (previous, next) => refresh.value++);
  ref.listen(onboardingProvider, (previous, next) => refresh.value++);
  ref.listen(
    onboardingFlowProvider.select((draft) => draft.courseId),
    (previous, next) => refresh.value++,
  );
  final router = GoRouter(
    initialLocation: AppRoutes.welcome,
    refreshListenable: refresh,
    redirect: (context, state) {
      final path = state.uri.path;
      final auth = ref.read(authStateProvider);
      const authPaths = {
        AppRoutes.login,
        AppRoutes.register,
        AppRoutes.forgotPassword,
      };
      if (auth.isLoading) {
        return path == AppRoutes.authLoading ? null : AppRoutes.authLoading;
      }
      final identity = auth.asData?.value;
      if (identity == null) {
        return authPaths.contains(path) ? null : AppRoutes.login;
      }
      if (identity.needsPasswordReset) {
        return path == AppRoutes.resetPassword ? null : AppRoutes.resetPassword;
      }
      final ready = ref.read(accountReadyProvider);
      if (ready.isLoading || ready.hasError) {
        return path == AppRoutes.authLoading ? null : AppRoutes.authLoading;
      }
      if (authPaths.contains(path) ||
          path == AppRoutes.authLoading ||
          path == AppRoutes.resetPassword) {
        return AppRoutes.home;
      }
      final settings = ref.read(onboardingProvider);
      const onboardingPaths = {
        AppRoutes.welcome,
        AppRoutes.languages,
        AppRoutes.dailyGoal,
      };
      if (settings.isLoading || settings.hasError) {
        return path == AppRoutes.startup ? null : AppRoutes.startup;
      }
      if (settings.requireValue == null) {
        if (!onboardingPaths.contains(path)) return AppRoutes.welcome;
        if (path == AppRoutes.dailyGoal &&
            ref.read(onboardingFlowProvider).courseId == null) {
          return AppRoutes.languages;
        }
        return null;
      }
      return onboardingPaths.contains(path) ||
              path == '/' ||
              path == AppRoutes.startup
          ? AppRoutes.home
          : null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.resetPassword,
        builder: (context, state) => const ResetPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.authLoading,
        builder: (context, state) => const AuthLoadingScreen(),
      ),
      GoRoute(path: '/', redirect: (context, state) => AppRoutes.welcome),
      GoRoute(
        path: AppRoutes.welcome,
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.startup,
        builder: (context, state) => const StartupScreen(),
      ),
      GoRoute(
        path: AppRoutes.languages,
        builder: (context, state) => const LanguageScreen(),
      ),
      GoRoute(
        path: AppRoutes.dailyGoal,
        builder: (context, state) => const DailyGoalScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => HomeScreen(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const LearnScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.review,
                builder: (context, state) => const ReviewScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.lesson,
        builder: (context, state) =>
            LessonScreen(lessonId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.reviewSession,
        builder: (context, state) => const ReviewSessionScreen(),
      ),
    ],
    errorBuilder: (context, state) => PlaceholderPage(
      title: 'Page not found',
      message: 'This page is unavailable.',
      action: FilledButton(
        onPressed: () => context.go(AppRoutes.home),
        child: const Text('Go to Learn'),
      ),
    ),
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});
```

## lib/features/flashcards/data/review_repository.dart

```dart
import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/sync_timestamp.dart';
import '../../lessons/domain/course.dart';
import '../domain/review_session.dart';
import '../domain/sm2.dart';
import '../domain/word.dart';
import 'word_enrollment.dart';

final reviewRepositoryProvider = Provider<ReviewRepository>(
  (ref) => ReviewRepository(
    ref.watch(appDatabaseProvider),
    clock: ref.watch(clockProvider),
  ),
);

class ReviewRepository {
  ReviewRepository(this.database, {DateTime Function()? clock})
    : clock = clock ?? DateTime.now;
  final AppDatabase database;
  final DateTime Function() clock;

  Future<void> enrollCompletedLessons(Course course) async {
    await database.transaction(() async {
      final completed = await (database.select(
        database.lessonProgress,
      )..where((row) => row.completed.equals(true))).get();
      final completedIds = completed.map((row) => row.lessonId).toSet();
      final knownWords = course.words.map((word) => word.id).toSet();
      final ids = course.units
          .expand((unit) => unit.lessons)
          .where((lesson) => completedIds.contains(lesson.id))
          .expand((lesson) => lesson.wordIds)
          .where(knownWords.contains);
      await enrollWords(database, ids, clock());
    });
  }

  SimpleSelectStatement<WordProgress, WordProgressRow> _query(Course course) =>
      database.select(database.wordProgress)
        ..where((row) => row.wordId.isIn(course.words.map((word) => word.id)))
        ..orderBy([
          (row) => OrderingTerm.asc(row.dueDate),
          (row) => OrderingTerm.asc(row.wordId),
        ]);

  Future<List<Word>> loadDueCards(Course course) async {
    final rows = await _query(course).get();
    final now = clock().toUtc();
    final words = {for (final word in course.words) word.id: word};
    return rows
        .where((row) => !row.dueDate.toUtc().isAfter(now))
        .map((row) => words[row.wordId]!)
        .toList(growable: false);
  }

  Stream<ReviewOverview> watchOverview(Course course) {
    late StreamController<ReviewOverview> controller;
    StreamSubscription<List<WordProgressRow>>? subscription;
    Timer? timer;
    List<WordProgressRow>? latest;

    void emit() {
      timer?.cancel();
      final rows = latest;
      if (rows == null || controller.isClosed || controller.isPaused) return;
      final now = clock().toUtc();
      final future = rows.where((row) => row.dueDate.toUtc().isAfter(now));
      final nextDue = future.isEmpty ? null : future.first.dueDate.toUtc();
      controller.add(
        ReviewOverview(
          dueCount: rows.length - future.length,
          totalCards: rows.length,
          nextDue: nextDue,
        ),
      );
      if (nextDue != null) timer = Timer(nextDue.difference(now), emit);
    }

    controller = StreamController<ReviewOverview>(
      onListen: () {
        subscription = _query(course).watch().listen(
          (rows) {
            latest = rows;
            emit();
          },
          onError: (Object error, StackTrace stack) {
            timer?.cancel();
            controller.addError(error, stack);
          },
        );
      },
      onPause: () {
        timer?.cancel();
        subscription?.pause();
      },
      onResume: () {
        subscription?.resume();
        emit();
      },
      onCancel: () async {
        timer?.cancel();
        await subscription?.cancel();
      },
    );
    return controller.stream;
  }

  Future<Sm2Schedule> rate(String wordId, int quality) =>
      database.transaction(() async {
        final row = await (database.select(
          database.wordProgress,
        )..where((row) => row.wordId.equals(wordId))).getSingle();
        final next = const Sm2().schedule(
          quality: quality,
          repetitions: row.repetitions,
          easeFactor: row.easeFactor,
          intervalDays: row.intervalDays,
          reviewedAt: clock(),
        );
        await (database.update(
          database.wordProgress,
        )..where((row) => row.wordId.equals(wordId))).write(
          WordProgressCompanion(
            repetitions: Value(next.repetitions),
            easeFactor: Value(next.easeFactor),
            intervalDays: Value(next.intervalDays),
            dueDate: Value(next.dueDate),
            updatedAt: Value(nextSyncTimestamp(row.updatedAt, clock())),
            dirty: const Value(true),
          ),
        );
        return next;
      });
}
```

## lib/features/flashcards/data/word_enrollment.dart

```dart
import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';

/// The caller owns the transaction. Existing schedules are never overwritten.
Future<void> enrollWords(
  AppDatabase database,
  Iterable<String> wordIds,
  DateTime now,
) async {
  final ids = wordIds.toSet();
  if (ids.isEmpty) return;
  await database.batch(
    (batch) => batch.insertAll(database.wordProgress, [
      for (final id in ids)
        WordProgressCompanion.insert(
          wordId: id,
          dueDate: now.toUtc(),
          updatedAt: Value(now.toUtc().microsecondsSinceEpoch),
        ),
    ], mode: InsertMode.insertOrIgnore),
  );
}
```

## lib/features/lessons/data/lesson_completion_repository.dart

```dart
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/sync_timestamp.dart';
import '../../flashcards/data/word_enrollment.dart';
import '../domain/lesson_session.dart';

final lessonCompletionRepositoryProvider = Provider<LessonCompletionRepository>(
  (ref) => LessonCompletionRepository(
    ref.watch(appDatabaseProvider),
    clock: ref.watch(clockProvider),
  ),
);

class LessonCompletionRepository {
  LessonCompletionRepository(this.database, {DateTime Function()? clock})
    : clock = clock ?? DateTime.now;
  final AppDatabase database;
  final DateTime Function() clock;

  Future<void> save(
    LessonResult result, {
    required List<String> wordIds,
  }) async {
    if (!result.success) return;
    await database.transaction(() async {
      final previous =
          await (database.select(database.lessonProgress)
                ..where((table) => table.lessonId.equals(result.lessonId)))
              .getSingleOrNull();
      await database
          .into(database.lessonProgress)
          .insertOnConflictUpdate(
            LessonProgressCompanion.insert(
              lessonId: result.lessonId,
              completed: const Value(true),
              bestScore: Value(max(previous?.bestScore ?? 0, result.score)),
              completedAt: Value(previous?.completedAt ?? clock().toUtc()),
              updatedAt: Value(
                nextSyncTimestamp(previous?.updatedAt ?? 0, clock()),
              ),
              dirty: const Value(true),
            ),
          );
      final stats = await (database.select(
        database.userStats,
      )..where((row) => row.id.equals(1))).getSingleOrNull();
      if (stats == null) throw StateError('User stats row is missing');
      final changed =
          await (database.update(
            database.userStats,
          )..where((table) => table.id.equals(1))).write(
            UserStatsCompanion.custom(
              xp: database.userStats.xp + Constant(result.xp),
              lastActiveDate: Constant(clock().toUtc()),
              updatedAt: Constant(nextSyncTimestamp(stats.updatedAt, clock())),
              dirty: const Constant(true),
            ),
          );
      if (changed != 1) throw StateError('User stats row is missing');
      await enrollWords(database, wordIds, clock());
    });
  }
}
```

## lib/features/profile/presentation/profile_screen.dart

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/responsive_body.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/presentation/account_controller.dart';
import '../../sync/data/sync_service.dart';
import '../../sync/presentation/sync_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(authStateProvider).asData?.value;
    final action = ref.watch(accountControllerProvider);
    final status = ref.watch(syncStatusProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ResponsiveBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Your account',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            Text(
              account?.email ?? '',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            Text(switch (status) {
              SyncStatus.idle => 'Sync ready',
              SyncStatus.syncing => 'Syncing your progress...',
              SyncStatus.offline =>
                'Offline. Changes are saved on this device.',
            }),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: status == SyncStatus.syncing
                  ? null
                  : () => ref.read(syncServiceProvider)?.request(),
              child: const Text('Sync now'),
            ),
            const SizedBox(height: 24),
            if (action.error != null)
              Semantics(
                liveRegion: true,
                child: Text(
                  action.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            FilledButton.tonal(
              onPressed: action.busy
                  ? null
                  : ref.read(accountControllerProvider.notifier).signOut,
              child: Text(action.busy ? 'Signing out...' : 'Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}
```

## linux/flutter/generated_plugin_registrant.cc

```cpp
//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <app_links_linux/app_links_plugin_linux.h>
#include <url_launcher_linux/url_launcher_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) app_links_linux_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "AppLinksPluginLinux");
  app_links_plugin_linux_register_with_registrar(app_links_linux_registrar);
  g_autoptr(FlPluginRegistrar) url_launcher_linux_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "UrlLauncherPlugin");
  url_launcher_plugin_register_with_registrar(url_launcher_linux_registrar);
}
```

## linux/flutter/generated_plugins.cmake

```cmake
#
# Generated file, do not edit.
#

list(APPEND FLUTTER_PLUGIN_LIST
  app_links_linux
  url_launcher_linux
)

list(APPEND FLUTTER_FFI_PLUGIN_LIST
  jni
)

set(PLUGIN_BUNDLED_LIBRARIES)

foreach(plugin ${FLUTTER_PLUGIN_LIST})
  add_subdirectory(flutter/ephemeral/.plugin_symlinks/${plugin}/linux plugins/${plugin})
  target_link_libraries(${BINARY_NAME} PRIVATE ${plugin}_plugin)
  list(APPEND PLUGIN_BUNDLED_LIBRARIES $<TARGET_FILE:${plugin}_plugin>)
  list(APPEND PLUGIN_BUNDLED_LIBRARIES ${${plugin}_bundled_libraries})
endforeach(plugin)

foreach(ffi_plugin ${FLUTTER_FFI_PLUGIN_LIST})
  add_subdirectory(flutter/ephemeral/.plugin_symlinks/${ffi_plugin}/linux plugins/${ffi_plugin})
  list(APPEND PLUGIN_BUNDLED_LIBRARIES ${${ffi_plugin}_bundled_libraries})
endforeach(ffi_plugin)
```

## macos/Flutter/GeneratedPluginRegistrant.swift

```swift
//
//  Generated file. Do not edit.
//

import FlutterMacOS
import Foundation

import app_links
import shared_preferences_foundation
import url_launcher_macos

func RegisterGeneratedPlugins(registry: FlutterPluginRegistry) {
  AppLinksMacosPlugin.register(with: registry.registrar(forPlugin: "AppLinksMacosPlugin"))
  SharedPreferencesPlugin.register(with: registry.registrar(forPlugin: "SharedPreferencesPlugin"))
  UrlLauncherPlugin.register(with: registry.registrar(forPlugin: "UrlLauncherPlugin"))
}
```

## pubspec.lock

```yaml
# Generated by pub
# See https://dart.dev/tools/pub/glossary#lockfile
packages:
  _fe_analyzer_shared:
    dependency: transitive
    description:
      name: _fe_analyzer_shared
      sha256: "1c5591cc6f252d5f440d96ab87c03e43504be552a3fa49d7cb7563f04c51fb0a"
      url: "https://pub.dev"
    source: hosted
    version: "111.0.0"
  analyzer:
    dependency: transitive
    description:
      name: analyzer
      sha256: "6c39bd5486a310e56217bed7cb1691377959f31be4227e41750107db7e6dd55c"
      url: "https://pub.dev"
    source: hosted
    version: "14.7.0"
  app_links:
    dependency: transitive
    description:
      name: app_links
      sha256: "08ba88bf19d9edea33130cb71c8ced2cb982b4e00b82efef4a434d1357bc69c3"
      url: "https://pub.dev"
    source: hosted
    version: "7.2.2"
  app_links_linux:
    dependency: transitive
    description:
      name: app_links_linux
      sha256: "9ccb5802085a1e57bb07b6256fd1d61a78c7ec104944d4965e62938b4fefd9cb"
      url: "https://pub.dev"
    source: hosted
    version: "1.0.4"
  app_links_platform_interface:
    dependency: transitive
    description:
      name: app_links_platform_interface
      sha256: "7546f09a6e93f4a2df2fe2bd40a5c6c64310ac461b036d82b43033be7a59f809"
      url: "https://pub.dev"
    source: hosted
    version: "2.0.4"
  app_links_web:
    dependency: transitive
    description:
      name: app_links_web
      sha256: "382d32c6f486f15b1d7f5d6a37a70a481a4fc08382eef419d373169921a3e765"
      url: "https://pub.dev"
    source: hosted
    version: "1.0.5"
  args:
    dependency: transitive
    description:
      name: args
      sha256: d0481093c50b1da8910eb0bb301626d4d8eb7284aa739614d2b394ee09e3ea04
      url: "https://pub.dev"
    source: hosted
    version: "2.7.0"
  async:
    dependency: transitive
    description:
      name: async
      sha256: e2eb0491ba5ddb6177742d2da23904574082139b07c1e33b8503b9f46f3e1a37
      url: "https://pub.dev"
    source: hosted
    version: "2.13.1"
  boolean_selector:
    dependency: transitive
    description:
      name: boolean_selector
      sha256: "8aab1771e1243a5063b8b0ff68042d67334e3feab9e95b9490f9a6ebf73b42ea"
      url: "https://pub.dev"
    source: hosted
    version: "2.1.2"
  build:
    dependency: transitive
    description:
      name: build
      sha256: "50df3d1558953a0d936401c1687cc41dbc039f9132f538c7bcb2aac2a580ae7f"
      url: "https://pub.dev"
    source: hosted
    version: "5.0.0"
  build_config:
    dependency: transitive
    description:
      name: build_config
      sha256: "4703a785fbc3c266c5c7518589d0863f6a05078ee33f7ca5aa4b87a56f1cedd2"
      url: "https://pub.dev"
    source: hosted
    version: "1.4.0"
  build_daemon:
    dependency: transitive
    description:
      name: build_daemon
      sha256: "39ab65f7c60c19af64b9ef96e6a5d3ab48355f7dddfd98a9079d55a8cb6628fc"
      url: "https://pub.dev"
    source: hosted
    version: "4.1.7"
  build_runner:
    dependency: "direct dev"
    description:
      name: build_runner
      sha256: "96b9da39a3a8d4365aa1ca6f7655437d80f514ba13d4c21d8408cc8aacb94681"
      url: "https://pub.dev"
    source: hosted
    version: "2.17.1"
  built_collection:
    dependency: transitive
    description:
      name: built_collection
      sha256: "44922ecebd8e3d0cef743dadd3b54df4e87e2a4c52a29465a1872aa9e192caa8"
      url: "https://pub.dev"
    source: hosted
    version: "5.1.2"
  built_value:
    dependency: transitive
    description:
      name: built_value
      sha256: f87ea98192116f7093cb214551ce1929caae0681fdba282b3d8b4462adee7bb7
      url: "https://pub.dev"
    source: hosted
    version: "8.13.0"
  characters:
    dependency: transitive
    description:
      name: characters
      sha256: faf38497bda5ead2a8c7615f4f7939df04333478bf32e4173fcb06d428b5716b
      url: "https://pub.dev"
    source: hosted
    version: "1.4.1"
  charcode:
    dependency: transitive
    description:
      name: charcode
      sha256: fb0f1107cac15a5ea6ef0a6ef71a807b9e4267c713bb93e00e92d737cc8dbd8a
      url: "https://pub.dev"
    source: hosted
    version: "1.4.0"
  checked_yaml:
    dependency: transitive
    description:
      name: checked_yaml
      sha256: "959525d3162f249993882720d52b7e0c833978df229be20702b33d48d91de70f"
      url: "https://pub.dev"
    source: hosted
    version: "2.0.4"
  cli_util:
    dependency: transitive
    description:
      name: cli_util
      sha256: "89b8801ba49f8b593fbf2d3e59efd0f566c46cd4ba6837ae2610c72b52a0f899"
      url: "https://pub.dev"
    source: hosted
    version: "0.6.0"
  clock:
    dependency: transitive
    description:
      name: clock
      sha256: e51d50bca3217c9a9fa2b41a30e4a38971133f5f9ec7a3d57bae095007f1d28e
      url: "https://pub.dev"
    source: hosted
    version: "1.1.3"
  code_assets:
    dependency: transitive
    description:
      name: code_assets
      sha256: bf394f466ba9205f1812a0433b392d6af280f155f56651eda7c18cc32ed493b8
      url: "https://pub.dev"
    source: hosted
    version: "1.2.1"
  collection:
    dependency: transitive
    description:
      name: collection
      sha256: "2f5709ae4d3d59dd8f7cd309b4e023046b57d8a6c82130785d2b0e5868084e76"
      url: "https://pub.dev"
    source: hosted
    version: "1.19.1"
  convert:
    dependency: transitive
    description:
      name: convert
      sha256: b30acd5944035672bc15c6b7a8b47d773e41e2f17de064350988c5d02adb1c68
      url: "https://pub.dev"
    source: hosted
    version: "3.1.2"
  crypto:
    dependency: transitive
    description:
      name: crypto
      sha256: e3626ae6270383c9e3a549f34c9e4cd26c09ae6a9adaab2bf4737a00340efdc4
      url: "https://pub.dev"
    source: hosted
    version: "3.0.8"
  cupertino_ui:
    dependency: transitive
    description:
      name: cupertino_ui
      sha256: "369e39a1c5c030a6212589c3da1809920b1c2cfade7b02aade7695bfa4b88c3a"
      url: "https://pub.dev"
    source: hosted
    version: "1.1.6"
  dart_jsonwebtoken:
    dependency: transitive
    description:
      name: dart_jsonwebtoken
      sha256: ad84e60181696513d04d5f2078e0bbc20365b911f46f647797317414bdc88fbe
      url: "https://pub.dev"
    source: hosted
    version: "3.4.1"
  dart_style:
    dependency: transitive
    description:
      name: dart_style
      sha256: a0e4f65339b31eb6a9e6a12e14b4682a48d46fbc54a82f4a702396fbdbac63a7
      url: "https://pub.dev"
    source: hosted
    version: "3.1.14"
  dio:
    dependency: "direct main"
    description:
      name: dio
      sha256: "852ec3b48cc431ac04fff978413c541502b67ffc3e26921e74e3d994694192c1"
      url: "https://pub.dev"
    source: hosted
    version: "5.11.1"
  dio_web_adapter:
    dependency: transitive
    description:
      name: dio_web_adapter
      sha256: "3a1b2cd7be71086f38504956e3ebcd2837288d231ff454bafa78021244102bfc"
      url: "https://pub.dev"
    source: hosted
    version: "2.2.2"
  drift:
    dependency: "direct main"
    description:
      name: drift
      sha256: "3179e7323b36d1852b42997b92ac72e8abcb61b1d58cfa8c6da9b540ab02a540"
      url: "https://pub.dev"
    source: hosted
    version: "2.35.3"
  drift_dev:
    dependency: "direct dev"
    description:
      name: drift_dev
      sha256: ff4201b38dfbbbc85ffcd85597ad63c7146d2303126241623ebfce89fc4c4bfe
      url: "https://pub.dev"
    source: hosted
    version: "2.35.2"
  drift_flutter:
    dependency: "direct main"
    description:
      name: drift_flutter
      sha256: "91acf4bee7c3c84467cba46455aa70e5292a3b889f4582645d74f2e5a8c106f2"
      url: "https://pub.dev"
    source: hosted
    version: "0.3.1"
  fake_async:
    dependency: transitive
    description:
      name: fake_async
      sha256: "5368f224a74523e8d2e7399ea1638b37aecfca824a3cc4dfdf77bf1fa905ac44"
      url: "https://pub.dev"
    source: hosted
    version: "1.3.3"
  ffi:
    dependency: transitive
    description:
      name: ffi
      sha256: "6d7fd89431262d8f3125e81b50d3847a091d846eafcd4fdb88dd06f36d705a45"
      url: "https://pub.dev"
    source: hosted
    version: "2.2.0"
  file:
    dependency: transitive
    description:
      name: file
      sha256: a3b4f84adafef897088c160faf7dfffb7696046cb13ae90b508c2cbc95d3b8d4
      url: "https://pub.dev"
    source: hosted
    version: "7.0.1"
  fixnum:
    dependency: transitive
    description:
      name: fixnum
      sha256: b6dc7065e46c974bc7c5f143080a6764ec7a4be6da1285ececdc37be96de53be
      url: "https://pub.dev"
    source: hosted
    version: "1.1.1"
  flutter:
    dependency: "direct main"
    description: flutter
    source: sdk
    version: "0.0.0"
  flutter_dotenv:
    dependency: "direct main"
    description:
      name: flutter_dotenv
      sha256: d41da11fb497314fbf89811ec30af02d1d898b47980a129f0a8c0a1720460ba2
      url: "https://pub.dev"
    source: hosted
    version: "6.0.1"
  flutter_lints:
    dependency: "direct dev"
    description:
      name: flutter_lints
      sha256: "3105dc8492f6183fb076ccf1f351ac3d60564bff92e20bfc4af9cc1651f4e7e1"
      url: "https://pub.dev"
    source: hosted
    version: "6.0.0"
  flutter_localizations:
    dependency: transitive
    description: flutter
    source: sdk
    version: "0.0.0"
  flutter_riverpod:
    dependency: "direct main"
    description:
      name: flutter_riverpod
      sha256: "2ae1a93a868ae5f2d5358f521a4bfae0da7a3bfe77a60515ab5c28953b50557f"
      url: "https://pub.dev"
    source: hosted
    version: "3.5.0"
  flutter_test:
    dependency: "direct dev"
    description: flutter
    source: sdk
    version: "0.0.0"
  flutter_web_plugins:
    dependency: transitive
    description: flutter
    source: sdk
    version: "0.0.0"
  functions_client:
    dependency: transitive
    description:
      name: functions_client
      sha256: "931e822688d2e97867b2300e2fdbb08c9db73f8653fc83efc7a259d2e0cca769"
      url: "https://pub.dev"
    source: hosted
    version: "2.7.1"
  glob:
    dependency: transitive
    description:
      name: glob
      sha256: "218aeb56050c714f62a3182775320dfa04602b55074873e24e31bbd39bda96fb"
      url: "https://pub.dev"
    source: hosted
    version: "2.2.0"
  go_router:
    dependency: "direct main"
    description:
      name: go_router
      sha256: "5a44b0bd6131888bda5f770be5db2e08a59063724c6fa534ea4ec7c9fc3f841b"
      url: "https://pub.dev"
    source: hosted
    version: "18.1.3"
  gotrue:
    dependency: transitive
    description:
      name: gotrue
      sha256: cca816226824160e40d149816fd89740cc64dda1eaa3d9161e334330b18bba89
      url: "https://pub.dev"
    source: hosted
    version: "2.27.3"
  graphs:
    dependency: transitive
    description:
      name: graphs
      sha256: "741bbf84165310a68ff28fe9e727332eef1407342fca52759cb21ad8177bb8d0"
      url: "https://pub.dev"
    source: hosted
    version: "2.3.2"
  hooks:
    dependency: transitive
    description:
      name: hooks
      sha256: "9a62a50b50b769a737bc0a8ff381f333529df3ab746b2f6b02e83760231455ba"
      url: "https://pub.dev"
    source: hosted
    version: "2.0.2"
  http:
    dependency: transitive
    description:
      name: http
      sha256: "87721a4a50b19c7f1d49001e51409bddc46303966ce89a65af4f4e6004896412"
      url: "https://pub.dev"
    source: hosted
    version: "1.6.0"
  http_multi_server:
    dependency: transitive
    description:
      name: http_multi_server
      sha256: "361668bdd71f0ae2dc6d17b75a593520f3c414af6534f9eed1aa72049dd71d18"
      url: "https://pub.dev"
    source: hosted
    version: "3.2.3"
  http_parser:
    dependency: transitive
    description:
      name: http_parser
      sha256: "178d74305e7866013777bab2c3d8726205dc5a4dd935297175b19a23a2e66571"
      url: "https://pub.dev"
    source: hosted
    version: "4.1.2"
  intl:
    dependency: "direct main"
    description:
      name: intl
      sha256: "1ca20c894b1717686a2319b8548763d812bc0aabdac580420a44c5178c57a867"
      url: "https://pub.dev"
    source: hosted
    version: "0.20.3"
  io:
    dependency: transitive
    description:
      name: io
      sha256: "2635216ca6a737e60de577ffa1a48a0bec76ca8a62917cfc1bb88c14c570646f"
      url: "https://pub.dev"
    source: hosted
    version: "1.1.0"
  jni:
    dependency: transitive
    description:
      name: jni
      sha256: "2e91e6087291affd10b31b6c872f3e3ac7dc5d93b51b5ba485d930c8f08bde6c"
      url: "https://pub.dev"
    source: hosted
    version: "1.1.2"
  jni_flutter:
    dependency: transitive
    description:
      name: jni_flutter
      sha256: "0dd33d67797560f66e961a6053882d4df54bd345bf063b8fe7ea133f7ad8b191"
      url: "https://pub.dev"
    source: hosted
    version: "1.0.4+1"
  jni_util:
    dependency: transitive
    description:
      name: jni_util
      sha256: "1ba86da04a5f2bf18fde2edb235587e70c5b0fc5bd4ba955f46b00942c3fc35f"
      url: "https://pub.dev"
    source: hosted
    version: "1.0.0"
  json_annotation:
    dependency: transitive
    description:
      name: json_annotation
      sha256: "2a743920d81b7910627f68ee2c9ac1fc0bfee32b9fc3403587d7c6791ca12f80"
      url: "https://pub.dev"
    source: hosted
    version: "4.12.0"
  leak_tracker:
    dependency: transitive
    description:
      name: leak_tracker
      sha256: "33e2e26bdd85a0112ec15400c8cbffea70d0f9c3407491f672a2fad47915e2de"
      url: "https://pub.dev"
    source: hosted
    version: "11.0.2"
  leak_tracker_flutter_testing:
    dependency: transitive
    description:
      name: leak_tracker_flutter_testing
      sha256: "1dbc140bb5a23c75ea9c4811222756104fbcd1a27173f0c34ca01e16bea473c1"
      url: "https://pub.dev"
    source: hosted
    version: "3.0.10"
  leak_tracker_testing:
    dependency: transitive
    description:
      name: leak_tracker_testing
      sha256: "8d5a2d49f4a66b49744b23b018848400d23e54caf9463f4eb20df3eb8acb2eb1"
      url: "https://pub.dev"
    source: hosted
    version: "3.0.2"
  lints:
    dependency: transitive
    description:
      name: lints
      sha256: "12f842a479589fea194fe5c5a3095abc7be0c1f2ddfa9a0e76aed1dbd26a87df"
      url: "https://pub.dev"
    source: hosted
    version: "6.1.0"
  listen:
    dependency: transitive
    description:
      name: listen
      sha256: "47501a08016a43fcad79252439d723f50f14f88fa7bfd8a177e0a417e5c9e1f2"
      url: "https://pub.dev"
    source: hosted
    version: "1.0.1"
  logging:
    dependency: transitive
    description:
      name: logging
      sha256: c8245ada5f1717ed44271ed1c26b8ce85ca3228fd2ffdb75468ab01979309d61
      url: "https://pub.dev"
    source: hosted
    version: "1.3.0"
  matcher:
    dependency: transitive
    description:
      name: matcher
      sha256: "31bd099b47c10cd1aeb55146a2d46ce0277630ecef3f7dae54ad7873f36696cd"
      url: "https://pub.dev"
    source: hosted
    version: "0.12.20"
  material_color_utilities:
    dependency: transitive
    description:
      name: material_color_utilities
      sha256: "9c337007e82b1889149c82ed242ed1cb24a66044e30979c44912381e9be4c48b"
      url: "https://pub.dev"
    source: hosted
    version: "0.13.0"
  material_ui:
    dependency: transitive
    description:
      name: material_ui
      sha256: a30f5d0625b6b83770f53ca3f7aafd6fd9d147cb3853f54a70668541046fe5d6
      url: "https://pub.dev"
    source: hosted
    version: "1.10.0"
  meta:
    dependency: transitive
    description:
      name: meta
      sha256: c82594181e3312f3d0695fc95aaaf7758d75b8d4ae2bbecf223b9fd5109a059d
      url: "https://pub.dev"
    source: hosted
    version: "1.18.3"
  mime:
    dependency: transitive
    description:
      name: mime
      sha256: bd47de35f07e27267e69c8c8b22edf9473bfee170a60d60fcc93730c5144b7f6
      url: "https://pub.dev"
    source: hosted
    version: "2.1.0"
  mocktail:
    dependency: "direct dev"
    description:
      name: mocktail
      sha256: "5e1bf53cc7baa8062a33b84424deb61513858ea05c601b8509e683815b5914aa"
      url: "https://pub.dev"
    source: hosted
    version: "1.0.5"
  native_toolchain_c:
    dependency: transitive
    description:
      name: native_toolchain_c
      sha256: f9c168717100ae6d9fee9ffb0be379bf1f8b26b0f6bcbd4fdddcd931993a6a72
      url: "https://pub.dev"
    source: hosted
    version: "0.19.2"
  objective_c:
    dependency: transitive
    description:
      name: objective_c
      sha256: b7fb95a6d9a4f009edd63dc5ac69f07420b23a16161c6dd8660290b59c602e8e
      url: "https://pub.dev"
    source: hosted
    version: "9.5.0"
  package_config:
    dependency: transitive
    description:
      name: package_config
      sha256: ffcf4cf3d6c0b74ac43708d9f56625506e8a68aa935abe9d267a7330f320eb5d
      url: "https://pub.dev"
    source: hosted
    version: "3.0.0"
  passkeys_platform_interface:
    dependency: transitive
    description:
      name: passkeys_platform_interface
      sha256: "1a4a39920a737dfacfb7d4bb8f03bb0d95e9fdb6c3ff2010cfeb7fc5d087eeb1"
      url: "https://pub.dev"
    source: hosted
    version: "2.11.0"
  path:
    dependency: transitive
    description:
      name: path
      sha256: "75cca69d1490965be98c73ceaea117e8a04dd21217b37b292c9ddbec0d955bc5"
      url: "https://pub.dev"
    source: hosted
    version: "1.9.1"
  path_provider:
    dependency: transitive
    description:
      name: path_provider
      sha256: a7f4874f987173da295a61c181b8ee71dab59b332a486b391babf26a1b884825
      url: "https://pub.dev"
    source: hosted
    version: "2.1.6"
  path_provider_android:
    dependency: transitive
    description:
      name: path_provider_android
      sha256: "69cbd515a62b94d32a7944f086b2f82b4ac40a1d45bebfc00813a430ab2dabcd"
      url: "https://pub.dev"
    source: hosted
    version: "2.3.1"
  path_provider_foundation:
    dependency: transitive
    description:
      name: path_provider_foundation
      sha256: "2a376b7d6392d80cd3705782d2caa734ca4727776db0b6ec36ef3f1855197699"
      url: "https://pub.dev"
    source: hosted
    version: "2.6.0"
  path_provider_linux:
    dependency: transitive
    description:
      name: path_provider_linux
      sha256: "58c2005f147315b11e9b4a7bc889cd5203e250cba8e3f012dae259b4972b5c16"
      url: "https://pub.dev"
    source: hosted
    version: "2.2.2"
  path_provider_platform_interface:
    dependency: transitive
    description:
      name: path_provider_platform_interface
      sha256: "484838772624c3a4b94f1e44a3e19897fee738f2d5c4ce448443b0417f7c9dda"
      url: "https://pub.dev"
    source: hosted
    version: "2.1.3"
  path_provider_windows:
    dependency: transitive
    description:
      name: path_provider_windows
      sha256: bd6f00dbd873bfb70d0761682da2b3a2c2fccc2b9e84c495821639601d81afe7
      url: "https://pub.dev"
    source: hosted
    version: "2.3.0"
  platform:
    dependency: transitive
    description:
      name: platform
      sha256: a36d119c13416516a7b5913fbe8af8531e11633d784c550b2125f76c758524ec
      url: "https://pub.dev"
    source: hosted
    version: "3.2.0"
  plugin_platform_interface:
    dependency: transitive
    description:
      name: plugin_platform_interface
      sha256: "4820fbfdb9478b1ebae27888254d445073732dae3d6ea81f0b7e06d5dedc3f02"
      url: "https://pub.dev"
    source: hosted
    version: "2.1.8"
  pointycastle:
    dependency: transitive
    description:
      name: pointycastle
      sha256: "92aa3841d083cc4b0f4709b5c74fd6409a3e6ba833ffc7dc6a8fee096366acf5"
      url: "https://pub.dev"
    source: hosted
    version: "4.0.0"
  pool:
    dependency: transitive
    description:
      name: pool
      sha256: "4177f68c237ea2128d1bee66ac17b2ce05ba3dbaafcbdd54c5d40a39d0b6b11c"
      url: "https://pub.dev"
    source: hosted
    version: "1.5.3"
  postgrest:
    dependency: transitive
    description:
      name: postgrest
      sha256: b7f957273ba6a1c26cefa987ac524f4138e9ab7542fbb9e6abdfddacb9895a21
      url: "https://pub.dev"
    source: hosted
    version: "2.9.1"
  pub_semver:
    dependency: transitive
    description:
      name: pub_semver
      sha256: "261236774e8b1d69cfc6b9eabbc96c40f25e7a2d6b171f3385d4f65d5734fb24"
      url: "https://pub.dev"
    source: hosted
    version: "2.2.1"
  pubspec_parse:
    dependency: transitive
    description:
      name: pubspec_parse
      sha256: "9ac81c01ffd6a9cf9b2713288834fbaaf6aebde05ffdf02d380e68b8e06f27d8"
      url: "https://pub.dev"
    source: hosted
    version: "1.7.0"
  realtime_client:
    dependency: transitive
    description:
      name: realtime_client
      sha256: "2ef680d83ba2c0f76019d16194ca7067fa2458b2d4091b52323a9ca4a964fd40"
      url: "https://pub.dev"
    source: hosted
    version: "2.13.2"
  recase:
    dependency: transitive
    description:
      name: recase
      sha256: e4eb4ec2dcdee52dcf99cb4ceabaffc631d7424ee55e56f280bc039737f89213
      url: "https://pub.dev"
    source: hosted
    version: "4.1.0"
  record_use:
    dependency: transitive
    description:
      name: record_use
      sha256: "2551bd8eecfe95d14ae75f6021ad0248be5c27f138c2ec12fcb52b500b3ba1ed"
      url: "https://pub.dev"
    source: hosted
    version: "0.6.0"
  riverpod:
    dependency: transitive
    description:
      name: riverpod
      sha256: "24cbce92e87088cae0dd06caac3876c0b3abfd084901e7a93a3254d6daf4937d"
      url: "https://pub.dev"
    source: hosted
    version: "3.5.0"
  shared_preferences:
    dependency: "direct main"
    description:
      name: shared_preferences
      sha256: "1e85e0dccf5b4a016077fea7dfbb4a7cb39c759ac1596fcf60c06deadb7da91f"
      url: "https://pub.dev"
    source: hosted
    version: "2.5.6"
  shared_preferences_android:
    dependency: transitive
    description:
      name: shared_preferences_android
      sha256: "33b38b07d9ac7d16aff0426c61418752fd3e7a8c7dc8be786c875d6ce673b002"
      url: "https://pub.dev"
    source: hosted
    version: "2.5.4"
  shared_preferences_foundation:
    dependency: transitive
    description:
      name: shared_preferences_foundation
      sha256: "2ec3934efa51e46117f23031cc141b8fc878e8525b94ec1ea4f7f586cf1b47ea"
      url: "https://pub.dev"
    source: hosted
    version: "2.5.7"
  shared_preferences_linux:
    dependency: transitive
    description:
      name: shared_preferences_linux
      sha256: "580abfd40f415611503cae30adf626e6656dfb2f0cee8f465ece7b6defb40f2f"
      url: "https://pub.dev"
    source: hosted
    version: "2.4.1"
  shared_preferences_platform_interface:
    dependency: transitive
    description:
      name: shared_preferences_platform_interface
      sha256: "649dc798a33931919ea356c4305c2d1f81619ea6e92244070b520187b5140ef9"
      url: "https://pub.dev"
    source: hosted
    version: "2.4.2"
  shared_preferences_web:
    dependency: transitive
    description:
      name: shared_preferences_web
      sha256: c49bd060261c9a3f0ff445892695d6212ff603ef3115edbb448509d407600019
      url: "https://pub.dev"
    source: hosted
    version: "2.4.3"
  shared_preferences_windows:
    dependency: transitive
    description:
      name: shared_preferences_windows
      sha256: "94ef0f72b2d71bc3e700e025db3710911bd51a71cefb65cc609dd0d9a982e3c1"
      url: "https://pub.dev"
    source: hosted
    version: "2.4.1"
  shelf:
    dependency: transitive
    description:
      name: shelf
      sha256: e75e9cf311d7fd712048038cc17c25199c38536c20330d53e7db058b543d5a48
      url: "https://pub.dev"
    source: hosted
    version: "1.4.3"
  shelf_web_socket:
    dependency: transitive
    description:
      name: shelf_web_socket
      sha256: "3632775c8e90d6c9712f883e633716432a27758216dfb61bd86a8321c0580925"
      url: "https://pub.dev"
    source: hosted
    version: "3.0.0"
  sky_engine:
    dependency: transitive
    description: flutter
    source: sdk
    version: "0.0.0"
  source_gen:
    dependency: transitive
    description:
      name: source_gen
      sha256: "833ea7d15b5be79949d3d6c077da0267a0bd93c16897b36a771395a91e63086e"
      url: "https://pub.dev"
    source: hosted
    version: "4.3.1"
  source_span:
    dependency: transitive
    description:
      name: source_span
      sha256: "56a02f1f4cd1a2d96303c0144c93bd6d909eea6bee6bf5a0e0b685edbd4c47ab"
      url: "https://pub.dev"
    source: hosted
    version: "1.10.2"
  sqlcipher_flutter_libs:
    dependency: transitive
    description:
      name: sqlcipher_flutter_libs
      sha256: "38d62d659d2fb8739bf25a42c9a350d1fdd6c29a5a61f13a946778ec75d27929"
      url: "https://pub.dev"
    source: hosted
    version: "0.7.0+eol"
  sqlite3:
    dependency: transitive
    description:
      name: sqlite3
      sha256: "4c7fe79840389aaeaf05fd093f795b631b5a98e2bd28d54e555c100f4a9c7a1c"
      url: "https://pub.dev"
    source: hosted
    version: "3.5.2"
  sqlite3_flutter_libs:
    dependency: transitive
    description:
      name: sqlite3_flutter_libs
      sha256: "3ed7553eee7bb368f8950f58ba29f634e06e813c029aff6a0d60862b96de8454"
      url: "https://pub.dev"
    source: hosted
    version: "0.6.0+eol"
  sqlparser:
    dependency: transitive
    description:
      name: sqlparser
      sha256: "8121dae2c5de4a1e39153d95c55f7fd1816e32d1232fe270bc415a4a370d6e47"
      url: "https://pub.dev"
    source: hosted
    version: "0.45.1"
  stack_trace:
    dependency: transitive
    description:
      name: stack_trace
      sha256: "277654b3034d17ac6f9f1cb5595db011b1d5d41e8806866db28e0abaa101c490"
      url: "https://pub.dev"
    source: hosted
    version: "1.12.2"
  state_notifier:
    dependency: transitive
    description:
      name: state_notifier
      sha256: b8677376aa54f2d7c58280d5a007f9e8774f1968d1fb1c096adcb4792fba29bb
      url: "https://pub.dev"
    source: hosted
    version: "1.0.0"
  storage_client:
    dependency: transitive
    description:
      name: storage_client
      sha256: b951281b8e2b293460f0e6cc4e866f2546681390f0e37d24fbbd7b4a0deb27a3
      url: "https://pub.dev"
    source: hosted
    version: "2.8.1"
  stream_channel:
    dependency: transitive
    description:
      name: stream_channel
      sha256: "969e04c80b8bcdf826f8f16579c7b14d780458bd97f56d107d3950fdbeef059d"
      url: "https://pub.dev"
    source: hosted
    version: "2.1.4"
  stream_transform:
    dependency: transitive
    description:
      name: stream_transform
      sha256: a00e5f18bffc764f923e7dec1038527f7fe7a1791361a7117f0358193f13d53a
      url: "https://pub.dev"
    source: hosted
    version: "2.1.2"
  string_scanner:
    dependency: transitive
    description:
      name: string_scanner
      sha256: "921cd31725b72fe181906c6a94d987c78e3b98c2e205b397ea399d4054872b43"
      url: "https://pub.dev"
    source: hosted
    version: "1.4.1"
  supabase:
    dependency: transitive
    description:
      name: supabase
      sha256: "123fe08792b24e5e7c4b9a01145de8e95ebaa9183cd5f3c9d48dd2ff890f28a6"
      url: "https://pub.dev"
    source: hosted
    version: "2.16.5"
  supabase_common:
    dependency: transitive
    description:
      name: supabase_common
      sha256: a7961a44953cf8d9da049381fc3377516348255042fbb12b9d4f8540816f2fe9
      url: "https://pub.dev"
    source: hosted
    version: "0.1.2"
  supabase_flutter:
    dependency: "direct main"
    description:
      name: supabase_flutter
      sha256: "48bbde226e68bdb293020859a1bfa42d0f3bd2239992fba0ec4f9194cbb842e6"
      url: "https://pub.dev"
    source: hosted
    version: "2.18.3"
  term_glyph:
    dependency: transitive
    description:
      name: term_glyph
      sha256: "7f554798625ea768a7518313e58f83891c7f5024f88e46e7182a4558850a4b8e"
      url: "https://pub.dev"
    source: hosted
    version: "1.2.2"
  test_api:
    dependency: transitive
    description:
      name: test_api
      sha256: "2a122cbe059f8b610d3a5415f42e255b6c17b1f21eee1d960f31080237fb4f11"
      url: "https://pub.dev"
    source: hosted
    version: "0.7.12"
  typed_data:
    dependency: transitive
    description:
      name: typed_data
      sha256: f9049c039ebfeb4cf7a7104a675823cd72dba8297f264b6637062516699fa006
      url: "https://pub.dev"
    source: hosted
    version: "1.4.0"
  url_launcher:
    dependency: transitive
    description:
      name: url_launcher
      sha256: e8cc955c97e06df9879140a1fe301f3d493f01b7c62dec7f46834be31d7e9fda
      url: "https://pub.dev"
    source: hosted
    version: "6.3.3"
  url_launcher_android:
    dependency: transitive
    description:
      name: url_launcher_android
      sha256: "611e87fb320b70d1dd721dc46af89c98aceccea9b31fde49e084591414e0c610"
      url: "https://pub.dev"
    source: hosted
    version: "6.3.33"
  url_launcher_ios:
    dependency: transitive
    description:
      name: url_launcher_ios
      sha256: "8faa1aab294f1ab4040b43660c887b0418d5fa4f0cffef76a484e6aa1092eb4a"
      url: "https://pub.dev"
    source: hosted
    version: "6.4.2"
  url_launcher_linux:
    dependency: transitive
    description:
      name: url_launcher_linux
      sha256: "10f86fef4c2c43563fa6c211ff9cf757adf4d3ab762c56bd430664a947d70cd0"
      url: "https://pub.dev"
    source: hosted
    version: "3.2.3"
  url_launcher_macos:
    dependency: transitive
    description:
      name: url_launcher_macos
      sha256: "5e835a3b869c2d70325349c81c5a45c28e20791265b67b2669da6b08c5cd5201"
      url: "https://pub.dev"
    source: hosted
    version: "3.2.6"
  url_launcher_platform_interface:
    dependency: transitive
    description:
      name: url_launcher_platform_interface
      sha256: "552f8a1e663569be95a8190206a38187b531910283c3e982193e4f2733f01029"
      url: "https://pub.dev"
    source: hosted
    version: "2.3.2"
  url_launcher_web:
    dependency: transitive
    description:
      name: url_launcher_web
      sha256: "85c81589622fbc87c1c683aaea164d3604a7777495a79d91e39ffcdec39ddb34"
      url: "https://pub.dev"
    source: hosted
    version: "2.4.3"
  url_launcher_windows:
    dependency: transitive
    description:
      name: url_launcher_windows
      sha256: "6c5ad3f22cd4c38e089b81963b3cd7bb83b111b2df5dce008bb066162f42e429"
      url: "https://pub.dev"
    source: hosted
    version: "3.1.6"
  uuid:
    dependency: transitive
    description:
      name: uuid
      sha256: "9b129329f58692f6e6578329498a8fe9fbe98f090beb764ffbb8ee2eadd01dcd"
      url: "https://pub.dev"
    source: hosted
    version: "4.6.0"
  vector_math:
    dependency: transitive
    description:
      name: vector_math
      sha256: "1d774bbdf6b72a0b12122fc1560c9c2d2a67db5a4a4cc2bd8a5c990ab20e3188"
      url: "https://pub.dev"
    source: hosted
    version: "2.4.0"
  vm_service:
    dependency: transitive
    description:
      name: vm_service
      sha256: "89b11d62e1040ee681af3b4f1c97a803ecbf010c6e8b9c5896ee5b08c3bf7b78"
      url: "https://pub.dev"
    source: hosted
    version: "15.4.0"
  watcher:
    dependency: transitive
    description:
      name: watcher
      sha256: "1398c9f081a753f9226febe8900fce8f7d0a67163334e1c94a2438339d79d635"
      url: "https://pub.dev"
    source: hosted
    version: "1.2.1"
  web:
    dependency: transitive
    description:
      name: web
      sha256: e119e82ac4795c7925103b7cf3768191f33941b99e7ccffbd6c645201d9f606b
      url: "https://pub.dev"
    source: hosted
    version: "1.1.2"
  web_socket:
    dependency: transitive
    description:
      name: web_socket
      sha256: "34d64019aa8e36bf9842ac014bb5d2f5586ca73df5e4d9bf5c936975cae6982c"
      url: "https://pub.dev"
    source: hosted
    version: "1.0.1"
  web_socket_channel:
    dependency: transitive
    description:
      name: web_socket_channel
      sha256: d645757fb0f4773d602444000a8131ff5d48c9e47adfe9772652dd1a4f2d45c8
      url: "https://pub.dev"
    source: hosted
    version: "3.0.3"
  xdg_directories:
    dependency: transitive
    description:
      name: xdg_directories
      sha256: "7a3f37b05d989967cdddcbb571f1ea834867ae2faa29725fd085180e0883aa15"
      url: "https://pub.dev"
    source: hosted
    version: "1.1.0"
  yaml:
    dependency: transitive
    description:
      name: yaml
      sha256: f67cdd8e07d3c6329146aaef1ba043542b3134c12489f553ca9a7435d1068aea
      url: "https://pub.dev"
    source: hosted
    version: "3.1.4"
  yaml_edit:
    dependency: transitive
    description:
      name: yaml_edit
      sha256: "07c9e63ba42519745182b88ca12264a7ba2484d8239958778dfe4d44fe760488"
      url: "https://pub.dev"
    source: hosted
    version: "2.2.4"
  yet_another_json_isolate:
    dependency: transitive
    description:
      name: yet_another_json_isolate
      sha256: eaa26beb5990b25a49d942374fd5a0c5aa67a837e03b14b4c26134aaa1ed01a9
      url: "https://pub.dev"
    source: hosted
    version: "2.1.1"
sdks:
  dart: ">=3.13.5 <4.0.0"
  flutter: ">=3.47.0"
```

## pubspec.yaml

```yaml
name: myapp
description: A language-learning app, built phase by phase.
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: ^3.13.5

dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^3.5.0
  go_router: ^18.1.3
  drift: ^2.35.3
  drift_flutter: ^0.3.1
  shared_preferences: ^2.5.6
  dio: ^5.11.1
  intl: ^0.20.3
  flutter_dotenv: ^6.0.1
  supabase_flutter: ^2.18.3

dev_dependencies:
  flutter_test:
    sdk: flutter
  drift_dev: ^2.35.2
  build_runner: ^2.17.1
  flutter_lints: ^6.0.0
  mocktail: ^1.0.5

flutter:
  uses-material-design: true
  assets:
    - assets/courses/japanese_basics.json
```

## test/widget_test.dart

```dart
import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/app/app.dart';
import 'package:myapp/features/auth/data/auth_repository.dart';
import 'package:myapp/features/auth/domain/auth_models.dart';
import 'package:myapp/features/sync/presentation/sync_providers.dart';
import 'package:myapp/core/config/app_config.dart';
import 'package:myapp/core/config/supabase_config.dart';
import 'package:myapp/core/database/app_database.dart';
import 'package:myapp/core/utils/clock.dart';
import 'package:myapp/features/flashcards/data/review_repository.dart';
import 'package:myapp/core/router/app_router.dart';
import 'package:myapp/features/home/data/home_providers.dart';
import 'package:myapp/features/home/domain/learning_path.dart';
import 'package:myapp/features/lessons/domain/course.dart';
import 'package:myapp/features/lessons/data/lesson_completion_repository.dart';
import 'package:myapp/features/onboarding/data/course_catalog.dart';
import 'package:myapp/features/onboarding/data/onboarding_repository.dart';
import 'package:myapp/features/onboarding/domain/onboarding_settings.dart';
import 'package:myapp/features/onboarding/presentation/onboarding_controller.dart';
import 'package:myapp/shared/widgets/lesson_path_node.dart';

import 'support/phase3_fixtures.dart';

class AppHarness {
  AppHarness({
    MemoryOnboardingRepository? repository,
    OnboardingSettings? settings,
    bool statsError = false,
    Course? course,
    LessonCompletionRepository? completionRepository,
    ReviewRepository? reviewRepository,
    DateTime Function()? clock,
    AuthRepository? authRepository,
    bool useRealAuth = false,
  }) {
    this.course = course ?? sampleCourse();
    this.repository = repository ?? MemoryOnboardingRepository(saved: settings);
    database = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        onboardingRepositoryProvider.overrideWithValue(this.repository),
        appDatabaseProvider.overrideWithValue(database),
        syncServiceProvider.overrideWithValue(null),
        accountReadyProvider.overrideWith((ref) async {}),
        if (useRealAuth)
          supabaseConfigProvider.overrideWithValue(
            const SupabaseConfig(url: '', publishableKey: ''),
          ),
        if (authRepository != null)
          authRepositoryProvider.overrideWith((ref) async => authRepository)
        else if (!useRealAuth)
          authStateProvider.overrideWith(
            (ref) => Stream.value(
              const AuthIdentity(id: 'test-account', email: 'test@example.com'),
            ),
          ),
        if (clock != null) clockProvider.overrideWithValue(clock),
        if (reviewRepository != null)
          reviewRepositoryProvider.overrideWithValue(reviewRepository),
        appConfigProvider.overrideWithValue(
          const AppConfig(appName: 'Test App'),
        ),
        courseCatalogProvider.overrideWith((ref) async {
          if (catalogFails) throw StateError('Catalog failure');
          return catalogGate?.future ?? [this.course];
        }),
        if (completionRepository != null)
          lessonCompletionRepositoryProvider.overrideWithValue(
            completionRepository,
          ),
        if (statsError)
          userStatsProvider.overrideWith(
            (ref) => Stream.error(StateError('Stats error')),
          ),
      ],
    );
  }
  late final Course course;
  late final MemoryOnboardingRepository repository;
  late final AppDatabase database;
  late final ProviderContainer container;
  bool catalogFails = false;
  bool closed = false;
  Completer<List<Course>>? catalogGate;

  Future<void> close() async {
    if (closed) return;
    closed = true;
    container.dispose();
    await database.close();
  }
}

Future<void> mount(
  WidgetTester tester,
  AppHarness harness, {
  bool settle = true,
}) async {
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(harness.close);
  });
  await tester.runAsync(() => harness.database.customSelect('SELECT 1').get());
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: harness.container,
      child: const LanguageApp(),
    ),
  );
  if (settle) await tester.pumpAndSettle();
}

Future<void> tapText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> reachGoal(WidgetTester tester) async {
  await tapText(tester, 'Get Started');
  await tapText(tester, 'Japanese');
  await tapText(tester, 'Continue');
}

void main() {
  testWidgets('system Back preserves the onboarding draft', (tester) async {
    final harness = AppHarness();
    await mount(tester, harness);
    await reachGoal(tester);
    await tapText(tester, '5 minutes');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(
      harness.container.read(appRouterProvider).state.uri.path,
      '/languages',
    );
    expect(
      harness.container.read(onboardingFlowProvider).courseId,
      'ja_basics_en',
    );
    await tapText(tester, 'Continue');
    expect(harness.container.read(onboardingFlowProvider).goalMinutes, 5);
  });

  testWidgets('three steps persist choices; later launch skips onboarding', (
    tester,
  ) async {
    final harness = AppHarness();
    await mount(tester, harness);
    expect(find.text('Test App'), findsOneWidget);
    expect(
      harness.container.read(appRouterProvider).state.uri.path,
      '/welcome',
    );
    await reachGoal(tester);
    await tapText(tester, '15 minutes');
    await tapText(tester, 'Start learning');
    expect(harness.repository.saved!.courseId, 'ja_basics_en');
    expect(harness.repository.saved!.goalMinutes, 15);
    expect(find.text('Your daily goal: 15 minutes'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(harness.close);
    final second = AppHarness(repository: harness.repository);
    await mount(tester, second);
    final router = second.container.read(appRouterProvider);
    expect(router.state.uri.path, '/home');
    router.go('/welcome');
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/home');
  });

  testWidgets('direct links cannot bypass onboarding or language selection', (
    tester,
  ) async {
    final harness = AppHarness();
    await mount(tester, harness);
    final router = harness.container.read(appRouterProvider);
    router.go('/lesson/ja_greetings');
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/welcome');
    router.go('/daily-goal');
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/languages');
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue'))
          .onPressed,
      isNull,
    );
  });

  testWidgets('saving failures preserve choices and allow retry', (
    tester,
  ) async {
    final harness = AppHarness();
    harness.repository.failSave = true;
    await mount(tester, harness);
    await reachGoal(tester);
    await tapText(tester, '5 minutes');
    await tapText(tester, 'Start learning');
    expect(
      find.text('Your choices could not be saved. Please try again.'),
      findsOneWidget,
    );
    expect(harness.repository.saved, isNull);
    expect(harness.container.read(onboardingFlowProvider).goalMinutes, 5);
    harness.repository.failSave = false;
    await tapText(tester, 'Start learning');
    expect(harness.repository.saved!.goalMinutes, 5);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets(
    'in-flight save disables repeat submissions without redirecting',
    (tester) async {
      final harness = AppHarness();
      harness.repository.saveGate = Completer<void>();
      await mount(tester, harness);
      await reachGoal(tester);
      await tapText(tester, 'Start learning');
      expect(find.text('Saving…'), findsOneWidget);
      expect(
        harness.container.read(appRouterProvider).state.uri.path,
        '/daily-goal',
      );
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Saving…'))
            .onPressed,
        isNull,
      );
      await harness.container.read(onboardingFlowProvider.notifier).finish();
      expect(harness.repository.saveCalls, 1);
      harness.repository.saveGate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
    },
  );

  testWidgets('preferences loading and errors have a retry screen', (
    tester,
  ) async {
    final harness = AppHarness();
    harness.repository.loadGate = Completer<void>();
    await mount(tester, harness, settle: false);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Get Started'), findsNothing);
    harness.repository.failLoad = true;
    harness.repository.loadGate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Your preferences could not be loaded.'), findsOneWidget);
    harness.repository.failLoad = false;
    await tapText(tester, 'Try again');
    expect(find.text('Get Started'), findsOneWidget);
  });

  testWidgets('data-driven language catalog errors can be retried', (
    tester,
  ) async {
    final harness = AppHarness()..catalogFails = true;
    await mount(tester, harness);
    await tapText(tester, 'Get Started');
    expect(find.text('Languages could not be loaded.'), findsOneWidget);
    harness.catalogFails = false;
    await tapText(tester, 'Try again');
    expect(find.text('Japanese'), findsOneWidget);
  });

  testWidgets('home loading and catalog errors can be retried', (tester) async {
    final harness = AppHarness(settings: completedSettings());
    harness.catalogGate = Completer<List<Course>>();
    await mount(tester, harness, settle: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    harness.catalogGate!.completeError(StateError('Catalog failure'));
    await tester.pumpAndSettle();
    expect(find.text('Your lessons could not be loaded.'), findsOneWidget);
    harness.catalogGate = null;
    await tapText(tester, 'Try again');
    expect(find.text('Japanese Basics'), findsOneWidget);
  });

  testWidgets('stats errors do not prevent learning path from loading', (
    tester,
  ) async {
    final harness = AppHarness(settings: completedSettings(), statsError: true);
    await mount(tester, harness);
    expect(find.text('Stats could not be loaded.'), findsOneWidget);
    expect(find.text('Retry stats'), findsOneWidget);
    expect(find.text('Japanese Basics'), findsOneWidget);
  });

  testWidgets('DB updates unlock next lesson, show stars and refresh stats', (
    tester,
  ) async {
    final harness = AppHarness(settings: completedSettings());
    await mount(tester, harness);
    expect(find.text('0 XP'), findsOneWidget);
    final secondFinder = find.byKey(const ValueKey('lesson-node-ja_people'));
    expect(
      tester.widget<LessonPathNode>(secondFinder).entry.availability,
      LessonAvailability.locked,
    );
    await harness.database
        .into(harness.database.lessonProgress)
        .insert(
          LessonProgressCompanion.insert(
            lessonId: 'ja_greetings',
            completed: const Value(true),
            bestScore: const Value(95),
          ),
        );
    await harness.database
        .update(harness.database.userStats)
        .write(const UserStatsCompanion(xp: Value(120), streak: Value(3)));
    await tester.pumpAndSettle();
    final first = tester.widget<LessonPathNode>(
      find.byKey(const ValueKey('lesson-node-ja_greetings')),
    );
    expect(first.entry.availability, LessonAvailability.completed);
    expect(first.entry.stars, 3);
    expect(
      tester.widget<LessonPathNode>(secondFinder).entry.availability,
      LessonAvailability.available,
    );
    expect(find.text('120 XP'), findsOneWidget);
    expect(find.text('3 days streak'), findsOneWidget);
    final firstButton = find.descendant(
      of: find.byKey(const ValueKey('lesson-node-ja_greetings')),
      matching: find.byType(FilledButton),
    );
    await tester.ensureVisible(firstButton);
    await tester.tap(firstButton);
    await tester.pumpAndSettle();
    expect(find.text('Check'), findsOneWidget);
    await tester.tap(find.byTooltip('Close lesson'));
    await tester.pumpAndSettle();
    await tapText(tester, 'Leave');
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('tabs, locked and unknown lesson routes remain usable', (
    tester,
  ) async {
    final harness = AppHarness(settings: completedSettings());
    await mount(tester, harness);
    await tapText(tester, 'Review');
    expect(find.text('Your review deck is ready to grow.'), findsOneWidget);
    await tester.tap(find.byType(NavigationDestination).at(2));
    await tester.pumpAndSettle();
    expect(find.text('Your account'), findsOneWidget);
    final router = harness.container.read(appRouterProvider);
    router.go('/lesson/ja_people');
    await tester.pumpAndSettle();
    expect(find.text('Lesson locked'), findsWidgets);
    router.go('/lesson/missing');
    await tester.pumpAndSettle();
    expect(find.text('Lesson not found'), findsWidgets);
    router.go('/missing');
    await tester.pumpAndSettle();
    await tapText(tester, 'Go to Learn');
    expect(find.text('Japanese Basics'), findsOneWidget);
  });

  for (final brightness in Brightness.values) {
    testWidgets('320px phone with 200% text in ${brightness.name}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final harness = AppHarness();
      await mount(tester, harness);
      final router = harness.container.read(appRouterProvider);
      await reachGoal(tester);
      await tapText(tester, 'Start learning');
      for (final route in [
        '/home',
        '/review',
        '/profile',
        '/lesson/ja_greetings',
      ]) {
        router.go(route);
        await tester.pumpAndSettle();
        expect(
          Theme.of(tester.element(find.byType(Scaffold).last)).brightness,
          brightness,
        );
        expect(tester.takeException(), isNull, reason: route);
      }
      router.go('/home');
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Daily life'),
        300,
        scrollable: find.descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        ),
      );
      expect(find.text('Daily life'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }
}
```

## windows/flutter/generated_plugin_registrant.cc

```cpp
//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <app_links/app_links_plugin_c_api.h>
#include <url_launcher_windows/url_launcher_windows.h>

void RegisterPlugins(flutter::PluginRegistry* registry) {
  AppLinksPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("AppLinksPluginCApi"));
  UrlLauncherWindowsRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("UrlLauncherWindows"));
}
```

## windows/flutter/generated_plugins.cmake

```cmake
#
# Generated file, do not edit.
#

list(APPEND FLUTTER_PLUGIN_LIST
  app_links
  url_launcher_windows
)

list(APPEND FLUTTER_FFI_PLUGIN_LIST
  jni
)

set(PLUGIN_BUNDLED_LIBRARIES)

foreach(plugin ${FLUTTER_PLUGIN_LIST})
  add_subdirectory(flutter/ephemeral/.plugin_symlinks/${plugin}/windows plugins/${plugin})
  target_link_libraries(${BINARY_NAME} PRIVATE ${plugin}_plugin)
  list(APPEND PLUGIN_BUNDLED_LIBRARIES $<TARGET_FILE:${plugin}_plugin>)
  list(APPEND PLUGIN_BUNDLED_LIBRARIES ${${plugin}_bundled_libraries})
endforeach(plugin)

foreach(ffi_plugin ${FLUTTER_FFI_PLUGIN_LIST})
  add_subdirectory(flutter/ephemeral/.plugin_symlinks/${ffi_plugin}/windows plugins/${ffi_plugin})
  list(APPEND PLUGIN_BUNDLED_LIBRARIES ${${ffi_plugin}_bundled_libraries})
endforeach(ffi_plugin)
```

