import 'package:flutter/material.dart';

import '../../core/theme/lingo_tokens.dart';
import '../../core/localization/lingo_localizations.dart';

enum PipMood { happy, thinking, celebrating, sad, sleepy }

abstract final class PipSize {
  static const hero = 116.0;
  static const medium = 88.0;
  static const small = 56.0;
}

/// Native vector recreation of renderPipMascot's 96x96 coordinate system.
class PipMascot extends StatelessWidget {
  const PipMascot({
    super.key,
    this.mood = PipMood.happy,
    this.size = PipSize.medium,
    this.decorative = false,
  });
  final PipMood mood;
  final double size;
  final bool decorative;
  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    excludeSemantics: decorative,
    label: decorative
        ? null
        : context.l10n.text('pipMood', {'mood': context.l10n.text(mood.name)}),
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _PipPainter(mood)),
    ),
  );
}

class _PipPainter extends CustomPainter {
  const _PipPainter(this.mood);
  final PipMood mood;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 96, size.height / 96);
    final ink = Paint()
      ..color = LingoPalette.ink
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    void fill(Path path, Color color) {
      canvas.drawPath(path, Paint()..color = color);
      canvas.drawPath(path, ink);
    }

    final body = Path()
      ..moveTo(48, 16)
      ..cubicTo(45, 10, 38, 11, 40, 18)
      ..cubicTo(23, 21, 14, 35, 14, 54)
      ..cubicTo(14, 73, 27, 84, 48, 84)
      ..cubicTo(69, 84, 82, 73, 82, 54)
      ..cubicTo(82, 35, 73, 21, 56, 18)
      ..cubicTo(58, 11, 51, 10, 48, 16)
      ..close();
    fill(body, mood == PipMood.sad ? LingoPalette.accent : LingoPalette.lime);
    for (final x in [25.0, 71.0]) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, 57), width: 9, height: 5),
        Paint()..color = LingoPalette.coral.withValues(alpha: .55),
      );
    }
    if (mood == PipMood.celebrating || mood == PipMood.sleepy) {
      for (final x in [26.0, 54.0]) {
        canvas.drawPath(
          Path()
            ..moveTo(x, 48)
            ..cubicTo(
              x + 4,
              mood == PipMood.sleepy ? 53 : 41,
              x + 12,
              mood == PipMood.sleepy ? 53 : 41,
              x + 16,
              48,
            ),
          ink,
        );
      }
    } else {
      for (final x in [34.0, 62.0]) {
        final y = mood == PipMood.thinking
            ? 44.0
            : mood == PipMood.sad
            ? 48.0
            : 46.0;
        canvas.drawCircle(
          Offset(x, y),
          11,
          Paint()..color = LingoPalette.cream,
        );
        canvas.drawCircle(Offset(x, y), 11, ink..strokeWidth = 2.5);
        canvas.drawCircle(
          Offset(
            x +
                (mood == PipMood.thinking
                    ? 2
                    : x == 34
                    ? 2
                    : -2),
            y +
                (mood == PipMood.thinking
                    ? -3
                    : mood == PipMood.sad
                    ? 2
                    : 0),
          ),
          5.5,
          Paint()..color = LingoPalette.ink,
        );
        if (mood == PipMood.happy) {
          canvas.drawCircle(
            Offset(x + 4, y - 2),
            2,
            Paint()..color = LingoPalette.cream,
          );
        }
      }
    }
    ink.strokeWidth = 3;
    switch (mood) {
      case PipMood.celebrating:
        fill(
          Path()
            ..moveTo(39, 58)
            ..cubicTo(41, 69, 55, 69, 57, 58)
            ..close(),
          LingoPalette.coral,
        );
        final confetti = Paint()
          ..color = LingoPalette.accent
          ..strokeWidth = 3.5
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(const Offset(16, 24), const Offset(22, 30), confetti);
        canvas.drawLine(const Offset(80, 24), const Offset(74, 30), confetti);
        canvas.drawLine(const Offset(48, 8), const Offset(48, 15), confetti);
      case PipMood.thinking:
        canvas.drawLine(const Offset(44, 64), const Offset(53, 64), ink);
        for (final item in [
          (const Offset(82, 20), 5.0),
          (const Offset(74, 30), 3.0),
        ]) {
          canvas.drawCircle(
            item.$1,
            item.$2,
            Paint()..color = LingoPalette.accent,
          );
          canvas.drawCircle(item.$1, item.$2, ink..strokeWidth = 1.5);
        }
      case PipMood.sad:
        canvas.drawPath(
          Path()
            ..moveTo(41, 67)
            ..cubicTo(44, 62, 52, 62, 55, 67),
          ink,
        );
      case PipMood.sleepy:
        canvas.drawCircle(
          const Offset(48, 63),
          4,
          Paint()..color = LingoPalette.ink,
        );
        // Vector Zs avoid SVG text/font dependencies.
        canvas.drawPath(
          Path()
            ..moveTo(74, 20)
            ..lineTo(81, 20)
            ..lineTo(74, 27)
            ..lineTo(81, 27),
          ink..strokeWidth = 2,
        );
      case PipMood.happy:
        canvas.drawPath(
          Path()
            ..moveTo(41, 63)
            ..cubicTo(44, 67, 52, 67, 55, 63),
          ink,
        );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PipPainter oldDelegate) => oldDelegate.mood != mood;
}
