import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const seedColor = Color(0xFF426B50);

  static final light = _build(Brightness.light);
  static final dark = _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final colors = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );
    final base = ThemeData(useMaterial3: true, colorScheme: colors);

    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        headlineMedium: base.textTheme.headlineMedium!.copyWith(
          fontWeight: FontWeight.w700,
        ),
        titleLarge: base.textTheme.titleLarge!.copyWith(
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: base.textTheme.bodyLarge!.copyWith(height: 1.5),
        bodyMedium: base.textTheme.bodyMedium!.copyWith(height: 1.5),
      ),
      appBarTheme: const AppBarTheme(centerTitle: false),
    );
  }
}
