class PracticeSettings {
  const PracticeSettings({
    this.sound = true,
    this.reminders = false,
    this.hour = 19,
    this.minute = 0,
    this.saving = false,
    this.error,
  });
  final bool sound, reminders, saving;
  final int hour, minute;
  final String? error;
  PracticeSettings copyWith({
    bool? sound,
    bool? reminders,
    int? hour,
    int? minute,
    bool saving = false,
    String? error,
  }) => PracticeSettings(
    sound: sound ?? this.sound,
    reminders: reminders ?? this.reminders,
    hour: hour ?? this.hour,
    minute: minute ?? this.minute,
    saving: saving,
    error: error,
  );
}
