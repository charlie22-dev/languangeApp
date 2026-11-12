# LingoBlob UI implementation

The reference is `lingoblob_ui_ux_design_system_prototype.html` at the repository root.
Its HTML, Tailwind classes, JavaScript, phone frames, presentation toolbar and canvas
shadows are not shipped in Flutter. Native widgets and CustomPainter recreate the
app design. The two LingoBlob WebP reference boards remain untouched.

## Scope and preserved behavior

The UI uses the existing account, course, lesson, review, XP and streak data. No
Spanish demo course, Alex Rivera identity, cafe conversation, fake XP totals,
pronunciation score, review interval or activity history has been introduced.
The local config now sets APP_NAME to LingoBlob; AppConfig remains the source.
config.example.json includes that non-secret brand setting. The local Supabase
URL/key are still ignored and untracked.

Existing lesson controllers, grading, SM-2, auth controllers, models, local
storage, migrations and sync were preserved. The new appearance controller stores
only a device presentation preference. The new profile provider is a read-only
projection of the existing account database. Existing route paths and redirect
rules remain; additions are /chat, /settings and debug-only /dev/components.
Existing navigation branch indices were retained, with a UI mapping for the
Learn / Review / Chat / Profile display order.

## Steps completed

1. Theme: complete light/dark ColorScheme from the ten JS palette roles and CSS
   support tokens; onPrimary stays navy in both modes. Plus Jakarta Sans weights
   400/500/600/700/800 are bundled, runtime fetching is disabled, CJK system font
   fallback is specified, and the OFL license is registered. Shared tokens cover
   8/16/24/32 spacing, 24/16/999 radii, 48 dp targets and 2 px borders. ThemeData
   styles buttons, fields, cards, chips, navigation, radio controls, dialogs,
   sheets and progress. Light/dark/system selection persists with SharedPreferences.
2. Shared widgets: five native-vector Pip moods with size/semantics support;
   primary/accent/secondary/ghost button presentations and press feedback; option
   states; cards; progress/hearts; XP/streak badges; lesson nodes; 3D card flip;
   chat/correction previews; skeletons and empty/error states. Debug gallery is
   reachable from Profile > Settings > Component gallery in debug builds.
3. Auth/onboarding: native Android Pip splash assets, themed existing forms, dedicated email-sent view, startup
   states, welcome, catalog-driven languages and saved daily goals. Supabase
   operations, validation, recovery routing and error handling remain intact.
4. Home: live stats, a target ring, periwinkle unit headers, winding connectors,
   completed/available/locked lessons and four navigation destinations.
5. Lessons: four supported exercises are reskinned, using controller feedback
   for correctness. Spanish accent keys appear only for a Spanish/es course and
   insert at the current selection. Feedback pops/shakes, button press scales,
   haptics, quit confirmation and results preserve their original actions.
   Saved results display the real current streak with a finite celebration pulse.
6. Review/profile/settings/chat: real due-card flow, 550 ms flip, accessible
   rating colors, saved summaries/next-due states; account/profile/XP/streak/word
   metrics; working appearance and logout; honest unavailable states elsewhere.
7. Polish: localization-ready English ARB catalog, responsive layouts, semantic
   labels, dual-encoded answer states, offline-safe fonts, reduced-motion support,
   sync-unavailable messaging and informational permission explainers.

ThemeExtension adds the custom design tokens to Flutter ThemeData. CustomPainter
draws vector artwork directly on the Flutter canvas; Pip has no HTML or SVG
runtime dependency. The appearance controller is a new Riverpod UI state source
that stores a device preference without changing learning state.

## Screen-by-screen checklist

| Screen/state | Before | After | Differences and reasons |
| --- | --- | --- | --- |
| 1. Splash/startup | Generic progress states | Pip, brand palette, skeletons and existing retry states | Android launch themes now use a static Pip vector and lime background, including the Android 12+ system splash. Startup follows actual readiness, with no artificial 1.2 s delay. Other platforms retain their native launch assets. |
| 2. Welcome | Generic onboarding introduction | Pip, themed typography and existing Get Started action | Welcome remains after auth, matching the existing guarded onboarding flow. No pre-auth redirect change. |
| 3. Signup | Email/password/confirmation/Google form | Themed form, celebrating Pip, disabled/busy/error/confirmation states | Password confirmation retained; name entry omitted because registration has no name-write contract. Adaptive canvas retained for consistent dark mode. |
| 4. Login | Existing validated form | Pip, flat fields/buttons, password visibility and existing error/retry states | No hard-coded streak claim or example email. |
| 4. Forgot/email sent/reset | Inline message plus recovery form | Dedicated email-sent presentation and themed recovery form | Keeps the non-enumerating account-existence message; no claim that an unknown account received mail. |
| 5. Language/goal onboarding | Catalog and saved 5/10/15-minute choices | Pip, progress, selected cards and themed actions | Japanese/English comes from the course. Existing three-step sequence includes Welcome; no fake learner counts or unavailable course choices. |
| 6. Home | Straight path and stats | Curved path, unit headers, live badges and target ring | Ring represents a target, not measured elapsed minutes. Account-wide hearts omitted; lives belong to each lesson. |
| 7a. Multiple choice | Working choices/grading | Native option selection and correct/wrong presentation | Uses actual exercise text and controller result. No audio playback without an audio feature. |
| 7b. Match pairs | Working editable pairs | Outlined two-column cards, selection and pair labels | A selected pair is not labeled correct before Check grades it. |
| 7c. Fill blank | Working choices | Themed sentence/answer layout and graded choice state | Existing exercise schema and checking preserved. |
| 7d. Type translation | Text input | Themed multiline field and language-aware accent helper | Japanese does not show Spanish diacritic keys. Caret/selection and controller answer are preserved. |
| 7e. Listening | No model/player | Disabled listening component preview in debug gallery | Functional audio, speed control and word assembly need a separate engine/content feature. |
| 7f. Speaking | No recording/grading feature | Explicit idle/recording/unavailable visual previews | No microphone requests, recordings or invented 94% score. |
| 8. Feedback/quit | Working feedback and confirmation | Green/coral sheets, icons, readable ink, motion/haptics and sad Pip dialog | Three lives and wrong-answer re-queues remain. Chimes are unavailable without sound assets/player. |
| 9. Results/streak | Working save/results/retry | Celebrating Pip, real metrics and saved streak badge/pulse | No fabricated weekly tracker or goal completion. Metrics stack for small/large-text layouts. Pulse runs once, not forever. |
| 10. Review landing | Due count/start | Themed existing due-card flow | No extra-card practice action without a repository feature. |
| 10. Flashcard/ratings | Existing flip and SM-2 | Bordered 3D flip, dual faces and coral/periwinkle/lime/green rating controls | Ratings use a responsive 2x2 grid. Actual SM-2 is preserved; prototype 1m/12h/2d/5d examples are not copied. |
| 10. Summary/empty | Real ratings and next due | Pip and themed real summary/empty states | No invented recall-accuracy or mastery metrics. |
| 11. AI chat | No feature | Honest Chat destination; reusable bubbles/corrections in debug gallery | No scenarios/messages/corrections or save-word API fabricated. |
| 12. Profile | Email/sync/logout | Synced name when present, email, course, XP, streak and review-word count | Longest streak, joined date, level rules and daily XP history are not exposed by existing contracts; chart has an unavailable state. |
| 13. Settings | No screen | Persisted appearance, working logout, license view and feature explainers | Notifications, sounds and reset operations are not added behind working-looking controls. |
| 14. Loading/error/offline | Existing loading and retry branches | Skeletons, Pip error states, retries and sync-unavailable banner | Static skeletons avoid perpetual animation. A sync failure is not treated as proof that internet connectivity is lost. |
| 14. Permissions | No feature requesting permissions | Informational mic/reminder sheets | No OS permission is requested for a feature that cannot use it yet. |
| Extra states | Reset password, missing route, save/rating errors | Restyled using shared visual language | These working states are retained even though the prototype lacks a dedicated frame. |

## Accessibility and motion

- 48 dp minimum touch areas; primary controls use a 52 dp minimum height.
- No text scaling clamp. Existing 320 dp/200% tests are preserved; new tests cover
  six routes plus onboarding, email-sent and sync-banner states at 360 dp/200% in light and dark.
- Enabled text colors are tested at >=4.5:1 for surface, canvas, muted, lime,
  accent, coral and success pairings. Selected chip colors are resolved and tested.
- Coral-on-cream and green-on-white text in the reference are replaced with
  readable ink; color remains in surfaces/icons with explicit status wording.
- Correct/wrong options expose semantic state; icon buttons have labels/tooltips.
- Button press: 120 ms scale; answer: 350 ms pop/shake; card: 550 ms perspective
  transition; streak: one 1.4 s pulse. Reduced motion removes these animations.
- Uppercase typography is not forced on arbitrary localized sentences or course
  content. The label scale/weight/tracking is provided by the theme.

## Localization and assets

English UI copy is centralized in lib/l10n/app_en.arb; ui_messages.g.dart is its
checked-in offline catalog. Generate it after editing the ARB:

```powershell
python tool/generate_ui_messages.py
dart format lib/core/localization/ui_messages.g.dart
```

The UI currently supports English, matching the native-language course. Course
text stays in course JSON. Existing domain error contracts remain unchanged;
known messages are translated at the presentation boundary. Additional UI locales
need a translated catalog and delegate locale registration, rather than changing
screen literals. No Tailwind/HTML/JS or reference WebP is bundled into the app.

## Validation and run commands

Final automated verification: 151 Flutter tests; clean analysis/formatting;
Android x86-64 debug APK build. The APK was installed and launched on the
Android emulator; Login rendered and empty submission produced both validation
messages. System UI/Pixel Launcher briefly stalled during low-memory emulator
boot; after the build daemon stopped and the launcher recovered, the app was
interactive and Flutter logs showed no app crash. UI tests also check Android tap-target and labeled
control guidelines. Three optional fixture-based screenshot capture tests cover
light/dark home, review, profile, settings, components and Login. Captures are
in ignored .dart_tool/lingoblob-previews. These are local widget previews, not
live Supabase account verification or an Android Accessibility Scanner report.

```powershell
cd C:\Langunge_flutter\myapp
flutter pub get
flutter test --dart-define-from-file=config.local.json
flutter analyze
flutter test test/support/capture_lingoblob.dart
flutter build apk --debug --target-platform android-x64 --dart-define-from-file=config.local.json
flutter emulators --launch Medium_Phone_API_37.0
flutter devices
flutter run -d emulator-5554 --dart-define-from-file=config.local.json
```

Use the actual device ID shown by flutter devices. After login/onboarding, open
Profile > Settings to switch appearance or open the debug gallery. Manually check
confirmation/recovery/Google callbacks with your configured Supabase project;
those services were not modified or live-verified by this UI task.

## Files created or edited for this UI task

Phase 6C files already present in the worktree are not listed as UI changes unless
this task edited their presentation/configuration. No commit or push was made.

| File | Change |
| --- | --- |
| [android/app/src/main/res/values/lingoblob_colors.xml](android/app/src/main/res/values/lingoblob_colors.xml) | Created |
| [android/app/src/main/res/values-night/lingoblob_colors.xml](android/app/src/main/res/values-night/lingoblob_colors.xml) | Created |
| [android/app/src/main/res/drawable/pip_splash.xml](android/app/src/main/res/drawable/pip_splash.xml) | Created |
| [android/app/src/main/res/values-v31/styles.xml](android/app/src/main/res/values-v31/styles.xml) | Created |
| [android/app/src/main/res/values-night-v31/styles.xml](android/app/src/main/res/values-night-v31/styles.xml) | Created |
| [android/app/src/main/res/drawable/launch_background.xml](android/app/src/main/res/drawable/launch_background.xml) | Edited |
| [android/app/src/main/res/drawable-v21/launch_background.xml](android/app/src/main/res/drawable-v21/launch_background.xml) | Edited |
| [android/app/src/main/res/values/styles.xml](android/app/src/main/res/values/styles.xml) | Edited |
| [android/app/src/main/res/values-night/styles.xml](android/app/src/main/res/values-night/styles.xml) | Edited |
| [README.md](README.md) | Edited |
| [config.example.json](config.example.json) | Edited |
| [lib/app/app.dart](lib/app/app.dart) | Edited |
| [lib/core/router/app_router.dart](lib/core/router/app_router.dart) | Edited |
| [lib/core/theme/app_theme.dart](lib/core/theme/app_theme.dart) | Edited |
| [lib/features/auth/presentation/auth_loading_screen.dart](lib/features/auth/presentation/auth_loading_screen.dart) | Edited |
| [lib/features/auth/presentation/auth_screens.dart](lib/features/auth/presentation/auth_screens.dart) | Edited |
| [lib/features/exercises/presentation/fill_in_blank_view.dart](lib/features/exercises/presentation/fill_in_blank_view.dart) | Edited |
| [lib/features/exercises/presentation/match_pairs_view.dart](lib/features/exercises/presentation/match_pairs_view.dart) | Edited |
| [lib/features/exercises/presentation/multiple_choice_view.dart](lib/features/exercises/presentation/multiple_choice_view.dart) | Edited |
| [lib/features/exercises/presentation/type_translation_view.dart](lib/features/exercises/presentation/type_translation_view.dart) | Edited |
| [lib/features/flashcards/presentation/review_empty_state.dart](lib/features/flashcards/presentation/review_empty_state.dart) | Edited |
| [lib/features/flashcards/presentation/review_rating_buttons.dart](lib/features/flashcards/presentation/review_rating_buttons.dart) | Edited |
| [lib/features/flashcards/presentation/review_screen.dart](lib/features/flashcards/presentation/review_screen.dart) | Edited |
| [lib/features/flashcards/presentation/review_session_screen.dart](lib/features/flashcards/presentation/review_session_screen.dart) | Edited |
| [lib/features/flashcards/presentation/review_summary.dart](lib/features/flashcards/presentation/review_summary.dart) | Edited |
| [lib/features/home/presentation/home_screen.dart](lib/features/home/presentation/home_screen.dart) | Edited |
| [lib/features/home/presentation/learn_screen.dart](lib/features/home/presentation/learn_screen.dart) | Edited |
| [lib/features/home/presentation/learning_path_view.dart](lib/features/home/presentation/learning_path_view.dart) | Edited |
| [lib/features/home/presentation/user_stats_bar.dart](lib/features/home/presentation/user_stats_bar.dart) | Edited |
| [lib/features/lessons/presentation/exercise_content.dart](lib/features/lessons/presentation/exercise_content.dart) | Edited |
| [lib/features/lessons/presentation/lesson_action_bar.dart](lib/features/lessons/presentation/lesson_action_bar.dart) | Edited |
| [lib/features/lessons/presentation/lesson_runner.dart](lib/features/lessons/presentation/lesson_runner.dart) | Edited |
| [lib/features/lessons/presentation/lesson_screen.dart](lib/features/lessons/presentation/lesson_screen.dart) | Edited |
| [lib/features/lessons/presentation/results_screen.dart](lib/features/lessons/presentation/results_screen.dart) | Edited |
| [lib/features/onboarding/presentation/daily_goal_screen.dart](lib/features/onboarding/presentation/daily_goal_screen.dart) | Edited |
| [lib/features/onboarding/presentation/language_screen.dart](lib/features/onboarding/presentation/language_screen.dart) | Edited |
| [lib/features/onboarding/presentation/onboarding_frame.dart](lib/features/onboarding/presentation/onboarding_frame.dart) | Edited |
| [lib/features/onboarding/presentation/startup_screen.dart](lib/features/onboarding/presentation/startup_screen.dart) | Edited |
| [lib/features/onboarding/presentation/welcome_screen.dart](lib/features/onboarding/presentation/welcome_screen.dart) | Edited |
| [lib/features/profile/presentation/profile_screen.dart](lib/features/profile/presentation/profile_screen.dart) | Edited |
| [lib/shared/widgets/answer_feedback_sheet.dart](lib/shared/widgets/answer_feedback_sheet.dart) | Edited |
| [lib/shared/widgets/answer_option.dart](lib/shared/widgets/answer_option.dart) | Edited |
| [lib/shared/widgets/async_status_view.dart](lib/shared/widgets/async_status_view.dart) | Edited |
| [lib/shared/widgets/choice_card.dart](lib/shared/widgets/choice_card.dart) | Edited |
| [lib/shared/widgets/flippable_flashcard.dart](lib/shared/widgets/flippable_flashcard.dart) | Edited |
| [lib/shared/widgets/lesson_path_node.dart](lib/shared/widgets/lesson_path_node.dart) | Edited |
| [lib/shared/widgets/lesson_status_header.dart](lib/shared/widgets/lesson_status_header.dart) | Edited |
| [lib/shared/widgets/password_field.dart](lib/shared/widgets/password_field.dart) | Edited |
| [lib/shared/widgets/placeholder_page.dart](lib/shared/widgets/placeholder_page.dart) | Edited |
| [lib/shared/widgets/responsive_body.dart](lib/shared/widgets/responsive_body.dart) | Edited |
| [lib/shared/widgets/stat_badge.dart](lib/shared/widgets/stat_badge.dart) | Edited |
| [pubspec.lock](pubspec.lock) | Edited |
| [pubspec.yaml](pubspec.yaml) | Edited |
| [test/auth_widget_test.dart](test/auth_widget_test.dart) | Edited |
| [test/review_widget_test.dart](test/review_widget_test.dart) | Edited |
| [test/widget_test.dart](test/widget_test.dart) | Edited |
| [LINGOBLOB_UI_IMPLEMENTATION.md](LINGOBLOB_UI_IMPLEMENTATION.md) | Created |
| [assets/fonts/OFL.txt](assets/fonts/OFL.txt) | Created |
| [assets/fonts/PlusJakartaSans-Bold.ttf](assets/fonts/PlusJakartaSans-Bold.ttf) | Created |
| [assets/fonts/PlusJakartaSans-ExtraBold.ttf](assets/fonts/PlusJakartaSans-ExtraBold.ttf) | Created |
| [assets/fonts/PlusJakartaSans-Medium.ttf](assets/fonts/PlusJakartaSans-Medium.ttf) | Created |
| [assets/fonts/PlusJakartaSans-Regular.ttf](assets/fonts/PlusJakartaSans-Regular.ttf) | Created |
| [assets/fonts/PlusJakartaSans-SemiBold.ttf](assets/fonts/PlusJakartaSans-SemiBold.ttf) | Created |
| [lib/core/localization/lingo_localizations.dart](lib/core/localization/lingo_localizations.dart) | Created |
| [lib/core/localization/ui_messages.g.dart](lib/core/localization/ui_messages.g.dart) | Created |
| [lib/core/theme/appearance_controller.dart](lib/core/theme/appearance_controller.dart) | Created |
| [lib/core/theme/lingo_font_license.dart](lib/core/theme/lingo_font_license.dart) | Created |
| [lib/core/theme/lingo_tokens.dart](lib/core/theme/lingo_tokens.dart) | Created |
| [lib/features/chat/presentation/chat_screen.dart](lib/features/chat/presentation/chat_screen.dart) | Created |
| [lib/features/dev/presentation/components_screen.dart](lib/features/dev/presentation/components_screen.dart) | Created |
| [lib/features/profile/presentation/profile_display_provider.dart](lib/features/profile/presentation/profile_display_provider.dart) | Created |
| [lib/features/settings/presentation/settings_screen.dart](lib/features/settings/presentation/settings_screen.dart) | Created |
| [lib/l10n/app_en.arb](lib/l10n/app_en.arb) | Created |
| [lib/shared/widgets/lingo_components.dart](lib/shared/widgets/lingo_components.dart) | Created |
| [lib/shared/widgets/pip_mascot.dart](lib/shared/widgets/pip_mascot.dart) | Created |
| [test/lingoblob_ui_test.dart](test/lingoblob_ui_test.dart) | Created |
| [test/support/capture_lingoblob.dart](test/support/capture_lingoblob.dart) | Created |
| [tool/generate_ui_messages.py](tool/generate_ui_messages.py) | Created |
