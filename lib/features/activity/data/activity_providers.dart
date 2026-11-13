import 'dart:async';
import 'dart:math';

import 'package:drift/drift.dart' show Variable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/clock.dart';
import '../../onboarding/presentation/onboarding_controller.dart';
import '../domain/streak.dart';

final localTodayProvider = Provider<DateTime>((ref) {
  final now = ref.watch(clockProvider)().toLocal();
  final next = DateTime(now.year, now.month, now.day + 1);
  final timer = Timer(next.difference(now), ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return now;
});

class ActivitySummary {
  const ActivitySummary({
    required this.todayXp,
    required this.target,
    required this.streak,
    required this.longestStreak,
    required this.days,
    required this.xpByDay,
  });
  final int todayXp, target, streak, longestStreak;
  final List<DateTime> days;
  final List<int> xpByDay;
  bool get goalDone => todayXp >= target;
  double get fraction => (todayXp / target).clamp(0, 1);
}

final activitySummaryProvider = StreamProvider<ActivitySummary>((ref) {
  final today = ref.watch(localTodayProvider);
  final goal = ref.watch(onboardingProvider).asData?.value?.goalMinutes ?? 10;
  final db = ref.watch(appDatabaseProvider);
  final days = List.generate(
    7,
    (i) => DateTime(today.year, today.month, today.day - 6 + i),
  );
  return db
      .customSelect(
        '''SELECT s.*, a.activity_date, a.xp AS day_xp FROM user_stats s
    LEFT JOIN daily_activities a ON a.activity_date >= ? AND a.activity_date <= ?''',
        variables: [
          Variable.withString(dayKey(days.first)),
          Variable.withString(dayKey(today)),
        ],
        readsFrom: {db.userStats, db.dailyActivities},
      )
      .watch()
      .map((rows) {
        final first = rows.first;
        final xp = {
          for (final r in rows)
            if (r.readNullable<String>('activity_date') != null)
              r.read<String>('activity_date'): r.read<int>('day_xp'),
        };
        final active = first.readNullable<DateTime>('last_active_date');
        final streak = first.read<int>('streak');
        return ActivitySummary(
          todayXp: xp[dayKey(today)] ?? 0,
          target: dailyXpTarget(goal),
          streak: Streak.visible(streak, active?.toLocal(), today),
          longestStreak: max(streak, first.read<int>('longest_streak')),
          days: days,
          xpByDay: [for (final day in days) xp[dayKey(day)] ?? 0],
        );
      });
});
