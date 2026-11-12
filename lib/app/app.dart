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

class LanguageApp extends ConsumerWidget {
  const LanguageApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    LingoFontLicense.register();
    final config = ref.watch(appConfigProvider);
    ref.watch(syncServiceProvider);
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
    if (state == AppLifecycleState.resumed) {
      ref.read(syncServiceProvider)?.request();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
