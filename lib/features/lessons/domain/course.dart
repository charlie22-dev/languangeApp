import '../../../core/utils/json_reader.dart';
import '../../flashcards/domain/word.dart';
import 'unit.dart';

final class Course {
  Course({
    required this.id,
    required this.title,
    required this.targetLanguage,
    required this.nativeLanguage,
    this.targetLocale,
    required List<Word> words,
    required List<Unit> units,
  }) : words = List.unmodifiable(words),
       units = List.unmodifiable(units);

  final String id;
  final String title;
  final String targetLanguage;
  final String nativeLanguage;
  final String? targetLocale;
  final List<Word> words;
  final List<Unit> units;

  factory Course.fromJson(JsonMap json) {
    if (JsonReader.integer(json, 'schemaVersion') != 1) {
      throw const FormatException('Unsupported course schemaVersion');
    }
    final course = Course(
      id: JsonReader.text(json, 'id'),
      title: JsonReader.text(json, 'title'),
      targetLanguage: JsonReader.text(json, 'targetLanguage'),
      nativeLanguage: JsonReader.text(json, 'nativeLanguage'),
      targetLocale: json['targetLocale'] == null
          ? null
          : JsonReader.text(json, 'targetLocale'),
      words: JsonReader.list(json, 'words')
          .map((value) => Word.fromJson(JsonReader.object(value, 'word')))
          .toList(),
      units: JsonReader.list(json, 'units')
          .map((value) => Unit.fromJson(JsonReader.object(value, 'unit')))
          .toList(),
    );
    final lessons = course.units.expand((unit) => unit.lessons).toList();
    JsonReader.unique(course.words.map((word) => word.id), 'word ID');
    JsonReader.unique(course.units.map((unit) => unit.id), 'unit ID');
    JsonReader.unique(lessons.map((lesson) => lesson.id), 'lesson ID');
    JsonReader.unique(
      lessons
          .expand((lesson) => lesson.exercises)
          .map((exercise) => exercise.id),
      'exercise ID',
    );
    final wordIds = course.words.map((word) => word.id).toSet();
    for (final lesson in lessons) {
      if (lesson.wordIds.any((id) => !wordIds.contains(id))) {
        throw FormatException('Unknown word reference in ${lesson.id}');
      }
    }
    return course;
  }

  JsonMap toJson() => {
    'schemaVersion': 1,
    'id': id,
    'title': title,
    'targetLanguage': targetLanguage,
    'nativeLanguage': nativeLanguage,
    if (targetLocale != null) 'targetLocale': targetLocale,
    'words': words.map((word) => word.toJson()).toList(),
    'units': units.map((unit) => unit.toJson()).toList(),
  };
}
