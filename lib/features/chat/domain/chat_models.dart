import '../../../core/utils/json_reader.dart';

enum ChatScenario {
  orderingFood('ordering_food', 'chatScenarioFood'),
  introductions('introductions', 'chatScenarioIntroductions'),
  directions('directions', 'chatScenarioDirections'),
  shopping('shopping', 'chatScenarioShopping');

  const ChatScenario(this.id, this.labelKey);
  final String id, labelKey;
  static ChatScenario parse(String id) => values.firstWhere((s) => s.id == id);
}

String chatText(JsonMap json, String field, int limit) {
  final text = JsonReader.text(json, field);
  if (text.runes.length > limit) throw FormatException('Invalid $field');
  return text;
}

class ChatCorrection {
  const ChatCorrection({
    required this.original,
    required this.corrected,
    required this.explanation,
  });
  final String original, corrected, explanation;
  factory ChatCorrection.fromJson(JsonMap json) => ChatCorrection(
    original: chatText(json, 'original', 500),
    corrected: chatText(json, 'corrected', 500),
    explanation: chatText(json, 'explanation', 500),
  );
  JsonMap toJson() => {
    'original': original,
    'corrected': corrected,
    'explanation': explanation,
  };
}

class SuggestedWord {
  const SuggestedWord({
    required this.text,
    required this.translation,
    required this.example,
    required this.exampleTranslation,
  });
  final String text, translation, example, exampleTranslation;
  factory SuggestedWord.fromJson(JsonMap json) => SuggestedWord(
    text: chatText(json, 'text', 100),
    translation: chatText(json, 'translation', 150),
    example: chatText(json, 'example', 300),
    exampleTranslation: chatText(json, 'exampleTranslation', 300),
  );
  JsonMap toJson() => {
    'text': text,
    'translation': translation,
    'example': example,
    'exampleTranslation': exampleTranslation,
  };
}

class TutorTurn {
  TutorTurn({
    required this.reply,
    required this.translation,
    required List<ChatCorrection> corrections,
    required List<SuggestedWord> newWords,
  }) : corrections = List.unmodifiable(corrections),
       newWords = List.unmodifiable(newWords);
  final String reply, translation;
  final List<ChatCorrection> corrections;
  final List<SuggestedWord> newWords;
  factory TutorTurn.fromJson(JsonMap json) {
    final corrections = JsonReader.list(json, 'corrections');
    final words = JsonReader.list(json, 'newWords');
    if (corrections.length > 3 || words.length > 3) {
      throw const FormatException('Too many tutor items');
    }
    return TutorTurn(
      reply: chatText(json, 'reply', 500),
      translation: chatText(json, 'translation', 800),
      corrections: corrections
          .map(
            (c) => ChatCorrection.fromJson(JsonReader.object(c, 'correction')),
          )
          .toList(),
      newWords: words
          .map((w) => SuggestedWord.fromJson(JsonReader.object(w, 'newWord')))
          .toList(),
    );
  }
}

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.scenario,
    required this.role,
    required this.content,
    this.status = 'sent',
    this.translation,
    List<ChatCorrection> corrections = const [],
    List<SuggestedWord> newWords = const [],
  }) : corrections = List.unmodifiable(corrections),
       newWords = List.unmodifiable(newWords);
  final int id;
  final ChatScenario scenario;
  final String role, content, status;
  final String? translation;
  final List<ChatCorrection> corrections;
  final List<SuggestedWord> newWords;
  bool get fromUser => role == 'user';
  bool get pending => fromUser && status != 'sent';
  JsonMap toApiJson() => {'role': role, 'content': content};
}

class ChatFailure implements Exception {
  const ChatFailure(this.key);
  final String key;
}

String vocabularyKey(String text) => text.trim().toLowerCase();
