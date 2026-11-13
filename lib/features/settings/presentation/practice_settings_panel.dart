import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/lingo_localizations.dart';
import '../../../core/theme/lingo_tokens.dart';
import '../../../shared/widgets/lingo_components.dart';
import '../../notifications/data/reminder_service.dart';
import '../../notifications/presentation/reminder_coordinator.dart';
import 'settings_controller.dart';

class PracticeSettingsPanel extends ConsumerWidget {
  const PracticeSettingsPanel({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(practiceSettingsProvider.notifier);
    final supported = ref.watch(reminderServiceProvider).supported;
    final reminder = ref.watch(reminderCoordinatorProvider);
    return ref
        .watch(practiceSettingsProvider)
        .when(
          loading: () => const LingoSkeleton(),
          error: (error, stack) => LingoButton.outlined(
            onPressed: () => ref.invalidate(practiceSettingsProvider),
            child: Text(context.l10n.text('settingsRetry')),
          ),
          data: (settings) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LingoPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(context.l10n.text('dailyReminder')),
                      value: settings.reminders,
                      onChanged: !supported || settings.saving
                          ? null
                          : (enabled) async {
                              if (enabled) {
                                final accepted = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text(
                                      context.l10n.text(
                                        'reminderPermissionTitle',
                                      ),
                                    ),
                                    content: Text(
                                      context.l10n.text(
                                        'reminderPermissionBody',
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: Text(
                                          context.l10n.text('notNow'),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: Text(
                                          context.l10n.text('enableReminders'),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                                if (accepted != true) return;
                              }
                              await controller.setReminder(enabled);
                            },
                    ),
                    if (!supported)
                      Text(context.l10n.text('mobileRemindersOnly')),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(context.l10n.text('reminderTime')),
                      subtitle: Text(
                        TimeOfDay(
                          hour: settings.hour,
                          minute: settings.minute,
                        ).format(context),
                      ),
                      trailing: const Icon(Icons.schedule),
                      onTap: !supported || settings.saving
                          ? null
                          : () async {
                              final time = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay(
                                  hour: settings.hour,
                                  minute: settings.minute,
                                ),
                              );
                              if (time != null) {
                                await controller.setTime(
                                  time.hour,
                                  time.minute,
                                );
                              }
                            },
                    ),
                    Text(context.l10n.text('reminderGoalSkip')),
                    if (reminder.hasError) ...[
                      Text(context.l10n.text('reminderScheduleError')),
                      LingoButton.ghost(
                        onPressed: () =>
                            ref.invalidate(reminderCoordinatorProvider),
                        child: Text(context.l10n.text('settingsRetry')),
                      ),
                    ],
                  ],
                ),
              ),
              LingoPanel(
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.l10n.text('soundEffects')),
                  value: settings.sound,
                  onChanged: settings.saving ? null : controller.setSound,
                ),
              ),
              if (settings.error != null)
                Semantics(
                  liveRegion: true,
                  child: Text(context.l10n.message(settings.error!)),
                ),
              const SizedBox(height: LingoSpace.s16),
              LingoButton.outlined(
                onPressed: settings.saving
                    ? null
                    : () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text(
                              context.l10n.text('resetProgressTitle'),
                            ),
                            content: Text(
                              context.l10n.text('resetProgressBody'),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: Text(context.l10n.text('cancelAction')),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: Text(
                                  context.l10n.text('resetProgressAction'),
                                ),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) await controller.resetProgress();
                      },
                child: Text(context.l10n.text('resetProgressAction')),
              ),
              const SizedBox(height: LingoSpace.s16),
            ],
          ),
        );
  }
}
