import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/features/notifications/domain/reminder_plan.dart';
import 'package:timezone/data/latest.dart' as data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(data.initializeTimeZones);
  test(
    'includes today before reminder time and stays below iOS pending limit',
    () {
      final zone = tz.getLocation('Asia/Manila');
      final plan = reminderPlan(
        now: tz.TZDateTime(zone, 2026, 11, 13, 10),
        hour: 19,
        minute: 30,
        goalDoneToday: false,
      );
      expect(plan.length, 28);
      expect(plan.first, tz.TZDateTime(zone, 2026, 11, 13, 19, 30));
    },
  );
  test('goal completed today skips only today', () {
    final zone = tz.getLocation('Asia/Manila');
    final plan = reminderPlan(
      now: tz.TZDateTime(zone, 2026, 11, 13, 10),
      hour: 19,
      minute: 30,
      goalDoneToday: true,
    );
    expect(plan.length, 27);
    expect(plan.first.day, 14);
  });
  test('passed reminder time never schedules in the past', () {
    final zone = tz.getLocation('Asia/Manila');
    final now = tz.TZDateTime(zone, 2026, 11, 13, 20);
    final plan = reminderPlan(
      now: now,
      hour: 19,
      minute: 30,
      goalDoneToday: false,
    );
    expect(plan.first.day, 14);
    expect(plan.every((d) => d.isAfter(now)), isTrue);
  });
  test('local reminder hour survives DST rather than shifting by an hour', () {
    final zone = tz.getLocation('America/New_York');
    final plan = reminderPlan(
      now: tz.TZDateTime(zone, 2026, 3, 7, 10),
      hour: 19,
      minute: 30,
      goalDoneToday: false,
    );
    expect(plan.every((d) => d.hour == 19 && d.minute == 30), isTrue);
    expect(plan[1].difference(plan[0]).inHours, 23);
  });
  test('invalid time rejected', () {
    expect(
      () => reminderPlan(
        now: tz.TZDateTime(tz.UTC, 2026),
        hour: 24,
        minute: 0,
        goalDoneToday: false,
      ),
      throwsArgumentError,
    );
  });
}
