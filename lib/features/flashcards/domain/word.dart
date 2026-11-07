import '../../../core/utils/json_reader.dart';

final class Word {
  Word({
    required this.id,
    required this.text,
    required this.translation,
    required this.example,
    required this.exampleTranslation,
    this.audioUrl,
    required List<String> tags,
  }) : tags = List.unmodifiable(tags);

  final String id;
  final String text;
  final String translation;
  final String example;
  final String exampleTranslation;
  final String? audioUrl;
  final List<String> tags;

  factory Word.fromJson(JsonMap json) => Word(
    id: JsonReader.text(json, 'id'),
    text: JsonReader.text(json, 'text'),
    translation: JsonReader.text(json, 'translation'),
    example: JsonReader.text(json, 'example'),
    exampleTranslation: JsonReader.text(json, 'exampleTranslation'),
    audioUrl: json['audioUrl'] == null
        ? null
        : JsonReader.text(json, 'audioUrl'),
    tags: JsonReader.strings(json, 'tags'),
  );

  JsonMap toJson() => {
    'id': id,
    'text': text,
    'translation': translation,
    'example': example,
    'exampleTranslation': exampleTranslation,
    if (audioUrl != null) 'audioUrl': audioUrl,
    'tags': tags.toList(),
  };
}
