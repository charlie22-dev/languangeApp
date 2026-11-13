# Sign-in configuration fix

Plain `flutter run` previously omitted the compile-time Supabase URL/key, so
the auth provider failed before it could contact Supabase. The generic error
hid that configuration problem.

The app now optionally loads the ignored `assets/local/client.env`. Generate
it from `config.local.json`; explicit Dart defines still override the local
URL/key pair together. Both local files stay outside Git. Only public client
settings are copied, and the helper rejects secret/service-role keys.
Missing configuration and initialization failures now have distinct messages.

## Run

Stop the previous Flutter run completely, then:

```powershell
cd C:\Langunge_flutter\myapp
python tool/prepare_local_config.py
flutter run
```

Choose your Android emulator if Flutter prompts. Alternatively:

```powershell
flutter run -d emulator-5554 --dart-define-from-file=config.local.json
```

Regenerate the local asset after editing config.local.json, then stop and
rebuild. Hot reload cannot add a missing asset or change Dart defines.
The included VS Code launch profile passes the config flag automatically.

Select **Create an account**, enter your own email and an eight-character-or-longer
password, repeat the password and register. Follow the confirmation email if
required, then sign in. See [dashboard setup](SUPABASE_SETUP.md) for email
callbacks and Google OAuth. Google is currently disabled in your project.

## Verification

- `flutter analyze`: no issues.
- `flutter test`: all 157 tests passed.
- `flutter build apk --debug --target-platform android-x64`: passed **without**
  Dart defines, verifying the same configuration path as plain launches.
- Installed that APK on the Android emulator: Login and Register open without
  the configuration error; registration input validation works.
- Live, read-only auth settings: email enabled, signups enabled, Google disabled.
- Local config helper rejects server keys and omits unrelated config values.

A live account and email delivery were not tested; use your own address for
that check. Authenticated cloud synchronization still depends on the dashboard
SQL and settings described in the setup guide.

## Files changed

- `.gitignore`: ignores the generated local configuration asset.
- `pubspec.yaml`: registers the local asset folder.
- `assets/local/README.md`: documents the optional local asset.
- `tool/prepare_local_config.py`: generates public-only local configuration.
- `.vscode/launch.json`: configured local launch profile.
- `lib/main.dart`: loads the optional local settings before auth initialization.
- `lib/core/config/supabase_config.dart`: configuration fallback and typed failure.
- `lib/core/config/app_config.dart`: local app-name/language settings fallback.
- `lib/features/auth/data/auth_repository.dart`: distinguishes config/startup failures.
- `lib/features/auth/domain/auth_models.dart`: actionable auth error messages.
- `lib/features/auth/presentation/auth_controller.dart`: clearer startup failure.
- `lib/features/auth/presentation/auth_screens.dart`: displays the specific failure.
- `lib/l10n/app_en.arb`: new translatable error messages.
- `lib/core/localization/ui_messages.g.dart`: regenerated message catalog.
- `test/supabase_config_test.dart`: fallback, override and secret rejection checks.
- `test/auth_widget_test.dart`: missing-config login and registration checks.
- `test/auth_validation_test.dart`: email provider/delivery error mappings.
- `test/lingoblob_ui_test.dart`: fixes an existing analyzer brace warning.
- `README.md` and `SUPABASE_SETUP.md`: corrected launch instructions.
- `AUTH_CONFIGURATION_FIX.md`: this report.

The ignored `assets/local/client.env` was generated locally. No account data,
database schema, lesson logic, or synchronization logic was changed.
