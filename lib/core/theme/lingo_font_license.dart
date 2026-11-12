import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

abstract final class LingoFontLicense {
  static bool _registered = false;
  static void register() {
    if (_registered) return;
    _registered = true;
    LicenseRegistry.addLicense(() async* {
      yield LicenseEntryWithLineBreaks([
        'Plus Jakarta Sans',
      ], await rootBundle.loadString('assets/fonts/OFL.txt'));
    });
  }
}
