import 'package:timezone/timezone.dart' as tz;

/// One-shot calendar reminders allow skipping just today without a repeating
/// iOS trigger accidentally firing again today. Refresh the 28-day window on
/// launch, resume, goal completion and preference changes (under iOS's 64 limit).
List<tz.TZDateTime> reminderPlan({
  required tz.TZDateTime now,
  required int hour,
  required int minute,
  required bool goalDoneToday,
}) {
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
    throw ArgumentError('Invalid reminder time');
  }
  return [
    for (var day = 0; day < 28; day++)
      if (!(day == 0 && goalDoneToday))
        tz.TZDateTime(
          now.location,
          now.year,
          now.month,
          now.day + day,
          hour,
          minute,
        ),
  ].where((date) => date.isAfter(now)).toList(growable: false);
}
