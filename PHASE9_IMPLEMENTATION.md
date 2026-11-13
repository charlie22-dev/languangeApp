# Phase 9: AI conversation partner

The existing Chat tab now uses a Supabase Edge Function for beginner Japanese
practice. Assumption: the installed Japanese course remains the target language;
Groq is the server-side LLM provider. Existing lesson, audio, review, auth,
streak and route behavior is preserved.

The implementation is local. The SQL migration, server secret and function
deployment below are required before real tutor replies work. No paid API call
or live deployment was performed during implementation.

## 1. Supabase setup

1. Open your existing Supabase project. In **SQL Editor**, run migrations in
   this order if they have not already been applied:
   - `supabase/migrations/202611120001_phase6c.sql`
   - `supabase/migrations/202611130001_phase7.sql`
   - **New:** `supabase/migrations/202611130002_phase9.sql`
2. Open **Edge Functions → Secrets** and add `GROQ_API_KEY` using your Groq
   project API key. Your Groq project must have access to the configured model
   and sufficient API quota. Store this key only here. Do not add it to Flutter,
   `config.local.json`, assets, Git, screenshots or chat messages.
3. Optional server secrets:

   | Secret | Default | Purpose |
   | --- | --- | --- |
   | `GROQ_MODEL` | `openai/gpt-oss-20b` | Groq model supporting strict JSON schema and low reasoning effort |
   | `TUTOR_LANGUAGE` | `Japanese` | Tutor language; authored fallback redirects support Japanese and Spanish |
   | `ALLOWED_ORIGINS` | `*` | Comma-separated allowed browser origins; use your fixed development origins and deployed web origin |

   For browser development, an example allowlist is
   `http://localhost:7357,http://127.0.0.1:7357`.
   Native app requests have no browser Origin header.
4. Deploy from a terminal in this project:

   ```powershell
   cd C:\Langunge_flutter\myapp
   npx supabase login
   npx supabase link --project-ref YOUR_PROJECT_REF
   npx supabase functions deploy chat
   ```

   Copy your project reference from the Supabase dashboard. CLI login/link are
   administrative setup on your computer. They are separate from app login.
   `supabase/config.toml` configures this function's gateway `verify_jwt=false`:
   **every POST still verifies the bearer token through Supabase Auth's
   `/auth/v1/user` endpoint before quota or LLM access**. This supports current
   asymmetric JWT signing keys. Do not remove that handler authentication check.
5. Supabase supplies `SUPABASE_URL` and the public project key to the function.
   The handler supports the anon key and publishable-key environment forms.
   It never uses a service-role key. Database operations use the caller's verified
   JWT, so Row Level Security applies.

`supabase/functions/.env.example` contains placeholders for local function
development. Real `.env` files are ignored. The existing ignored Flutter public
Supabase config stays unchanged; a publishable Supabase key cannot replace an
LLM provider key.

Reference documentation: [Supabase function secrets](https://supabase.com/docs/guides/functions/secrets),
[Supabase JWT verification](https://supabase.com/docs/guides/functions/auth-legacy-jwt),
[Groq structured outputs](https://console.groq.com/docs/structured-outputs),
[the Chat Completions API](https://console.groq.com/docs/api-reference), and
[supported models](https://console.groq.com/docs/models).

The default `openai/gpt-oss-20b` is a model hosted **by Groq**; the `openai/`
part is its model identifier. Use a Groq API key, not an OpenAI API key.
The same stable model performs separate strict-JSON safety classifications before
and after the tutor call. A normal turn uses three Groq completions, so Groq's
account-level limits may be reached before the app's per-user limits. A provider
429 is shown as a retryable quota error. No second provider or safety-model key
is needed.

## 2. Endpoint contract

`POST /functions/v1/chat` is Supabase's deployed URL for the requested `/chat`
endpoint. Flutter calls it with `client.functions.invoke('chat', ...)` and the
current user's access token.

```json
{
  "messages": [{"role": "user", "content": "こんにちは"}],
  "level": "beginner",
  "scenario": "introductions"
}
```

Scenarios: `ordering_food`, `introductions`, `directions`, `shopping`.

```json
{
  "reply": "こんにちは。お名前は何ですか。",
  "translation": "Hello. What is your name?",
  "corrections": [],
  "newWords": [
    {
      "text": "名前",
      "translation": "name",
      "example": "お名前は何ですか。",
      "exampleTranslation": "What is your name?"
    }
  ]
}
```

Each correction has `original`, `corrected`, `explanation`. Suggested words
include example metadata so they can be reviewed as complete flashcards.
`translation` is an additional response field, hidden until the learner taps
the tutor message or Translate. Translations need no second network call.

Limits:

- Authenticated user only; **10 requests per minute and 100 per UTC day**.
  The private Postgres counter uses a row lock for concurrent requests. The
  authenticated user cannot read, edit, delete or reset counters directly.
  Valid requests reserve a slot before contacting the model; retries consume a
  slot too. There is no automatic retry that could silently incur API costs.
- Maximum 500 Unicode code points per message, 20 context messages, 6,000 total
  context code points, and 32 KiB request body. Only user/assistant roles accepted.
  The final message must be from the user.
- Server deadline 25 seconds; Flutter invocation timeout 35 seconds.
- Replies are schema-validated, bounded to 1–3 sentences, with at most 3
  corrections and 3 suggested words. A correction must quote part of the last
  user message. The provider receives a bounded completion-token budget (3,072 for the tutor,
  1,024 for each safety classification).
- Stable errors: 401 sign-in required, 400/413 invalid or oversized message,
  429 quota reached with `Retry-After`, 504 timeout, and 502/503 malformed,
  unavailable or unconfigured service. Private provider errors are not returned.

The system prompt treats messages as untrusted practice, stays in the selected
scenario, gently corrects the last learner message, and adds parenthesized English
hints inside the Japanese reply only when explicitly requested. Input and output
moderation plus an on-topic check use authored, scenario-specific redirects on
rejection. Provider refusal uses a safe redirect; malformed output produces a retryable error.
These are practical model guardrails; model-based safety and topic detection are
not absolute guarantees.

## 3. Flutter behavior

Riverpod's `AsyncNotifier` holds asynchronous conversation state (similar to a
React state store with loading/error states). Widgets display that state; HTTP,
database and word-saving logic live outside the widgets.

- Four scenario chips switch between locally stored threads. Only the current
  scenario's messages enter the tutor context.
- Messages are written to Drift before a request. A failed/pending learner
  message survives app restart and offers Retry or Discard. Retry reuses its
  existing row; completing a turn twice cannot duplicate the tutor response.
- A typing indicator follows the real request. Network, quota, timeout, auth and
  configuration failures have localized, actionable messages.
- Corrections expand underneath the learner message they correct. Tutor
  translation remains hidden until tapped.
- The mic reuses Phase 8 speech-to-text with a permission explanation. It fills
  the draft for review and never sends automatically. Recording stops when
  switching tabs or when the app leaves the foreground.
- Save word creates due `WordProgress` plus vocabulary metadata, and the Review
  tab includes it in existing SM-2 sessions. Saving again preserves repetitions,
  ease factor and due date. Known course words reuse their existing IDs.
- Exactly the **last 20 messages globally per account** remain locally, including
  pending messages. Scenario filtering may show fewer than 20. History does not
  sync to the cloud; saved word metadata and scheduling progress do.
- Offline learners can read history, reveal cached translations, save received
  word suggestions and review cards. Generating a new tutor reply needs internet.

Local schema version 5 adds `chat_entries` and `saved_vocabulary`. The additive
migration preserves prior progress. Each account keeps its existing isolated
database. `saved_words` syncs with ownership RLS, primary key `(user_id, word_id)`,
the existing timestamp/revision cursor and last-write-wins rule. Reset progress
tombstones vocabulary and WordProgress so stale remote words cannot resurrect it.

## 4. Run and test

Verification completed during implementation:

- All 239 Flutter regression and HTTP contract tests pass; `flutter analyze` is clean.
- 12 Edge Function handler tests pass with mocked Groq responses, including
  authentication, validation, quotas, provider rate limits, timeouts, moderation
  failure and correction ownership.
- 8 Postgres/PGlite checks pass, including cross-user RLS, private quota counters,
  per-user limits, incremental vocabulary sync and stale-write rejection.
- Deno type checking passes for the deployed function entry point.
- Android debug APK and web release builds pass.
- Edge's real SQLite smoke test passes on initial open and page reload,
  including persisted chat/vocabulary and isolation between accounts.

Live Groq responses and physical microphone permission behavior require manual
verification after dashboard setup. Android builds currently emit existing
Flutter TTS/Kotlin compatibility and Android SDK-tool warnings; neither prevented
the debug build. The web build emits an existing unused Cupertino font warning.

```powershell
cd C:\Langunge_flutter\myapp
flutter pub get
flutter run -d edge --web-port=7357 --dart-define-from-file=config.local.json
```

For Android, start the emulator in Android Studio or with
`flutter emulators --launch Medium_Phone_API_37.0`, then:

```powershell
flutter run -d emulator-5554 --dart-define-from-file=config.local.json
```

Sign in, open Chat, choose a scenario and send a short practice message. Expand a
correction, tap Translate, save a suggested word and open Review to study it.
Switch scenarios and restart the app to check history. Disable networking and
send a message; reconnect and Retry, checking that it appears only once. Test
microphone consent, denied permission and dictation on a real device/browser.

Automated checks:

```powershell
flutter analyze
flutter test
node --experimental-strip-types --test supabase/tests/chat_handler.test.ts
node supabase/tests/phase9_security.mjs
npx --yes deno check supabase/functions/chat/index.ts
```

The SQL test needs the local PGlite package; install it into the ignored tools
folder if it is absent:

```powershell
npm install --prefix .dart_tool/sqlcheck --no-save @electric-sql/pglite
```

Use a separate browser test origin to exercise real SQLite persistence, account
isolation, chat history and saved vocabulary without touching your normal app:

```powershell
flutter run -d edge -t tool/browser_database_smoke.dart --web-port=7358
```

UI changes:

| Before | After | Why |
| --- | --- | --- |
| Placeholder Chat | Real scenario threads, input and request state | Connect the existing tab to the authenticated tutor |
| Static conversation design | User corrections, hidden translations, suggested vocabulary | Support beginner practice using returned data |
| No chat dictation | Consent, transcript draft and stop controls | Reuse Phase 8 speech without automatic sending |
| Course-only review vocabulary | Saved tutor words join the same review flow | Keep one SM-2 implementation and offline source of truth |

The theme, route paths and small-screen behavior remain consistent with
LingoBlob. Chat is covered at 360 dp with 200% text in light and dark themes,
including a visible software keyboard.

## 5. Files created for Phase 9

- `supabase/config.toml`
- `supabase/functions/.env.example`
- `supabase/functions/chat/index.ts`
- `supabase/functions/chat/handler.ts`
- `supabase/migrations/202611130002_phase9.sql`
- `supabase/tests/chat_handler.test.ts`
- `supabase/tests/phase9_security.mjs`
- `lib/features/chat/domain/chat_models.dart`
- `lib/features/chat/data/chat_api.dart`
- `lib/features/chat/data/chat_repository.dart`
- `lib/features/chat/data/chat_vocabulary_providers.dart`
- `lib/features/chat/presentation/chat_controller.dart`
- `lib/features/chat/presentation/chat_input_bar.dart`
- `lib/features/chat/presentation/chat_message_tile.dart`
- `lib/features/audio/presentation/chat_dictation_controller.dart`
- `lib/shared/widgets/speech_permission_dialog.dart`
- `test/support/chat_fixtures.dart`
- `test/chat_repository_test.dart`
- `test/chat_api_test.dart`
- `test/chat_controller_test.dart`
- `test/chat_widget_test.dart`
- `PHASE9_IMPLEMENTATION.md`

## 6. Files updated for Phase 9

- `lib/core/database/app_database.dart` and generated `app_database.g.dart`
- `lib/features/chat/presentation/chat_screen.dart`
- `lib/features/sync/domain/sync_record.dart`
- `lib/features/sync/data/local_sync_store.dart`
- `lib/features/sync/data/remote_sync_store.dart`
- `lib/features/activity/data/activity_repository.dart`
- `lib/features/flashcards/presentation/review_providers.dart`
- `lib/features/home/presentation/home_screen.dart`
- `lib/features/exercises/presentation/speaking_view.dart`
- `lib/l10n/app_en.arb` and generated `lib/core/localization/ui_messages.g.dart`
- `test/widget_test.dart`, `test/review_session_controller_test.dart`
- `test/account_database_test.dart`, `test/remote_sync_store_test.dart`
- `test/lingoblob_ui_test.dart`
- `tool/browser_database_smoke.dart`
- `README.md`, `SUPABASE_SETUP.md`

Phase 8's existing local changes are retained. No new dependency is required for
Phase 9, and no credentials are added to tracked source.
