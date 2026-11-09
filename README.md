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
This directory currently has no Git repository; initialize one when ready.
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

Keep app_database.g.dart with the source, and do not edit it manually. Schema
version is 1; later schema changes will need a version bump and a migration.
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
