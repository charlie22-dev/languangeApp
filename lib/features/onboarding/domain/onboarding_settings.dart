import '../../../core/utils/json_reader.dart';

const dailyGoalMinutes = [5, 10, 15];

final class OnboardingSettings {
  OnboardingSettings({required this.courseId, required this.goalMinutes}) {
    if (courseId.trim().isEmpty || !dailyGoalMinutes.contains(goalMinutes)) {
      throw const FormatException('Invalid onboarding choices');
    }
  }

  final String courseId;
  final int goalMinutes;

  factory OnboardingSettings.fromJson(JsonMap json) {
    if (JsonReader.integer(json, 'version') != 1) {
      throw const FormatException('Unsupported onboarding version');
    }
    return OnboardingSettings(
      courseId: JsonReader.text(json, 'courseId'),
      goalMinutes: JsonReader.integer(json, 'goalMinutes'),
    );
  }

  JsonMap toJson() => {
    'version': 1,
    'courseId': courseId,
    'goalMinutes': goalMinutes,
  };
}
