import '../../../core/utils/json_reader.dart';
import '../../exercises/domain/exercise.dart';

final class Lesson {
  Lesson({
    required this.id,
    required this.title,
    required List<String> wordIds,
    required List<Exercise> exercises,
  }) : wordIds = List.unmodifiable(wordIds),
       exercises = List.unmodifiable(exercises);

  final String id;
  final String title;
  final List<String> wordIds;
  final List<Exercise> exercises;

  factory Lesson.fromJson(JsonMap json) => Lesson(
    id: JsonReader.text(json, 'id'),
    title: JsonReader.text(json, 'title'),
    wordIds: JsonReader.strings(json, 'wordIds'),
    exercises: JsonReader.list(json, 'exercises')
        .map((value) => Exercise.fromJson(JsonReader.object(value, 'exercise')))
        .toList(),
  );

  JsonMap toJson() => {
    'id': id,
    'title': title,
    'wordIds': wordIds.toList(),
    'exercises': exercises.map((exercise) => exercise.toJson()).toList(),
  };
}
