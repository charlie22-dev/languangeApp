import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:mocktail/mocktail.dart';
import 'package:myapp/features/lessons/domain/course.dart';
import 'package:myapp/features/onboarding/data/onboarding_repository.dart';
import 'package:myapp/features/onboarding/domain/onboarding_settings.dart';

Course sampleCourse() => Course.fromJson(
  jsonDecode(File('assets/courses/japanese_basics.json').readAsStringSync())
      as Map<String, dynamic>,
);

OnboardingSettings completedSettings() =>
    OnboardingSettings(courseId: 'ja_basics_en', goalMinutes: 10);

class UnusedPreferences extends Fake implements SharedPreferencesAsync {}

class MemoryOnboardingRepository extends OnboardingRepository {
  MemoryOnboardingRepository({this.saved}) : super(UnusedPreferences());
  OnboardingSettings? saved;
  bool failLoad = false;
  bool failSave = false;
  int saveCalls = 0;
  Completer<void>? loadGate;
  Completer<void>? saveGate;

  @override
  Future<OnboardingSettings?> load() async {
    await loadGate?.future;
    if (failLoad) throw StateError('Read failure');
    return saved;
  }

  @override
  Future<void> save(OnboardingSettings settings) async {
    saveCalls++;
    await saveGate?.future;
    if (failSave) throw StateError('Write failure');
    saved = settings;
  }
}
