import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myapp/features/onboarding/data/onboarding_repository.dart';
import 'package:myapp/features/onboarding/domain/onboarding_settings.dart';

class MockPreferences extends Mock implements SharedPreferencesAsync {}

void main() {
  late MockPreferences preferences;
  late OnboardingRepository repository;
  setUp(() {
    preferences = MockPreferences();
    repository = OnboardingRepository(preferences);
  });

  test('new installation has no saved choices', () async {
    when(() => preferences.getString(any())).thenAnswer((_) async => null);
    expect(await repository.load(), isNull);
  });

  test(
    'saves both choices in one document and reloads across instances',
    () async {
      String? stored;
      when(() => preferences.setString(any(), any())).thenAnswer((call) async {
        stored = call.positionalArguments[1] as String;
      });
      when(() => preferences.getString(any())).thenAnswer((_) async => stored);
      final settings = OnboardingSettings(
        courseId: 'ja_basics_en',
        goalMinutes: 15,
      );
      await repository.save(settings);
      verify(
        () => preferences.setString(
          OnboardingRepository.storageKey,
          jsonEncode(settings.toJson()),
        ),
      ).called(1);
      final reloaded = await OnboardingRepository(preferences).load();
      expect(reloaded!.courseId, settings.courseId);
      expect(reloaded.goalMinutes, 15);
    },
  );

  for (final corrupt in [
    '{broken',
    '{}',
    'null',
    '{"version":2}',
    '{"version":1,"courseId":"ja_basics_en","goalMinutes":7}',
  ]) {
    test('invalid stored choices restart onboarding: $corrupt', () async {
      when(() => preferences.getString(any())).thenAnswer((_) async => corrupt);
      expect(await repository.load(), isNull);
    });
  }

  test('storage read and write failures propagate for retry UI', () async {
    when(() => preferences.getString(any()))
        .thenThrow(StateError('Read failure'));
    when(() => preferences.setString(any(), any()))
        .thenAnswer((_) => Future.error(StateError('Write failure')));
    await expectLater(repository.load(), throwsStateError);
    await expectLater(
      repository.save(
        OnboardingSettings(courseId: 'ja_basics_en', goalMinutes: 5),
      ),
      throwsStateError,
    );
  });
}
