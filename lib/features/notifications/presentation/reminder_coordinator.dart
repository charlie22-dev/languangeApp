import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../activity/data/activity_providers.dart';
import '../../auth/data/auth_repository.dart';
import '../../settings/presentation/settings_controller.dart';
import '../data/reminder_service.dart';

final reminderCoordinatorProvider = FutureProvider<void>((ref) async {
  final auth = ref.watch(authStateProvider).asData?.value;
  final settings = ref.watch(practiceSettingsProvider).asData?.value;
  final summary = ref.watch(activitySummaryProvider).asData?.value;
  if (auth != null &&
      (settings == null || summary == null || settings.saving)) {
    return;
  }
  await ref
      .watch(reminderServiceProvider)
      .reconcile(
        userId: auth?.id,
        enabled: settings?.reminders ?? false,
        hour: settings?.hour ?? 19,
        minute: settings?.minute ?? 0,
        sound: settings?.sound ?? true,
        goalDone: summary?.goalDone ?? false,
      );
}, retry: (count, error) => null);
