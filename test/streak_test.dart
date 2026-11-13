import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/features/activity/domain/streak.dart';
import 'package:timezone/data/latest.dart' as data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(data.initializeTimeZones);
  test('first practice starts a streak', () {
    final change = Streak.evaluate(
      lastActiveDate: null,
      today: DateTime(2026, 11, 13),
    );
    expect(change, StreakChange.resets);
    expect(Streak.next(0, change), 1);
  });
  test('same-day repeats never increment', () {
    final change = Streak.evaluate(
      lastActiveDate: DateTime(2026, 11, 13, 1),
      today: DateTime(2026, 11, 13, 23),
    );
    expect(change, StreakChange.unchanged);
    expect(Streak.next(8, change), 8);
  });
  test('a minute across midnight continues', () {
    final change = Streak.evaluate(
      lastActiveDate: DateTime(2026, 11, 12, 23, 59),
      today: DateTime(2026, 11, 13),
    );
    expect(change, StreakChange.continues);
    expect(Streak.next(8, change), 9);
  });
  test('a missed day resets', () {
    final change = Streak.evaluate(
      lastActiveDate: DateTime(2026, 11, 11),
      today: DateTime(2026, 11, 13),
    );
    expect(change, StreakChange.resets);
    expect(Streak.next(8, change), 1);
  });
  test('year boundary continues', () {
    expect(
      Streak.evaluate(
        lastActiveDate: DateTime(2026, 12, 31),
        today: DateTime(2027, 1, 1),
      ),
      StreakChange.continues,
    );
  });
  test('spring DST day has 23 hours but still continues', () {
    final zone = tz.getLocation('America/New_York');
    final before = tz.TZDateTime(zone, 2026, 3, 8);
    final after = tz.TZDateTime(zone, 2026, 3, 9);
    expect(after.difference(before).inHours, 23);
    expect(
      Streak.evaluate(lastActiveDate: before, today: after),
      StreakChange.continues,
    );
  });
  test('autumn DST day has 25 hours but still continues', () {
    final zone = tz.getLocation('America/New_York');
    final before = tz.TZDateTime(zone, 2026, 11, 1);
    final after = tz.TZDateTime(zone, 2026, 11, 2);
    expect(after.difference(before).inHours, 25);
    expect(
      Streak.evaluate(lastActiveDate: before, today: after),
      StreakChange.continues,
    );
  });
  test('UTC midnight does not create a second local day', () {
    final zone = tz.getLocation('Asia/Manila');
    final before = tz.TZDateTime.from(DateTime.utc(2026, 11, 12, 23), zone);
    final after = tz.TZDateTime.from(DateTime.utc(2026, 11, 13, 1), zone);
    expect(
      Streak.evaluate(lastActiveDate: before, today: after),
      StreakChange.unchanged,
    );
  });
  test(
    'clock rollback or westward date-line travel does not increment/reset',
    () {
      expect(
        Streak.evaluate(
          lastActiveDate: DateTime(2026, 11, 14),
          today: DateTime(2026, 11, 13),
        ),
        StreakChange.unchanged,
      );
    },
  );
  test('expired streak is visibly zero before another lesson', () {
    expect(
      Streak.visible(8, DateTime(2026, 11, 11), DateTime(2026, 11, 13)),
      0,
    );
    expect(
      Streak.visible(8, DateTime(2026, 11, 12), DateTime(2026, 11, 13)),
      8,
    );
  });
  test('goal mapping is explicit', () {
    expect([5, 10, 15].map(dailyXpTarget), [25, 50, 75]);
  });
}
