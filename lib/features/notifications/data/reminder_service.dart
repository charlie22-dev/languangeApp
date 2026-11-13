import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../../core/localization/ui_messages.g.dart';
import '../domain/reminder_plan.dart';

final reminderServiceProvider = Provider<ReminderService>(
  (ref) => ReminderService(),
);

class ReminderService {
  final _plugin = FlutterLocalNotificationsPlugin();
  Future<void>? _initialization;
  Future<void> _queue = Future.value();
  String? _lastPlan;
  bool get supported =>
      !kIsWeb &&
      {
        TargetPlatform.android,
        TargetPlatform.iOS,
      }.contains(defaultTargetPlatform);

  Future<void> _initialize() =>
      _initialization ??= _initializeOnce().catchError((Object error) {
        _initialization = null;
        throw error;
      });

  Future<void> _initializeOnce() async {
    tzdata.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
  }

  Future<bool> requestPermission() async {
    if (!supported) return false;
    await _initialize();
    if (defaultTargetPlatform == TargetPlatform.android) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission() ??
          false;
    }
    return await _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: false, sound: true) ??
        false;
  }

  /// Serializes reschedules so logout or goal completion wins over older work.
  Future<void> reconcile({
    required String? userId,
    required bool enabled,
    required int hour,
    required int minute,
    required bool sound,
    required bool goalDone,
    bool force = false,
  }) {
    final result = _queue.catchError((Object _) {}).then((_) async {
      if (!supported) return;
      await _initialize();
      final zone = await FlutterTimezone.getLocalTimezone();
      final location = tz.getLocation(zone.identifier);
      final now = tz.TZDateTime.now(location);
      final fingerprint =
          '$userId/$enabled/$hour/$minute/$sound/$goalDone/${zone.identifier}/${now.year}-${now.month}-${now.day}';
      if (!force && _lastPlan == fingerprint) return;
      _lastPlan = null;
      for (var id = 4000; id < 4028; id++) {
        await _plugin.cancel(id: id);
      }
      if (userId != null && enabled) {
        final dates = reminderPlan(
          now: now,
          hour: hour,
          minute: minute,
          goalDoneToday: goalDone,
        );
        for (var index = 0; index < dates.length; index++) {
          await _plugin.zonedSchedule(
            id: 4000 + index,
            title: uiMessages['reminderNotificationTitle'],
            body: uiMessages['reminderNotificationBody'],
            scheduledDate: dates[index],
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            notificationDetails: NotificationDetails(
              android: AndroidNotificationDetails(
                sound ? 'daily_practice_sound' : 'daily_practice_silent',
                uiMessages['dailyReminder']!,
                playSound: sound,
                enableVibration: sound,
                importance: Importance.defaultImportance,
              ),
              iOS: DarwinNotificationDetails(presentSound: sound),
            ),
          );
        }
      }
      _lastPlan = fingerprint;
    });
    _queue = result;
    return result;
  }
}
