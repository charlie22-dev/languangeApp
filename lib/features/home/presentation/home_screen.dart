import 'dart:async';

import '../../audio/data/audio_service.dart';
import '../../audio/data/speech_service.dart';
import '../../../core/theme/lingo_tokens.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sync/presentation/sync_providers.dart';
import '../../sync/data/sync_service.dart';
import '../../../core/localization/lingo_localizations.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Column(
        children: [
          if (ref.watch(syncStatusProvider) == SyncStatus.offline)
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.all(LingoSpace.s8),
                child: Text(
                  context.l10n.text('syncPaused'),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          Expanded(child: navigationShell),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.outline,
              width: LingoSpace.border,
            ),
          ),
        ),
        child: NavigationBar(
          height:
              LingoSpace.node +
              (MediaQuery.textScalerOf(context).scale(
                        Theme.of(context).textTheme.labelLarge!.fontSize!,
                      ) -
                      Theme.of(context).textTheme.labelLarge!.fontSize!) *
                  2,
          selectedIndex: [0, 1, 3, 2].indexOf(navigationShell.currentIndex),
          onDestinationSelected: (index) {
            if (ref.read(audioServiceProvider.exists)) {
              unawaited(ref.read(audioServiceProvider).stop());
            }
            if (ref.read(speechServiceProvider.exists)) {
              unawaited(ref.read(speechServiceProvider).cancel());
            }
            navigationShell.goBranch([0, 1, 3, 2][index]);
          },
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.school_outlined),
              selectedIcon: const Icon(Icons.school),
              label: context.l10n.text('uib048378ee8'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.style_outlined),
              selectedIcon: const Icon(Icons.style),
              label: context.l10n.text('uie29a79fe0c'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.chat_bubble_outline),
              selectedIcon: const Icon(Icons.chat_bubble),
              label: context.l10n.text('ui2ced57f125'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.person_outline),
              selectedIcon: const Icon(Icons.person),
              label: context.l10n.text('uiff4fc0276e'),
            ),
          ],
        ),
      ),
    );
  }
}
