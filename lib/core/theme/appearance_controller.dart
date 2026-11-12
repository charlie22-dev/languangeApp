import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final appearanceProvider =
    NotifierProvider<AppearanceController, AppearanceState>(
      AppearanceController.new,
    );

@immutable
class AppearanceState {
  const AppearanceState({this.mode = ThemeMode.system, this.error = false});
  final ThemeMode mode;
  final bool error;
}

/// Device-only presentation preference, separate from learning/account settings.
class AppearanceController extends Notifier<AppearanceState> {
  static const key = 'lingoblob.themeMode';
  int _generation = 0;
  Future<void> _pending = Future.value();
  late final Future<void> restored;
  @override
  AppearanceState build() {
    restored = _restore();
    unawaited(restored);
    return const AppearanceState();
  }

  Future<void> _restore() async {
    final generation = _generation;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(key);
      final mode = ThemeMode.values.where((m) => m.name == saved).firstOrNull;
      if (ref.mounted && generation == _generation && mode != null) {
        state = AppearanceState(mode: mode);
      }
    } catch (_) {
      // Platform preferences may be unavailable in previews; default to system.
    }
  }

  Future<void> select(ThemeMode mode) {
    _generation++;
    state = AppearanceState(mode: mode);
    _pending = _pending.then((_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        if (!await prefs.setString(key, mode.name)) {
          throw StateError('Preference write failed');
        }
      } catch (_) {
        if (ref.mounted && state.mode == mode) {
          state = AppearanceState(mode: mode, error: true);
        }
      }
    });
    return _pending;
  }
}
