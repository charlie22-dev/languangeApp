# Phase 7: XP, streaks, notifications and settings

Phase 7 is implemented locally. Apply the additional Supabase migration below
before testing cloud synchronization with this build.

## Dashboard and run

In your existing Supabase project's SQL Editor, run the full contents of
[202611130001_phase7.sql](supabase/migrations/202611130001_phase7.sql).
It runs after the Phase 6C migration, preserves existing progress, and can be
run again. It adds `user_stats.longest_streak`, `word_progress.deleted`, and
`daily_activity` with per-user RLS, timestamp conflict protection, and delta sync.
It also updates `pull_progress` to include activity. No client/server secrets
need changing. Without this migration, local practice still works but the new
sync writes cannot succeed.

```powershell
cd C:\Langunge_flutter\myapp
flutter pub get
flutter run -d edge --web-port=7357 --dart-define-from-file=config.local.json
```

Keep your previous fixed browser port if it differs, so you retain that
origin's local data. Stop the previous Flutter run completely before running
this version. Test native reminders on an Android emulator or phone:

```powershell
flutter devices
flutter run -d emulator-5554 --dart-define-from-file=config.local.json
```

For a fresh clone, generate the ignored configuration asset with
`python tool/prepare_local_config.py` to also support plain `flutter run`.

## Behavior

- **Streaks:** successful lessons count as daily practice. The pure Dart `Streak`
  class compares calendar days already expressed in the user's local time zone.
  Same-day repeats do not increment; yesterday continues; a missed day resets
  the next practice to one. Calendar-day ordinals handle 23/25-hour DST days.
  Clock rollback or travel into an earlier date never grants another streak
  day. Expired current streaks display zero even before the next lesson.
- **XP goal:** existing lesson rewards stay unchanged. The explicit mapping is
  5/10/15 onboarding minutes to **25/50/75 XP**. Replays earn their normal XP.
  Failed lessons do not earn XP. Reviews retain their existing SM-2 behavior
  and do not award additional XP in this phase.
- **Atomic saves:** lesson completion, total XP, daily XP, streaks, longest
  streak and word enrollment commit together. Daily history uses local calendar
  date keys, while sync timestamps remain UTC.
- **Learn:** the ring reflects today's saved XP and a short Pip celebration
  appears when the target is reached. Reduced-motion preferences are respected.
- **Profile:** real account name (email prefix fallback), initial avatar, XP,
  current/longest streak, introduced words, and an accessible seven-day XP chart.
  Historical daily totals cannot be reconstructed from older total-XP values;
  daily history starts with this update. The longest streak starts at the
  largest previously known current streak and tracks future records.
- **Settings:** saved light/dark/system selection, per-account sound preference,
  opt-in reminder switch, local-time picker, logout and confirmed progress reset.
  Sound controls lesson system feedback sounds and reminder sound. Device/system
  mute settings still apply. Learning preferences and account details survive a
  progress reset.
- **Reset and sync:** reset writes newer zero-value records and word tombstones,
  preserving cursor/import metadata. It works offline and later syncs using the
  existing last-write-wins policy. Stale responses cannot resurrect the reset.
  Completing a lesson again can re-enroll its words with fresh SM-2 schedules.
  A genuinely newer edit on another device can still win under that policy.

## Notifications

Dependencies are `flutter_local_notifications` 23.0.1, `flutter_timezone` 5.1.1
and `timezone` 0.11.2. Android uses compile SDK 37, Java 17, core-library
desugaring, a monochrome notification icon and reboot/package-update receivers.
It uses **inexact alarms**, avoiding an unnecessary exact-alarm permission.
Android may deliver a little later to conserve battery.

There is no permission prompt on launch. In Settings, turn on **Daily reminder**,
read the explanation and choose **Enable reminders** to invoke the OS permission
dialog. Denial keeps the switch off with a useful error. Pick a time separately.
Today's pending reminder is cancelled when the goal is reached; future days
remain scheduled. Logout also cancels reminders.

Scheduling uses the device's IANA time zone and local calendar dates, not an
assumed UTC offset or fixed 24-hour durations. Launch/resume refreshes the plan
after travel. The rolling **28-day** window is below iOS's 64-pending-request
limit and is refreshed on launch, resume, preferences and activity changes.
If the app is not opened for 28 days, open it again to renew the window. This
allows skipping just today without iOS daily-repeat triggers re-including today.

Scheduled reminders are supported here on **Android and iOS**. Browser/desktop
Settings explain the limitation and disable scheduling; XP, goals, charts,
sound preferences and reset continue to work. Physical notification delivery
and iOS builds require testing on those devices; this Windows environment does
not provide an iOS toolchain.

## Test checklist

Verified in this workspace: **188 Flutter tests passed**, analyzer and formatting
clean, **6 Phase 7 SQL checks passed**, Android debug APK and web builds passed,
and the real Edge database check passed on both initial load and refresh.
Notification method-channel tests cover the actual plugin API calls using a
mock OS; physical delivery still needs the manual device check below.

```powershell
flutter analyze
flutter test
node supabase/tests/phase7_security.mjs
```

SQL tests use the existing ignored PGlite setup, never your cloud account:

```powershell
npm install --prefix .dart_tool/sqlcheck --no-save @electric-sql/pglite@0.5.15
node supabase/tests/phase7_security.mjs
```

The tests cover streak midnight, DST, calendar/year boundaries, rollback,
daily accumulation, longest streak, migration from schema 3, stale-sync reset
protection, new activity upserts, preference persistence/account isolation,
permission denial/opt-in, plugin scheduling, goal cancellation, logout, reset
confirmation and 360dp layouts at 200% text in both themes.

The real Edge database smoke check also passed after opening and refreshing
with persisted browser data. It now checks daily-activity persistence:

```powershell
flutter run -d edge -t tool/browser_database_smoke.dart --web-port=7358
```

Keep that test origin separate from your real app's port. It writes fixture data.

Manual acceptance:

1. Complete successful lessons and watch today's XP and the ring increase.
2. Reach the target and see Pip celebrate; check Profile's chart and streak.
3. Enable reminders on Android, grant permission, and choose a time a few minutes
   ahead. Test on a day when the goal is incomplete; complete the goal before
   another scheduled test and verify that today's pending alert is cancelled.
4. Toggle sound/theme and restart; check they persist. Revoke notification
   permission in OS Settings and test the explicit opt-in error.
5. On a test account, cancel the reset dialog once, then confirm it. Check XP,
   path, deck and chart; synchronize and reopen to verify the reset persists.

## UI changes

| Before | After | Why |
| --- | --- | --- |
| Time-target placeholder ring | Saved daily XP ring and finite celebration | Shows measurable progress against the chosen goal |
| Profile activity placeholder | Real seven-day chart and longest streak | Uses saved history without invented past activity |
| Pip as account avatar | Initial from the real account name | Identifies the account without adding remote image dependencies |
| Reminder and sound explainers | Permission opt-in, time picker and sound switch | Controls are now backed by saved preferences |
| Reset unavailable | Confirmation and synced reset records | Allows a reset while preserving account data and offline correctness |

The existing flat theme, borders, spacing, small-phone layouts and route paths
are retained. No chart or animation dependency was added.

## Files created

- `lib/features/activity/domain/streak.dart`
- `lib/features/activity/data/activity_repository.dart`
- `lib/features/activity/data/activity_providers.dart`
- `lib/features/activity/presentation/daily_goal_progress.dart`
- `lib/features/activity/presentation/activity_chart.dart`
- `lib/features/notifications/domain/reminder_plan.dart`
- `lib/features/notifications/data/reminder_service.dart`
- `lib/features/notifications/presentation/reminder_coordinator.dart`
- `lib/features/settings/domain/practice_settings.dart`
- `lib/features/settings/presentation/settings_controller.dart`
- `lib/features/settings/presentation/practice_settings_panel.dart`
- `android/app/src/main/res/drawable/ic_notification.xml`
- `supabase/migrations/202611130001_phase7.sql`
- `supabase/tests/phase7_security.mjs`
- `test/streak_test.dart`
- `test/reminder_plan_test.dart`
- `test/reminder_service_test.dart`
- `test/activity_repository_test.dart`
- `test/practice_settings_test.dart`
- `test/phase7_widget_test.dart`
- `test/support/reminder_fixtures.dart`
- `PHASE7_IMPLEMENTATION.md`

## Files updated

- `pubspec.yaml` and `pubspec.lock`
- `lib/app/app.dart`
- `lib/core/database/app_database.dart` and generated `app_database.g.dart`
- `lib/features/lessons/data/lesson_completion_repository.dart`
- `lib/features/flashcards/data/word_enrollment.dart` and `review_repository.dart`
- `lib/features/home/data/home_providers.dart`
- `lib/features/home/presentation/learning_path_view.dart`
- `lib/features/profile/presentation/profile_screen.dart` and `profile_display_provider.dart`
- `lib/features/settings/presentation/settings_screen.dart`
- `lib/features/sync/domain/sync_record.dart`
- `lib/features/sync/data/local_sync_store.dart` and `remote_sync_store.dart`
- `lib/shared/widgets/lingo_components.dart` and `answer_feedback_sheet.dart`
- `lib/l10n/app_en.arb` and generated `lib/core/localization/ui_messages.g.dart`
- `android/app/build.gradle.kts` and `android/app/src/main/AndroidManifest.xml`
- `ios/Runner/AppDelegate.swift`
- Generated plugin registrations: `linux/flutter/generated_plugin_registrant.cc`,
  `linux/flutter/generated_plugins.cmake`, `macos/Flutter/GeneratedPluginRegistrant.swift`,
  `windows/flutter/generated_plugin_registrant.cc`, `windows/flutter/generated_plugins.cmake`
- `test/account_database_test.dart`, `test/lesson_completion_repository_test.dart`,
  `test/remote_sync_store_test.dart`, `test/widget_test.dart`
- `tool/browser_database_smoke.dart`
- `README.md` and `SUPABASE_SETUP.md`
