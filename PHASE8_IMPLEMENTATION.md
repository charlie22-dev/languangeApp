# Phase 8: audio and speech

The previous work was committed in **70 nonempty commits** and pushed to
`origin/main` at `c0a7bd0`. Phase 8 below is implemented in the working tree;
it has not been committed or pushed as part of those earlier 70 commits.

## Run

Stop the previous Flutter run completely: native plugin/permission changes
need a rebuild, not just hot reload.

```powershell
cd C:\Langunge_flutter\myapp
flutter pub get
flutter run -d edge --web-port=7357 --dart-define-from-file=config.local.json
```

Keep your existing fixed port if different. For microphone/voice testing on Android:

```powershell
flutter devices
flutter run -d emulator-5554 --dart-define-from-file=config.local.json
```

The course is **Japanese**, so its explicit `targetLocale` is **ja-JP**.
Changing the course locale changes pronunciation/recognition; UI language stays
English. Existing course files without a locale still resolve common language
names/codes through the locale helper. Unknown languages show a useful error.
For another course, provide its actual BCP-47 locale, for example `es-ES`.

No additional Supabase migration is required for Phase 8. Keep the Phase 7
migration applied for XP/activity sync. Recordings and transcripts are not
uploaded to Supabase or saved in the app database.

## Playback and caching

The reusable speaker button appears in Listening, Speaking and review flashcards.
Playback order is:

1. A supplied `assets/audio/...` recording through `just_audio`.
2. A cached remote recording, downloading from its HTTP(S) URL if necessary.
3. TTS in the course locale when no recording is supplied or playback fails.

`assets/audio/` is registered in pubspec.yaml. It currently contains instructions,
not human voice recordings: the sample course uses TTS. To add a licensed recording,
put it there and set a word/exercise `audioUrl` to its asset path. Remote files
should be served over HTTPS with browser CORS access and a supported audio format.
No broad Android cleartext exception or iOS arbitrary-network exception was added.

Native clips are cached in the app's temporary directory, keyed by the complete
URL hash, including query parameters. They survive ordinary restarts until the OS
clears the temporary cache. Concurrent requests for the same URL share a download;
writes use a temporary file and rename. Browser clips use a bounded session blob
cache, alongside normal server/browser HTTP caching. The browser cache is not a
guaranteed permanent offline store. Missing files, network failures and decode
errors fall back to TTS. Missing voices display installation/retry guidance.

Pressing the speaker again stops it. Playback is cancelled when its widget leaves
the screen, the lesson closes or the app backgrounds. A stale download cannot
interrupt a newer pronunciation. Sound-effects settings still control feedback
sounds; explicitly requested pronunciation remains available.

Install/download the course's voice in the device's speech settings if no voice
is available. Browser voices depend on the browser/OS. Listening offers **Show
text instead** after playback failure, so a missing voice does not block a lesson.

## Course JSON additions

The existing course schema remains backward-compatible for older course assets.
The sample now contains **48 exercises**: six lessons with eight exercises each,
including one Listening and one Speaking exercise per lesson. Word IDs, lesson
IDs, previous progress and the original exercise types are preserved.

| Model/type | Field | Meaning |
| --- | --- | --- |
| Course | `targetLocale?` | Speech locale, sample `ja-JP` |
| Listening | `id`, `type: listening` | Unique exercise identity/type |
| Listening | `audioText` | Target-language phrase used for TTS |
| Listening | `acceptedAnswers` | Nonempty accepted answer list |
| Listening | `options?` | Two or more choices; omit for typed response |
| Listening | `audioUrl?` | Optional bundled/remote recording |
| Speaking | `id`, `type: speaking`, `phrase` | Target phrase to pronounce |
| Speaking | `audioUrl?` | Optional model-pronunciation recording |
| Speaking | `minimumScore?` | Match threshold from 0 to 1; defaults to 0.8 |
| Speaking | `acceptedAnswers?` | Additional transcript variants, e.g. kanji/numerals |

```json
{
  "id": "listen_hola",
  "type": "listening",
  "audioText": "hola",
  "acceptedAnswers": ["hola"],
  "options": ["hola", "gracias", "adiós"]
}
```

```json
{
  "id": "say_hello",
  "type": "speaking",
  "phrase": "こんにちは",
  "minimumScore": 0.8
}
```

Listening keeps the target text hidden until feedback or the unavailable-audio
alternative. Choice answers and typed answers use the pure grading engine.
Speaking recognizes a transcript and compares it to the phrase/accepted variants.
The scorer lowercases, removes punctuation/whitespace and computes
`1 - Levenshtein distance / max character length`. Unicode code points are used.
Empty/silent responses score zero. The displayed score is a **text match**, not
an assessment of accent, intonation or pronunciation quality.

## Microphone permission and skipping

There is no recording or microphone permission prompt on launch. In a Speaking
exercise, choose **Start recording**, read the explanation, then explicitly
start. The OS may request microphone/speech permission. The explanation states
that the device/browser speech provider may process audio remotely.

Partial transcripts are shown while listening; a stopped/final transcript can be
checked. Recordings are limited to short practice sessions. Pronunciation stops
before recording; recognition stops on Check, lesson exit and backgrounding.

Use **Skip speaking** in the explanation or exercise, including after OS denial.
Skipping loses no heart, counts no attempt, grants no perfect-exercise XP, and
allows the lesson to finish/unlock the next. Results show the skipped count.
A lesson consisting entirely of skipped exercises earns zero XP and does not
advance the streak. Normal lesson XP, wrong-answer requeue and SM-2 stay intact.

Speech availability varies by device/browser and may need a network connection.
Chrome/Edge require a secure context for microphone use; localhost is suitable
for development. Denial/unavailable language/network errors show guidance and
leave Skip available. The app does not store a user audio file.

## Exact platform file locations

These changes are already applied; do not paste duplicate permissions.

**Android:** `android/app/src/main/AndroidManifest.xml`.
Place microphone permission directly inside `<manifest>`, beside INTERNET and
the existing notification permissions, before `<application>`:

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.INTERNET" />
```

Add these intents to its existing root-level `<queries>` block:

```xml
<intent>
    <action android:name="android.speech.RecognitionService" />
</intent>
<intent>
    <action android:name="android.intent.action.TTS_SERVICE" />
</intent>
```

Speech initialization uses `SpeechToText.androidNoBluetooth`; this feature does
not request Bluetooth permission. Recording needs no storage permission.

**iOS:** `ios/Runner/Info.plist`. Both keys are in the main/root `<dict>` before
its closing `</dict>`:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>Use your microphone to practice speaking lesson phrases. You can skip speaking exercises.</string>
<key>NSSpeechRecognitionUsageDescription</key>
<string>Convert your spoken practice phrase to text so you can compare it with the lesson. Your device may use its speech recognition provider.</string>
```

See the official [speech_to_text platform setup](https://pub.dev/packages/speech_to_text)
and [Apple's permission requirements](https://developer.apple.com/documentation/Speech/asking-permission-to-use-speech-recognition).
Voice playback uses [flutter_tts](https://pub.dev/packages/flutter_tts) and
[just_audio](https://pub.dev/packages/just_audio).

## Validation and manual checks

Verified: **214 Flutter tests passed**, analyzer/formatting clean, Android debug APK and web builds passed,
and the real Edge browser cache check passed. The tests cover similarity edits,
Japanese, punctuation, case, whitespace, empty input, accents, cache reuse,
fallback, stale playback cancellation, permission denial, scoring, skipping,
late recognition callbacks, all six real lesson views and 200% text layouts.

```powershell
flutter analyze
flutter test
flutter build apk --debug --target-platform android-x64
flutter build web --no-web-resources-cdn --no-wasm-dry-run
```

Real voice output and microphone recognition still need a device check; tests use
fake speech results instead of recording your voice. iOS compilation requires
macOS/Xcode and was not run on this Windows machine.

1. Sign in and open the first lesson. Its final two exercises are Listening/Speaking.
2. Play pronunciation; verify Japanese voice output and retry with a missing voice.
3. Accept recording, say the phrase, stop and check the transcript/score.
4. Deny the permission and skip; verify hearts and skipped count.
5. Play a review card. For a supplied recording, replay it offline after caching.
6. Background/leave while playing or recording and verify it stops.

For the optional browser cache-only check, compile
`tool/browser_audio_cache_smoke.dart` with `dart compile js`, serve it in an
isolated test folder beside `clip.wav` containing bytes `[1,2,3,4]`, and load its
script in Edge. It prints `BROWSER_AUDIO_CACHE_PASS`. This checks bytes/blob reuse,
not audio decoding or a real voice.

## Flutter-specific structure

Riverpod owns the service/controller lifetimes, similar to shared React state.
The lesson controller grades pure Dart answers; widgets only collect input and
render state. Small output/cache interfaces let tests replace platform plugins.
Conditional exports select filesystem caching on native platforms and blob caching
in the browser, preventing browser builds from importing `dart:io`.

| Before | After | Why |
| --- | --- | --- |
| Silent review cards | Reusable pronunciation button | Plays the word from its actual data |
| Four exercise types | Six types with Listening/Speaking | Adds audio practice to the existing engine |
| No microphone flow | Explanation, explicit record/stop, transcript and skip | Makes capture intentional and handles unavailable devices |
| No speech rubric | Text-match score and target feedback | Shows what was checked without claiming phonetic assessment |

## Files created

- `lib/features/audio/domain/audio_ports.dart`
- `lib/features/audio/domain/language_locale.dart`
- `lib/features/audio/domain/speech_similarity.dart`
- `lib/features/audio/data/audio_cache.dart`
- `lib/features/audio/data/audio_cache_native.dart`
- `lib/features/audio/data/audio_cache_web.dart`
- `lib/features/audio/data/audio_service.dart`
- `lib/features/audio/data/speech_service.dart`
- `lib/features/audio/presentation/speaking_controller.dart`
- `lib/features/exercises/presentation/listening_view.dart`
- `lib/features/exercises/presentation/speaking_view.dart`
- `lib/shared/widgets/audio_speaker_button.dart`
- `assets/audio/README.md`
- `test/audio_cache_test.dart`
- `test/audio_service_test.dart`
- `test/audio_exercise_test.dart`
- `test/audio_exercise_widget_test.dart`
- `test/speech_similarity_test.dart`
- `test/speaking_controller_test.dart`
- `test/support/audio_fixtures.dart`
- `tool/browser_audio_cache_smoke.dart`
- `PHASE8_IMPLEMENTATION.md`

## Files updated

- `pubspec.yaml` and `pubspec.lock`
- `android/app/src/main/AndroidManifest.xml`
- `ios/Runner/Info.plist`
- `assets/courses/japanese_basics.json`
- `lib/app/app.dart`
- `lib/features/exercises/domain/exercise.dart` and `exercise_grader.dart`
- `lib/features/lessons/domain/course.dart` and `lesson_session.dart`
- `lib/features/lessons/data/lesson_completion_repository.dart`
- `lib/features/lessons/presentation/exercise_content.dart`, `lesson_controller.dart`,
  `lesson_runner.dart` and `results_screen.dart`
- `lib/features/flashcards/presentation/review_session_screen.dart`
- `lib/shared/widgets/answer_feedback_sheet.dart`
- `lib/l10n/app_en.arb` and generated `lib/core/localization/ui_messages.g.dart`
- `test/course_content_test.dart`, `test/lesson_engine_widget_test.dart`, `test/widget_test.dart`
- Generated registrations: `macos/Flutter/GeneratedPluginRegistrant.swift`,
  `windows/flutter/generated_plugin_registrant.cc`, `windows/flutter/generated_plugins.cmake`
- `README.md`
