import 'dart:async';

import '../features/audio/data/audio_service.dart';
import '../features/audio/data/speech_service.dart';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/theme/appearance_controller.dart';
import '../core/localization/lingo_localizations.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../core/router/app_router.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/lingo_font_license.dart';
import '../features/sync/presentation/sync_providers.dart';
import '../features/notifications/presentation/reminder_coordinator.dart';
import '../features/activity/data/activity_providers.dart';

class LanguageApp extends ConsumerWidget {
  const LanguageApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    LingoFontLicense.register();
    final config = ref.watch(appConfigProvider);
    ref.watch(syncServiceProvider);
    ref.watch(reminderCoordinatorProvider);
    return MaterialApp.router(
      title: config.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(appearanceProvider).mode,
      localizationsDelegates: const [
        LingoLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: LingoLocalizations.supportedLocales,
      routerConfig: ref.watch(appRouterProvider),
      builder: (context, child) => _SyncLifecycle(child: child!),
    );
  }
}

class _SyncLifecycle extends ConsumerStatefulWidget {
  const _SyncLifecycle({required this.child});
  final Widget child;
  @override
  ConsumerState<_SyncLifecycle> createState() => _SyncLifecycleState();
}

class _SyncLifecycleState extends ConsumerState<_SyncLifecycle>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      if (ref.read(audioServiceProvider.exists)) {
        unawaited(ref.read(audioServiceProvider).stop());
      }
      if (ref.read(speechServiceProvider.exists)) {
        unawaited(ref.read(speechServiceProvider).cancel());
      }
    }
    if (state == AppLifecycleState.resumed) {
      ref.read(syncServiceProvider)?.request();
      ref.invalidate(localTodayProvider);
      ref.invalidate(reminderCoordinatorProvider);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
