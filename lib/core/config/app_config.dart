import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

final appConfigProvider = Provider<AppConfig>((ref) {
  const compiled = AppConfig();
  final local = dotenv.isInitialized ? dotenv.env : const <String, String>{};
  return AppConfig(
    appName: const String.fromEnvironment('APP_NAME').isNotEmpty
        ? compiled.appName
        : local['APP_NAME'] ?? compiled.appName,
    targetLanguage: compiled.targetLanguage.isNotEmpty
        ? compiled.targetLanguage
        : local['TARGET_LANGUAGE'] ?? '',
    nativeLanguage: compiled.nativeLanguage.isNotEmpty
        ? compiled.nativeLanguage
        : local['NATIVE_LANGUAGE'] ?? '',
  );
});

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
