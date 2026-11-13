import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myapp/features/auth/data/auth_repository.dart';
import 'package:myapp/features/auth/domain/auth_models.dart';
import 'package:myapp/features/settings/presentation/settings_controller.dart';
import 'package:myapp/features/notifications/data/reminder_service.dart';

import 'support/reminder_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<ProviderContainer> container(
    String user,
    TestReminderService service,
  ) async {
    final c = ProviderContainer(
      overrides: [
        authStateProvider.overrideWith(
          (ref) =>
              Stream.value(AuthIdentity(id: user, email: '$user@example.com')),
        ),
        reminderServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(c.dispose);
    c.listen(authStateProvider, (_, _) {});
    await c.read(authStateProvider.future);
    c.listen(practiceSettingsProvider, (_, _) {});
    await c.read(practiceSettingsProvider.future);
    return c;
  }

  test('sound, reminder and time persist only for their account', () async {
    final service = TestReminderService();
    final first = await container('a', service);
    final controller = first.read(practiceSettingsProvider.notifier);
    expect(service.permissionRequests, 0);
    await controller.setSound(false);
    await controller.setTime(22, 15);
    await controller.setReminder(true);
    final second = await container('a', service);
    final saved = second.read(practiceSettingsProvider).asData!.value;
    expect(saved.sound, isFalse);
    expect(saved.reminders, isTrue);
    expect(saved.hour, 22);
    expect(saved.minute, 15);
    final other = await container('b', service);
    expect(other.read(practiceSettingsProvider).asData!.value.sound, isTrue);
    expect(
      other.read(practiceSettingsProvider).asData!.value.reminders,
      isFalse,
    );
  });
  test(
    'permission denial keeps reminders disabled and shows an actionable error',
    () async {
      final service = TestReminderService()..allowed = false;
      final c = await container('a', service);
      await c.read(practiceSettingsProvider.notifier).setReminder(true);
      final state = c.read(practiceSettingsProvider).asData!.value;
      expect(state.reminders, isFalse);
      expect(state.error, contains('permission'));
    },
  );
}
