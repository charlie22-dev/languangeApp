import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:myapp/features/notifications/data/reminder_service.dart';
import 'package:timezone/timezone.dart' as tz;

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const notifications = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );
  const timezone = MethodChannel('flutter_timezone');
  late List<MethodCall> calls;
  setUp(() {
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    calls = [];
    binding.defaultBinaryMessenger.setMockMethodCallHandler(notifications, (
      call,
    ) async {
      calls.add(call);
      return {
            'initialize',
            'requestNotificationsPermission',
          }.contains(call.method)
          ? true
          : null;
    });
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      timezone,
      (call) async => 'Asia/Manila',
    );
  });
  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      notifications,
      null,
    );
    binding.defaultBinaryMessenger.setMockMethodCallHandler(timezone, null);
  });
  test('real plugin scheduling uses the device zone, skips today, and cancels on logout', () async {
    final service = ReminderService();
    await service.reconcile(
      userId: 'a',
      enabled: true,
      hour: 23,
      minute: 59,
      sound: true,
      goalDone: false,
    );
    final schedules = calls.where((c) => c.method == 'zonedSchedule').toList();
    expect(schedules.length, inInclusiveRange(27, 28));
    expect(
      calls.any((c) => c.method == 'requestNotificationsPermission'),
      isFalse,
    );
    expect((schedules.first.arguments as Map)['timeZoneName'], 'Asia/Manila');
    calls.clear();
    await service.reconcile(
      userId: 'a',
      enabled: true,
      hour: 23,
      minute: 59,
      sound: false,
      goalDone: true,
    );
    final today = tz.TZDateTime.now(tz.getLocation('Asia/Manila'));
    for (final call in calls.where((c) => c.method == 'zonedSchedule')) {
      final date = DateTime.parse(
        (call.arguments as Map)['scheduledDateTime'] as String,
      );
      expect(
        date.day == today.day &&
            date.month == today.month &&
            date.year == today.year,
        isFalse,
      );
      expect(
        ((call.arguments as Map)['platformSpecifics'] as Map)['playSound'],
        isFalse,
      );
    }
    calls.clear();
    await service.reconcile(
      userId: null,
      enabled: false,
      hour: 23,
      minute: 59,
      sound: false,
      goalDone: true,
    );
    expect(calls.where((c) => c.method == 'cancel').length, 28);
    expect(calls.any((c) => c.method == 'zonedSchedule'), isFalse);
  });
  test('permission is requested only through the opt-in method', () async {
    expect(await ReminderService().requestPermission(), isTrue);
    expect(
      calls.where((c) => c.method == 'requestNotificationsPermission').length,
      1,
    );
  });
}
