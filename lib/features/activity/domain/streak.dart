enum StreakChange { continues, unchanged, resets }

/// Both dates must already be expressed in the user's current local time zone.
/// Calendar-day ordinals avoid 23/25-hour DST days affecting the streak.
abstract final class Streak {
  static StreakChange evaluate({
    required DateTime? lastActiveDate,
    required DateTime today,
  }) {
    if (lastActiveDate == null) return StreakChange.resets;
    final difference = calendarDay(today)
        .difference(calendarDay(lastActiveDate))
        .inDays;
    // Clock rollback / travel into an earlier calendar day never awards a second day.
    if (difference <= 0) return StreakChange.unchanged;
    return difference == 1 ? StreakChange.continues : StreakChange.resets;
  }

  static int next(int current, StreakChange change) => switch (change) {
    StreakChange.continues => current + 1,
    StreakChange.unchanged => current == 0 ? 1 : current,
    StreakChange.resets => 1,
  };

  static int visible(int current, DateTime? lastActiveLocal, DateTime today) {
    if (lastActiveLocal == null) return 0;
    return calendarDay(today).difference(calendarDay(lastActiveLocal)).inDays >
            1
        ? 0
        : current;
  }
}

DateTime calendarDay(DateTime date) =>
    DateTime.utc(date.year, date.month, date.day);
String dayKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

/// Onboarding's time goal is represented by five XP per selected minute.
int dailyXpTarget(int minutes) => minutes * 5;
