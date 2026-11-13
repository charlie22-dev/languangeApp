# Browser local-progress fix

The message **Your local progress could not be opened** happened after login
because the production database constructor had no browser configuration.
Drift throws an error on the web unless `DriftWebOptions` is provided.

The constructor now points to bundled SQLite WebAssembly and a Drift worker.
Both files come from the official Drift 2.35.3 release, matching pubspec.lock;
their release SHA-256 checksums were verified. The database schema, filenames,
saved progress and account ownership rules stay the same.

## Run in Edge

Stop the previous Flutter run completely, then run:

```powershell
cd C:\Langunge_flutter\myapp
flutter run -d edge --web-port=7357 --dart-define-from-file=config.local.json
```

Use that same port on later runs so browser storage and your session stay on
the same origin. Sign in with your existing app account. There is no need to
register again, clear storage, reinstall, or run another Supabase SQL script.

If your existing run already uses a fixed port, keep that port instead of 7357
to retain its existing local browser data. Hot reload is insufficient for this
change; stop and restart the run, then refresh its browser page.

## Verification

- Real headless Edge smoke check: production database creation, legacy progress
  import, account isolation, saving words/lessons, close/reopen persistence.
- Repeated the smoke check after a full browser-page refresh: passed.
- Database migration, account isolation and synchronization unit tests: 19 passed.
- `flutter analyze`: no issues.
- `flutter build web --no-web-resources-cdn`: production app build passed.

Run the repeatable browser check on its **own origin**, separate from your app:

```powershell
flutter run -d edge -t tool/browser_database_smoke.dart --web-port=7358
```

This uses fixture accounts and writes test records into that origin's databases.
The page and console report whether the checks pass. Refresh to test persistence
across a page reload. It does not contact Supabase or need an account password.

## Changed files for this fix

- `lib/core/database/app_database.dart`: configures the browser database runtime.
- `web/drift_worker.js`: official, unmodified worker.
- `web/sqlite3.wasm`: official, unmodified SQLite WebAssembly module.
- `web/DATABASE_ASSETS.md`: asset sources, checksums and license notices.
- `tool/browser_database_smoke.dart`: reproducible real-browser database check.
- `README.md` and `SUPABASE_SETUP.md`: browser troubleshooting and run instructions.
- `BROWSER_DATABASE_FIX.md`: this explanation and verification guide.

For web hosting, serve `sqlite3.wasm` as `application/wasm` and keep both runtime
files available alongside index.html. Flutter's development server already
does this. No special cross-origin isolation headers are necessary for the
tested persistent browser-storage fallback. See the
[official Drift web setup](https://drift.simonbinder.eu/platforms/web/).
