import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myapp/core/router/app_router.dart';
import 'package:myapp/core/theme/appearance_controller.dart';
import 'package:myapp/features/lessons/domain/course.dart';
import 'package:myapp/features/onboarding/domain/onboarding_settings.dart';

import '../widget_test.dart' show AppHarness, mount;
import 'auth_fixtures.dart';

void main() {
  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('Capture ${mode.name} app screens', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final course = Course.fromJson(
        jsonDecode(
          File('assets/courses/japanese_basics.json').readAsStringSync(),
        ) as Map<String, dynamic>,
      );
      final harness = AppHarness(
        appName: 'LingoBlob',
        course: course,
        settings: OnboardingSettings(courseId: course.id, goalMinutes: 10),
      );
      await harness.container.read(appearanceProvider.notifier).select(mode);
      await mount(tester, harness);
      await tester.runAsync(() async {
        await GoogleFonts.pendingFonts();
        await (FontLoader(
          'NotoSansJP',
        )..addFont(rootBundle.load('assets/fonts/NotoSansJP.ttf'))).load();
        final data = await rootBundle.load('fonts/MaterialIcons-Regular.otf');
        await (FontLoader('MaterialIcons')..addFont(Future.value(data))).load();
      });
      await tester.pumpAndSettle();
      for (final route in [
        '/home',
        '/profile',
        '/review',
        '/settings',
        '/lesson/ja_greetings',
        '/chat',
      ]) {
        harness.container.read(appRouterProvider).go(route);
        await tester.pumpAndSettle();
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byType(RepaintBoundary).first,
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 3);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File(
            'docs/screenshots/${mode.name}-${route.substring(1).replaceAll('/', '-')}.png',
          );
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('Capture Login', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final auth = MemoryAuthRepository();
    addTearDown(auth.close);
    final harness = AppHarness(authRepository: auth, appName: 'LingoBlob');
    await mount(tester, harness);
    await tester.runAsync(() async {
      await GoogleFonts.pendingFonts();
      await (FontLoader(
        'NotoSansJP',
      )..addFont(rootBundle.load('assets/fonts/NotoSansJP.ttf'))).load();
      final data = await rootBundle.load('fonts/MaterialIcons-Regular.otf');
      await (FontLoader('MaterialIcons')..addFont(Future.value(data))).load();
    });
    await tester.pumpAndSettle();
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byType(RepaintBoundary).first,
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('docs/screenshots/login.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  });
}
