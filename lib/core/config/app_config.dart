import 'package:flutter_riverpod/flutter_riverpod.dart';

final appConfigProvider = Provider<AppConfig>((ref) => const AppConfig());

class AppConfig {
  const AppConfig({
    this.appName = const String.fromEnvironment(
      'APP_NAME',
      defaultValue: 'Language Learning',
    ),
    this.targetLanguage = const String.fromEnvironment('TARGET_LANGUAGE'),
    this.nativeLanguage = const String.fromEnvironment('NATIVE_LANGUAGE'),
  });

  final String appName;
  final String targetLanguage;
  final String nativeLanguage;

  bool get hasLanguagePair =>
      targetLanguage.trim().isNotEmpty && nativeLanguage.trim().isNotEmpty;
}
