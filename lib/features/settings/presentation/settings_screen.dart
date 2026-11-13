import 'practice_settings_panel.dart';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/appearance_controller.dart';
import '../../../core/config/app_config.dart';
import '../../../core/theme/lingo_tokens.dart';
import '../../../core/localization/lingo_localizations.dart';
import '../../../shared/widgets/responsive_body.dart';
import '../../../shared/widgets/lingo_components.dart';
import '../../../shared/widgets/pip_mascot.dart';
import '../../auth/presentation/account_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(appearanceProvider);
    final action = ref.watch(accountControllerProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.text('settings'))),
      body: ResponsiveBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: PipMascot(mood: PipMood.thinking)),
            const SizedBox(height: LingoSpace.s24),
            LingoPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    context.l10n.text('appearance'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: LingoSpace.s16),
                  RadioGroup<ThemeMode>(
                    groupValue: appearance.mode,
                    onChanged: (value) {
                      if (value != null) {
                        ref.read(appearanceProvider.notifier).select(value);
                      }
                    },
                    child: Column(
                      children: [
                        for (final mode in ThemeMode.values)
                          RadioListTile<ThemeMode>(
                            title: Text(context.l10n.text(mode.name)),
                            value: mode,
                          ),
                      ],
                    ),
                  ),
                  if (appearance.error)
                    Text(context.l10n.text('settingsSaveError')),
                ],
              ),
            ),
            const PracticeSettingsPanel(),
            if (action.error != null) Text(context.l10n.message(action.error!)),
            LingoButton.tonal(
              onPressed: action.busy
                  ? null
                  : ref.read(accountControllerProvider.notifier).signOut,
              child: Text(
                context.l10n.text(action.busy ? 'signingOut' : 'logOut'),
              ),
            ),
            const SizedBox(height: LingoSpace.s16),
            if (kDebugMode)
              LingoButton.outlined(
                onPressed: () => context.push('/dev/components'),
                child: Text(context.l10n.text('components')),
              ),
            LingoButton.ghost(
              onPressed: () => showLicensePage(
                context: context,
                applicationName: ref.read(appConfigProvider).appName,
              ),
              child: Text(context.l10n.text('licenses')),
            ),
          ],
        ),
      ),
    );
  }
}
