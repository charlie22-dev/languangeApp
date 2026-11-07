import '../../../core/utils/json_reader.dart';
import 'lesson.dart';

final class Unit {
  Unit({required this.id, required this.title, required List<Lesson> lessons})
    : lessons = List.unmodifiable(lessons);

  final String id;
  final String title;
  final List<Lesson> lessons;

  factory Unit.fromJson(JsonMap json) => Unit(
    id: JsonReader.text(json, 'id'),
    title: JsonReader.text(json, 'title'),
    lessons: JsonReader.list(json, 'lessons')
        .map((value) => Lesson.fromJson(JsonReader.object(value, 'lesson')))
        .toList(),
  );

  JsonMap toJson() => {
    'id': id,
    'title': title,
    'lessons': lessons.map((lesson) => lesson.toJson()).toList(),
  };
}
