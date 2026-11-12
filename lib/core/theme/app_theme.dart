import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'lingo_tokens.dart';

abstract final class AppTheme {
  static const seedColor = LingoPalette.lime;
  static final light = _build(Brightness.light);
  static final dark = _build(Brightness.dark);
  static ThemeData _build(Brightness brightness) {
    GoogleFonts.config.allowRuntimeFetching = false;
    final dark = brightness == Brightness.dark;
    final surface = dark ? LingoPalette.darkSurface : LingoPalette.white;
    final canvas = dark ? LingoPalette.night : LingoPalette.cream;
    final alt = dark ? LingoPalette.darkAlt : LingoPalette.sand;
    final text = dark ? LingoPalette.cream : LingoPalette.ink;
    final border = dark ? LingoPalette.darkBorder : LingoPalette.ink;
    final muted = dark ? LingoPalette.darkMuted : LingoPalette.muted;
    final disabled = dark ? LingoPalette.darkDisabled : LingoPalette.disabled;
    final colors = ColorScheme(
      brightness: brightness,
      primary: LingoPalette.lime,
      onPrimary: LingoPalette.ink,
      primaryContainer: LingoPalette.lime,
      onPrimaryContainer: LingoPalette.ink,
      primaryFixed: LingoPalette.lime,
      primaryFixedDim: LingoPalette.pressed,
      onPrimaryFixed: LingoPalette.ink,
      onPrimaryFixedVariant: LingoPalette.ink,
      secondary: LingoPalette.accent,
      onSecondary: LingoPalette.ink,
      secondaryContainer: LingoPalette.accent,
      onSecondaryContainer: LingoPalette.ink,
      secondaryFixed: LingoPalette.accent,
      secondaryFixedDim: LingoPalette.accent,
      onSecondaryFixed: LingoPalette.ink,
      onSecondaryFixedVariant: LingoPalette.ink,
      tertiary: LingoPalette.green,
      onTertiary: LingoPalette.ink,
      tertiaryContainer: LingoPalette.green,
      onTertiaryContainer: LingoPalette.ink,
      tertiaryFixed: LingoPalette.green,
      tertiaryFixedDim: LingoPalette.green,
      onTertiaryFixed: LingoPalette.ink,
      onTertiaryFixedVariant: LingoPalette.ink,
      error: LingoPalette.coral,
      onError: LingoPalette.ink,
      errorContainer: LingoPalette.coral,
      onErrorContainer: LingoPalette.ink,
      surface: surface,
      onSurface: text,
      onSurfaceVariant: muted,
      surfaceDim: canvas,
      surfaceBright: surface,
      surfaceContainerLowest: canvas,
      surfaceContainerLow: surface,
      surfaceContainer: surface,
      surfaceContainerHigh: alt,
      surfaceContainerHighest: alt,
      outline: border,
      outlineVariant: border,
      inverseSurface: dark ? LingoPalette.cream : LingoPalette.ink,
      onInverseSurface: dark ? LingoPalette.ink : LingoPalette.cream,
      inversePrimary: LingoPalette.lime,
      shadow: LingoPalette.clear,
      scrim: LingoPalette.ink.withValues(alpha: .5),
      surfaceTint: LingoPalette.clear,
    );
    TextStyle type(
      double size,
      double line,
      FontWeight weight, [
      double spacing = 0,
    ]) =>
        GoogleFonts.plusJakartaSans(
          fontSize: size,
          height: line / size,
          fontWeight: weight,
          letterSpacing: spacing,
          color: text,
        ).copyWith(
          fontFamilyFallback: const [
            'Noto Sans CJK JP',
            'Noto Sans JP',
            'sans-serif',
          ],
        );
    final textTheme = TextTheme(
      displayLarge: type(32, 38, FontWeight.w800, -.5),
      displayMedium: type(32, 38, FontWeight.w800, -.5),
      displaySmall: type(32, 38, FontWeight.w800, -.5),
      headlineLarge: type(32, 38, FontWeight.w800, -.5),
      headlineMedium: type(24, 30, FontWeight.w800, -.2),
      headlineSmall: type(24, 30, FontWeight.w800, -.2),
      titleLarge: type(18, 24, FontWeight.w800),
      titleMedium: type(18, 24, FontWeight.w800),
      titleSmall: type(16, 22, FontWeight.w700),
      bodyLarge: type(16, 22, FontWeight.w500),
      bodyMedium: type(16, 22, FontWeight.w500),
      bodySmall: type(13, 18, FontWeight.w500),
      labelLarge: type(13, 18, FontWeight.w700, .5),
      labelMedium: type(13, 18, FontWeight.w700, .5),
      labelSmall: type(13, 18, FontWeight.w700, .5),
    );
    final side = BorderSide(color: border, width: LingoSpace.border);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(LingoRadii.control),
      side: side,
    );
    final card = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(LingoRadii.card),
      side: side,
    );
    final button = ButtonStyle(
      elevation: const WidgetStatePropertyAll(0),
      minimumSize: const WidgetStatePropertyAll(
        Size(LingoSpace.touch, LingoSpace.button),
      ),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(
          horizontal: LingoSpace.s24,
          vertical: LingoSpace.s16,
        ),
      ),
      textStyle: WidgetStatePropertyAll(
        textTheme.bodyLarge!.copyWith(fontWeight: FontWeight.w800),
      ),
      shape: WidgetStatePropertyAll(shape),
      side: WidgetStatePropertyAll(side),
      foregroundColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.disabled) ? muted : text,
      ),
      overlayColor: WidgetStatePropertyAll(
        LingoPalette.accent.withValues(alpha: .18),
      ),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colors,
      scaffoldBackgroundColor: canvas,
      textTheme: textTheme,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      splashFactory: NoSplash.splashFactory,
      extensions: [
        LingoTokens(
          success: LingoPalette.green,
          onSuccess: LingoPalette.ink,
          pressed: LingoPalette.pressed,
          disabled: disabled,
        ),
      ],
      appBarTheme: AppBarTheme(
        backgroundColor: canvas,
        foregroundColor: text,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: LingoPalette.clear,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: button.copyWith(
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled)
                ? disabled
                : dark
                ? LingoPalette.lime
                : LingoPalette.ink,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled)
                ? muted
                : dark
                ? LingoPalette.ink
                : LingoPalette.cream,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: button.copyWith(
          backgroundColor: WidgetStatePropertyAll(surface),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: button.copyWith(
          side: const WidgetStatePropertyAll(BorderSide.none),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(
            Size.square(LingoSpace.touch),
          ),
          foregroundColor: WidgetStatePropertyAll(text),
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? dark
                    ? LingoPalette.lime
                    : LingoPalette.ink
              : muted,
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.all(LingoSpace.s16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LingoRadii.control),
          borderSide: side,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LingoRadii.control),
          borderSide: side,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LingoRadii.control),
          borderSide: side.copyWith(color: LingoPalette.accent),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LingoRadii.control),
          borderSide: side.copyWith(color: LingoPalette.coral),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LingoRadii.control),
          borderSide: side.copyWith(color: LingoPalette.coral),
        ),
        errorStyle: textTheme.bodySmall,
        errorMaxLines: 4,
        labelStyle: textTheme.bodyLarge,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        surfaceTintColor: LingoPalette.clear,
        shape: card,
        margin: const EdgeInsets.only(bottom: LingoSpace.s16),
        clipBehavior: Clip.antiAlias,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: LingoPalette.lime,
        side: side,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LingoRadii.pill),
        ),
        labelStyle: textTheme.labelLarge!.copyWith(
          color: WidgetStateColor.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? colors.onPrimary
                : colors.onSurface,
          ),
        ),
        checkmarkColor: colors.onPrimary,
        padding: const EdgeInsets.all(LingoSpace.s8),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: surface,
        surfaceTintColor: LingoPalette.clear,
        indicatorColor: LingoPalette.lime,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LingoRadii.control),
          side: side,
        ),
        labelTextStyle: WidgetStatePropertyAll(textTheme.labelLarge),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            color: s.contains(WidgetState.selected) ? LingoPalette.ink : text,
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        elevation: 0,
        backgroundColor: surface,
        surfaceTintColor: LingoPalette.clear,
        shape: card,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        elevation: 0,
        modalElevation: 0,
        backgroundColor: surface,
        surfaceTintColor: LingoPalette.clear,
        shape: card,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: LingoPalette.lime,
        linearTrackColor: alt,
        linearMinHeight: LingoSpace.s16,
        borderRadius: BorderRadius.circular(LingoRadii.pill),
      ),
      dividerTheme: DividerThemeData(
        color: border,
        thickness: LingoSpace.border,
      ),
      snackBarTheme: SnackBarThemeData(
        elevation: 0,
        backgroundColor: colors.inverseSurface,
        contentTextStyle: textTheme.bodyLarge!.copyWith(
          color: colors.onInverseSurface,
        ),
        shape: card,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
