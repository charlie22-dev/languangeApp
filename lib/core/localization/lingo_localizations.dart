import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'ui_messages.g.dart';

/// English UI catalog generated from lib/l10n/app_en.arb. Course text is data.
class LingoLocalizations {
  const LingoLocalizations(this.locale);
  final Locale locale;
  static const delegate = _LingoDelegate();
  static const supportedLocales = [Locale('en')];
  String text(String key, [Map<String, Object?> values = const {}]) {
    var message = uiMessages[key] ?? key;
    for (final entry in values.entries) {
      message = message.replaceAll('{${entry.key}}', '${entry.value}');
    }
    return message;
  }

  /// Preserve existing domain error messages; known messages can be translated
  /// at this presentation boundary without changing provider contracts.
  String? validation(String? value) => value == null ? null : message(value);
  String message(String value) => uiMessages[value] ?? value;
}

class _LingoDelegate extends LocalizationsDelegate<LingoLocalizations> {
  const _LingoDelegate();
  @override
  bool isSupported(Locale locale) => locale.languageCode == 'en';
  @override
  Future<LingoLocalizations> load(Locale locale) =>
      SynchronousFuture(LingoLocalizations(locale));
  @override
  bool shouldReload(_LingoDelegate old) => false;
}

extension LingoStringsContext on BuildContext {
  LingoLocalizations get l10n =>
      Localizations.of<LingoLocalizations>(this, LingoLocalizations) ??
      const LingoLocalizations(Locale('en'));
}
