import 'package:flutter/material.dart';

abstract final class LingoPalette {
  static const lime = Color(0xFFB2EE05);
  static const ink = Color(0xFF0A1038);
  static const pressed = Color(0xFF8DBA00);
  static const cream = Color(0xFFFFF9E5);
  static const white = Color(0xFFFFFFFF);
  static const sand = Color(0xFFF3EBD3);
  static const accent = Color(0xFF8A9BFF);
  static const coral = Color(0xFFF4695F);
  static const green = Color(0xFF3DBE6B);
  static const night = Color(0xFF0D1126);
  static const darkSurface = Color(0xFF171D3B);
  static const darkAlt = Color(0xFF212952);
  static const darkBorder = Color(0xFF38437A);
  static const muted = Color(0xFF4A5178);
  static const darkMuted = Color(0xFFB4BCE0);
  static const disabled = Color(0xFFE6DFC8);
  static const darkDisabled = Color(0xFF1E2547);
  static const clear = Color(0x00000000);
}

abstract final class LingoSpace {
  static const s8 = 8.0;
  static const s16 = 16.0;
  static const s24 = 24.0;
  static const s32 = 32.0;
  static const touch = 48.0;
  static const button = 52.0;
  static const node = 80.0;
  static const contentWidth = 560.0;
  static const border = 2.0;
}

abstract final class LingoRadii {
  static const card = 24.0;
  static const control = 16.0;
  static const pill = 999.0;
}

@immutable
class LingoTokens extends ThemeExtension<LingoTokens> {
  const LingoTokens({
    required this.success,
    required this.onSuccess,
    required this.pressed,
    required this.disabled,
    this.space = LingoSpace.s8,
    this.cardRadius = LingoRadii.card,
    this.controlRadius = LingoRadii.control,
    this.pillRadius = LingoRadii.pill,
  });
  final Color success;
  final Color onSuccess;
  final Color pressed;
  final Color disabled;
  final double space;
  final double cardRadius;
  final double controlRadius;
  final double pillRadius;
  @override
  LingoTokens copyWith({
    Color? success,
    Color? onSuccess,
    Color? pressed,
    Color? disabled,
    double? space,
    double? cardRadius,
    double? controlRadius,
    double? pillRadius,
  }) => LingoTokens(
    success: success ?? this.success,
    onSuccess: onSuccess ?? this.onSuccess,
    pressed: pressed ?? this.pressed,
    disabled: disabled ?? this.disabled,
    space: space ?? this.space,
    cardRadius: cardRadius ?? this.cardRadius,
    controlRadius: controlRadius ?? this.controlRadius,
    pillRadius: pillRadius ?? this.pillRadius,
  );
  @override
  LingoTokens lerp(covariant LingoTokens? other, double t) {
    if (other == null) return this;
    return copyWith(
      success: Color.lerp(success, other.success, t),
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t),
      pressed: Color.lerp(pressed, other.pressed, t),
      disabled: Color.lerp(disabled, other.disabled, t),
    );
  }
}

extension LingoThemeContext on BuildContext {
  LingoTokens get lingo =>
      Theme.of(this).extension<LingoTokens>() ??
      const LingoTokens(
        success: LingoPalette.green,
        onSuccess: LingoPalette.ink,
        pressed: LingoPalette.pressed,
        disabled: LingoPalette.disabled,
      );
}
