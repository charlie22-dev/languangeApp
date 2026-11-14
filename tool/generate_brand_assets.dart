// flutter test tool/generate_brand_assets.dart
// Rasterizes our existing vector mascot; no external artwork or network needed.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/core/theme/lingo_tokens.dart';
import 'package:myapp/shared/widgets/pip_mascot.dart';

void main() {
  testWidgets('export Pip launcher and splash source artwork', (tester) async {
    tester.view.physicalSize = const Size(1024, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final transparent in [true, false]) {
      const key = ValueKey('brand-art');
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: RepaintBoundary(
            key: key,
            child: ColoredBox(
              color: transparent ? LingoPalette.clear : LingoPalette.ink,
              child: const Center(
                child: PipMascot(size: 800, decorative: true),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(key),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File(
          'assets/branding/${transparent ? 'pip_foreground' : 'app_icon'}.png',
        );
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
  });
}
