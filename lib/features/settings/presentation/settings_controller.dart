import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/data/auth_repository.dart';
import '../../activity/data/activity_repository.dart';
import '../../notifications/data/reminder_service.dart';
import '../domain/practice_settings.dart';

final practiceSettingsProvider =
    AsyncNotifierProvider<PracticeSettingsController, PracticeSettings>(
      PracticeSettingsController.new,
    );

class PracticeSettingsController extends AsyncNotifier<PracticeSettings> {
  String _key = '';
  @override
  Future<PracticeSettings> build() async {
    final uid = ref.watch(authStateProvider).asData?.value?.id;
    _key = 'lingoblob.practice.${uid ?? 'signed-out'}';
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return const PracticeSettings();
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final hour = json['hour'] as int;
      final minute = json['minute'] as int;
      if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
        return const PracticeSettings();
      }
      return PracticeSettings(
        sound: json['sound'] == true,
        reminders: json['reminders'] == true,
        hour: hour,
        minute: minute,
      );
    } catch (_) {
      return const PracticeSettings();
    }
  }

  Future<void> setReminder(bool enabled) => _change((current) async {
    if (enabled &&
        !await ref.read(reminderServiceProvider).requestPermission()) {
      throw StateError(
        'Notification permission was not granted. Enable it in your device settings.',
      );
    }
    return current.copyWith(reminders: enabled);
  });
  Future<void> setTime(int hour, int minute) =>
      _change((s) async => s.copyWith(hour: hour, minute: minute));
  Future<void> setSound(bool enabled) =>
      _change((s) async => s.copyWith(sound: enabled));

  Future<void> _change(
    Future<PracticeSettings> Function(PracticeSettings) update,
  ) async {
    final current = state.asData?.value;
    if (current == null || current.saving) return;
    final key = _key;
    state = AsyncData(current.copyWith(saving: true));
    try {
      final next = await update(current);
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString(
        key,
        jsonEncode({
          'sound': next.sound,
          'reminders': next.reminders,
          'hour': next.hour,
          'minute': next.minute,
        }),
      )) {
        throw StateError('Your settings could not be saved. Try again.');
      }
      if (ref.mounted && key == _key) state = AsyncData(next);
    } catch (error) {
      if (ref.mounted && key == _key) {
        state = AsyncData(
          current.copyWith(
            error: error is StateError
                ? error.message
                : 'Your settings could not be saved. Try again.',
          ),
        );
      }
    }
  }

  Future<void> resetProgress() => _change((s) async {
    await ref.read(activityRepositoryProvider).reset();
    return s;
  });
}
