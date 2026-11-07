import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/utils/json_reader.dart';
import '../domain/onboarding_settings.dart';

final onboardingRepositoryProvider = Provider<OnboardingRepository>(
  (ref) => OnboardingRepository(SharedPreferencesAsync()),
);

class OnboardingRepository {
  const OnboardingRepository(this.preferences);

  static const storageKey = 'onboarding.v1';
  final SharedPreferencesAsync preferences;

  Future<OnboardingSettings?> load() async {
    final value = await preferences.getString(storageKey);
    if (value == null) return null;
    try {
      return OnboardingSettings.fromJson(
        JsonReader.object(jsonDecode(value), 'onboarding'),
      );
    } on FormatException {
      // An interrupted or obsolete settings document starts onboarding again.
      return null;
    }
  }

  Future<void> save(OnboardingSettings settings) =>
      preferences.setString(storageKey, jsonEncode(settings.toJson()));
}
