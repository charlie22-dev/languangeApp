# Phase 10: testing, polish and Android release

Application identity: **LingoBlob**, Android/iOS ID
`com.charlie22dev.lingoblob`, version **1.0.0+1**. Android is the release target;
iOS branding/identifiers are prepared but cannot be built or signed on Windows.

## Audit before implementation

| Before | After / intended result | Why |
| --- | --- | --- |
| Placeholder Android package/label; release used debug signing | Permanent package/label, private upload key and fail-closed release signing | Correct release identity |
| No device integration target | Real-asset lesson, grading, SQLite reopen and unlock assertions | Verify the full flow |
| Review ratings had English labels outside ARB; obsolete feature-unavailable copy remained | Rating keys, localized errors and removal of stale messages | Accurate, centralized copy |
| Default pushed-page transitions | Short fades with a reduced-motion bypass | Predictable navigation |
| Lazy list built an entire unit's widget subtree | Lightweight row descriptions and individual keyed lazy rows | Scale to longer courses |
| Coral error text on white did not meet text contrast | Darker light-mode error text; coral retained on feedback containers | At least 4.5:1 for error text |
| Profile section failures had no local retry action | Shared compact retry widget | Recover without discarding the whole screen |
| Launcher/splash assets had no reproducible workflow | Existing vector Pip exported through Flutter, then package generators | Consistent branding |
| Japanese depended on host fallback fonts | Bundled Noto Sans JP and its license | Offline CJK rendering across platforms |
| README lacked actual screenshots and release materials | Captures, architecture, setup, roadmap and separate store/privacy drafts | Reviewable handoff |

The import graph found no Dart source file unreachable from `lib/main.dart`,
including conditional platform imports and generated parts. This is not proof
that every public method is used; model serialization and testable interfaces
remain intentional API surfaces. Static analysis checks unused imports and const
opportunities. Existing choice/answer cards share the design system but have
different state/semantics contracts; they were not forced into one oversized API.

Colors are centralized in `LingoPalette`, themes and semantic tokens. Generator
YAML files repeat native hex values because they run outside Flutter; update
those when changing branding. Audio already loads on explicit playback, and the
native player is allocated on first load. That lazy behavior is preserved.

## Steps and how to test

1. **Localization/navigation/path:** review rating labels use ARB; known auth and
   review error text passes through localization. `lingoPage` adds 180 ms fades
   and respects `disableAnimations`. Tab branches keep their existing navigation
   state. The path builds individual nodes rather than whole units.
2. **Regression tests:** focused widget tests cover correct feedback, incorrect
   feedback/requeue, completion/XP and onboarding redirects. A 100-lesson test
   verifies fewer than 12 lesson-node widgets exist at either end of the list.
   Existing tests scroll to off-screen nodes rather than relying on eager builds.
3. **Accessibility/recovery:** contrast pairs, Android touch-target and labeled
   target guidelines run in widget tests. Error text uses an accessible theme
   shade. Profile stats/activity can retry independently. Existing haptics on
   correct/wrong answers and reduced-motion-aware feedback are preserved.
4. **Branding:** `tool/generate_brand_assets.dart` renders our own vector Pip.
   `flutter_launcher_icons` and `flutter_native_splash` generate native/web assets.
   Native splash uses cream/night backgrounds and Pip, including Android 12+.
5. **Release:** Gradle reads ignored signing properties, requires upload signing
   for release, enables shrinking and targets API 37. `create_upload_key.py`
   generates random passwords without printing them and refuses to overwrite
   existing files. `verify_android_bundle.py` checks signing and native ELF load
   alignment. No private key/password belongs in Git or Flutter configuration.

```powershell
flutter analyze
flutter test
flutter test tool/generate_brand_assets.dart
dart run flutter_launcher_icons
dart run flutter_native_splash:create
flutter test test/support/capture_lingoblob.dart
```

Run Flutter commands **sequentially** and use the normal release command, without
`--no-pub`. In Flutter 3.47.6, `--no-pub` skips platform plugin regeneration and
can retain a test-only integration plugin in the Java registrant even though
Gradle excludes it from release dependencies. That caused the initial AAB
compilation failures; it was not a signing failure. Normal release tooling
regenerates the filtered registrant. Avoid parallel native-file generation too.

## Integration and performance

```powershell
flutter drive --profile --no-dds --driver=test_driver/integration_test.dart --target=integration_test/lesson_flow_test.dart -d emulator-5554
```

The integration target uses the real bundled course, real controllers/repositories
and a durable database named for `phase10-integration-only`. Only that isolated
test account is reset. It does not touch a learner's account/database. Audio/STT
and auth/IME input are deterministic boundaries; live microphone, native keyboard, OAuth and cloud behavior
remain separate manual checks. Completion must persist 100%/50 XP, unlock lesson
two and survive closing/reopening SQLite.

The driver collects a profile-mode scroll timeline in
`build/performance/lesson_flow.json`. Emulator measurements are diagnostic and
cannot establish low-end physical-device performance.

For Flutter DevTools inspection:

1. Run `flutter run --profile --dart-define-from-file=config.local.json` on a
   physical device and open the DevTools URL printed in the terminal.
2. In Performance, record a Learn-path scroll, a Chat send and a Review flip.
   Inspect UI/raster frame timing and long frames; use the device's refresh-rate
   budget rather than assuming every device runs at 60 Hz.
3. Use enhanced tracing / Track Widget Builds and Track Layouts where supported;
   use a debug run for Rebuild Stats and repaint highlighting. Inspect visible
   lesson rows, not a whole-unit subtree. Profile again after disabling tracing.
4. Confirm no audio file or audio network request loads before Play. Platform
   plugins may register their bridge/TTS service earlier; file/player loading is
   lazy. Opening Learn must not request microphone access.
5. Check actual lower-end devices before setting performance release gates.

This implementation does not claim a manual DevTools GUI session or physical
device performance review was completed by automated tests.

## Screen coverage and manual checks

| Screen/state | Automated coverage | Manual release check |
| --- | --- | --- |
| Login/register/recovery | Validation, errors, redirects, 320 dp/200% fonts | Live OAuth/email links on a signed install |
| Welcome/language/goal | Persistence, loading/error, back navigation, redirects | TalkBack focus order |
| Learn | Loading/retry, locked/unlocked/completed nodes, long lazy list | Physical-device scroll trace |
| Six exercise views | Correct/wrong/finish, keyboard, hearts, audio fallback, 320 dp/200% | Real voices/microphone permissions |
| Feedback/quit/results | Haptics code, retry-save, system Back and results | Device vibration preferences |
| Review | Enrollment, flip, ratings, summary and empty state | Pronunciation with installed voices |
| Chat | Retry/dictation/corrections/word saving, 360 dp/200%, keyboard | Deployed Groq latency, quota, real network loss |
| Profile/Settings | Real stats, reset confirmation, reminders, themes and large fonts | TalkBack announcements and notification delivery |
| System splash/icon | Generated Android/iOS/web assets | Cold launch, launcher masks, light/dark startup |

## Release handoff

- Signing files: ignored `android/key.properties` and
  `android/app/lingoblob-upload.jks`. Back up both securely outside the repository.
- Build: `flutter build appbundle --release --dart-define-from-file=config.local.json`.
- Bundle: `build/app/outputs/bundle/release/app-release.aab`.
- Validate: `python tool/verify_android_bundle.py`.
- Store materials: [Play checklist](docs/PLAY_STORE_CHECKLIST.md),
  [privacy draft](docs/PRIVACY_POLICY_DRAFT.md), [screenshots](docs/screenshots).

Publication still needs reviewed public privacy/deletion URLs, in-app deletion
requests and AI-response reporting, verified backend deployment, Play declarations/reviewer access and
device/closed testing. Reset progress/log out do not delete a Supabase account.
No store submission or external deployment is part of this local build task.

## Verification results

- `flutter analyze`: no issues.
- `flutter test`: **243 tests passed**, including the four focused Phase 10 tests.
- Branding exporter: **1 test passed**; launcher/splash generators completed.
- Screenshot capture: **3 tests passed**, producing **13 images** at 1080x1920.
  Learn and lesson captures were inspected visually; Japanese glyphs render with
  the bundled font.
- Android API 37 x86_64 integration in profile mode: **passed**. All eight
  exercises completed, 50 XP persisted, lesson two unlocked and SQLite reopen
  assertions passed. Timeline capture requires `--no-dds` with this SDK.
- Profile trace: `build/performance/lesson_flow.json`, **5,632 events**.
  A derived local summary is `build/performance/summary.json`.

| Trace section | Samples | Median ms | Maximum ms |
| --- | --- | --- | --- |
| Widget build phases | 25 | 0.209 | 7.004 |
| Layout phases | 15 | 0.020 | 29.620 |
| Software raster draw | 14 | 49.634 | 157.069 |

These are phase durations, not total frame times. Rasterization is slow on this
software-rendered, memory-constrained emulator, and the trace includes a long
layout phase. No 60 FPS or physical-device performance claim is made. The lazy
list regression establishes bounded widget construction; a physical-device
DevTools session remains a pre-publication check.

- Standard Android release command: **passed**, producing a **71.5 MiB** signed AAB
  (**75,001,198 bytes**). Signature/package checks pass, signing files are absent
  from the archive, and all **10** 64-bit native libraries pass 16 KiB ELF load
  alignment checks. `apkanalyzer` confirms Flutter/app symbol metadata is present.
- The local SDK lacked command-line tools, which made Flutter's symbol-check
  stage fail even though the AAB existed. Official tools were downloaded from
  Google's repository, checksum-verified and installed into the existing SDK;
  the normal build then exited successfully. The tools are under
  `%LOCALAPPDATA%/Android/sdk/cmdline-tools/latest`. No symbol-check bypass was added.
- Web release: **passed**. A fresh Edge context at 360x800 loaded the production
  build, enabled semantics and displayed invalid-email validation, with no
  uncaught browser errors or account-service writes. This was not a live login.
- Store draft lengths: title **25/30**, short description **74/80** characters.
- Existing Flutter TTS/Kotlin migration warnings remain non-blocking for this
  installed toolchain. iOS and physical-device checks remain unverified here.

AAB SHA-256:
`0cdae51486490700354633bf1c3d4a9588c572a3360341d487f8d8dcb44fc406`.
A checksum sidecar is saved next to the bundle.

The internal Dart package remains `myapp` to preserve imports; public labels and
native identifiers use LingoBlob. No store submission or Git push was performed.

## Files created, edited or replaced in Phase 10

Paths below are relative to the project root. Generated platform assets are listed individually.

| Change | File |
| --- | --- |
| Created | `PHASE10_IMPLEMENTATION.md` |
| Edited | `README.md` |
| Edited | `android/app/build.gradle.kts` |
| Edited | `android/app/src/main/AndroidManifest.xml` |
| Created | `android/app/src/main/kotlin/com/charlie22dev/lingoblob/MainActivity.kt` |
| Deleted | `android/app/src/main/kotlin/com/example/myapp/MainActivity.kt` |
| Created | `android/app/src/main/res/drawable-hdpi/android12splash.png` |
| Created | `android/app/src/main/res/drawable-hdpi/ic_launcher_foreground.png` |
| Created | `android/app/src/main/res/drawable-hdpi/splash.png` |
| Created | `android/app/src/main/res/drawable-mdpi/android12splash.png` |
| Created | `android/app/src/main/res/drawable-mdpi/ic_launcher_foreground.png` |
| Created | `android/app/src/main/res/drawable-mdpi/splash.png` |
| Created | `android/app/src/main/res/drawable-night-hdpi/android12splash.png` |
| Created | `android/app/src/main/res/drawable-night-hdpi/splash.png` |
| Created | `android/app/src/main/res/drawable-night-mdpi/android12splash.png` |
| Created | `android/app/src/main/res/drawable-night-mdpi/splash.png` |
| Created | `android/app/src/main/res/drawable-night-v21/background.png` |
| Created | `android/app/src/main/res/drawable-night-v21/launch_background.xml` |
| Created | `android/app/src/main/res/drawable-night-xhdpi/android12splash.png` |
| Created | `android/app/src/main/res/drawable-night-xhdpi/splash.png` |
| Created | `android/app/src/main/res/drawable-night-xxhdpi/android12splash.png` |
| Created | `android/app/src/main/res/drawable-night-xxhdpi/splash.png` |
| Created | `android/app/src/main/res/drawable-night-xxxhdpi/android12splash.png` |
| Created | `android/app/src/main/res/drawable-night-xxxhdpi/splash.png` |
| Created | `android/app/src/main/res/drawable-night/background.png` |
| Created | `android/app/src/main/res/drawable-night/launch_background.xml` |
| Created | `android/app/src/main/res/drawable-v21/background.png` |
| Edited | `android/app/src/main/res/drawable-v21/launch_background.xml` |
| Created | `android/app/src/main/res/drawable-xhdpi/android12splash.png` |
| Created | `android/app/src/main/res/drawable-xhdpi/ic_launcher_foreground.png` |
| Created | `android/app/src/main/res/drawable-xhdpi/splash.png` |
| Created | `android/app/src/main/res/drawable-xxhdpi/android12splash.png` |
| Created | `android/app/src/main/res/drawable-xxhdpi/ic_launcher_foreground.png` |
| Created | `android/app/src/main/res/drawable-xxhdpi/splash.png` |
| Created | `android/app/src/main/res/drawable-xxxhdpi/android12splash.png` |
| Created | `android/app/src/main/res/drawable-xxxhdpi/ic_launcher_foreground.png` |
| Created | `android/app/src/main/res/drawable-xxxhdpi/splash.png` |
| Created | `android/app/src/main/res/drawable/background.png` |
| Edited | `android/app/src/main/res/drawable/launch_background.xml` |
| Created | `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml` |
| Edited | `android/app/src/main/res/mipmap-hdpi/ic_launcher.png` |
| Edited | `android/app/src/main/res/mipmap-mdpi/ic_launcher.png` |
| Edited | `android/app/src/main/res/mipmap-xhdpi/ic_launcher.png` |
| Edited | `android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png` |
| Edited | `android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png` |
| Edited | `android/app/src/main/res/values-night/styles.xml` |
| Created | `android/app/src/main/res/values/colors.xml` |
| Edited | `android/app/src/main/res/values/styles.xml` |
| Created | `android/key.properties.example` |
| Created | `assets/branding/README.md` |
| Created | `assets/branding/app_icon.png` |
| Created | `assets/branding/pip_foreground.png` |
| Created | `assets/branding/play_store_icon.png` |
| Created | `assets/fonts/NOTO_SOURCE.md` |
| Created | `assets/fonts/NotoSansJP-OFL.txt` |
| Created | `assets/fonts/NotoSansJP.ttf` |
| Created | `docs/PLAY_STORE_CHECKLIST.md` |
| Created | `docs/PRIVACY_POLICY_DRAFT.md` |
| Created | `docs/screenshots/dark-chat.png` |
| Created | `docs/screenshots/dark-home.png` |
| Created | `docs/screenshots/dark-lesson-ja_greetings.png` |
| Created | `docs/screenshots/dark-profile.png` |
| Created | `docs/screenshots/dark-review.png` |
| Created | `docs/screenshots/dark-settings.png` |
| Created | `docs/screenshots/light-chat.png` |
| Created | `docs/screenshots/light-home.png` |
| Created | `docs/screenshots/light-lesson-ja_greetings.png` |
| Created | `docs/screenshots/light-profile.png` |
| Created | `docs/screenshots/light-review.png` |
| Created | `docs/screenshots/light-settings.png` |
| Created | `docs/screenshots/login.png` |
| Created | `flutter_launcher_icons.yaml` |
| Created | `flutter_native_splash.yaml` |
| Created | `integration_test/lesson_flow_test.dart` |
| Edited | `ios/Runner.xcodeproj/project.pbxproj` |
| Edited | `ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json` |
| Edited | `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png` |
| Edited | `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png` |
| Edited | `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png` |
| Edited | `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png` |
| Edited | `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png` |
| Edited | `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png` |
| Edited | `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png` |
| Edited | `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png` |
| Edited | `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png` |
| Edited | `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png` |
| Created | `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-50x50@1x.png` |
| Created | `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-50x50@2x.png` |
| Created | `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-57x57@1x.png` |
| Created | `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-57x57@2x.png` |
| Edited | `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png` |
| Edited | `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png` |
| Created | `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-72x72@1x.png` |
| Created | `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-72x72@2x.png` |
| Edited | `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png` |
| Edited | `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png` |
| Edited | `ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png` |
| Created | `ios/Runner/Assets.xcassets/LaunchBackground.imageset/Contents.json` |
| Created | `ios/Runner/Assets.xcassets/LaunchBackground.imageset/background.png` |
| Created | `ios/Runner/Assets.xcassets/LaunchBackground.imageset/darkbackground.png` |
| Edited | `ios/Runner/Assets.xcassets/LaunchImage.imageset/Contents.json` |
| Edited | `ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage.png` |
| Edited | `ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@2x.png` |
| Edited | `ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@3x.png` |
| Created | `ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImageDark.png` |
| Created | `ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImageDark@2x.png` |
| Created | `ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImageDark@3x.png` |
| Edited | `ios/Runner/Base.lproj/LaunchScreen.storyboard` |
| Edited | `ios/Runner/Info.plist` |
| Edited | `lib/core/config/app_config.dart` |
| Edited | `lib/core/localization/ui_messages.g.dart` |
| Edited | `lib/core/router/app_router.dart` |
| Created | `lib/core/router/lingo_page.dart` |
| Edited | `lib/core/theme/app_theme.dart` |
| Edited | `lib/core/theme/lingo_font_license.dart` |
| Edited | `lib/core/theme/lingo_tokens.dart` |
| Edited | `lib/features/auth/presentation/auth_screens.dart` |
| Edited | `lib/features/flashcards/domain/review_session.dart` |
| Edited | `lib/features/flashcards/presentation/review_rating_buttons.dart` |
| Edited | `lib/features/flashcards/presentation/review_session_screen.dart` |
| Edited | `lib/features/flashcards/presentation/review_summary.dart` |
| Edited | `lib/features/home/presentation/learning_path_view.dart` |
| Edited | `lib/features/profile/presentation/profile_screen.dart` |
| Edited | `lib/l10n/app_en.arb` |
| Created | `lib/shared/widgets/inline_retry.dart` |
| Edited | `pubspec.lock` |
| Edited | `pubspec.yaml` |
| Edited | `test/lesson_engine_widget_test.dart` |
| Edited | `test/lingoblob_ui_test.dart` |
| Created | `test/phase10_release_widget_test.dart` |
| Edited | `test/review_repository_test.dart` |
| Edited | `test/support/capture_lingoblob.dart` |
| Edited | `test/widget_test.dart` |
| Created | `test_driver/integration_test.dart` |
| Created | `tool/create_upload_key.py` |
| Created | `tool/generate_brand_assets.dart` |
| Created | `tool/verify_android_bundle.py` |
| Edited | `web/favicon.png` |
| Edited | `web/icons/Icon-192.png` |
| Edited | `web/icons/Icon-512.png` |
| Edited | `web/icons/Icon-maskable-192.png` |
| Edited | `web/icons/Icon-maskable-512.png` |
| Edited | `web/index.html` |
| Edited | `web/manifest.json` |
| Created | `web/splash/img/dark-1x.png` |
| Created | `web/splash/img/dark-2x.png` |
| Created | `web/splash/img/dark-3x.png` |
| Created | `web/splash/img/dark-4x.png` |
| Created | `web/splash/img/light-1x.png` |
| Created | `web/splash/img/light-2x.png` |
| Created | `web/splash/img/light-3x.png` |
| Created | `web/splash/img/light-4x.png` |
