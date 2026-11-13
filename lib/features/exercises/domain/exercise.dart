import '../../../core/utils/json_reader.dart';

sealed class Exercise {
  const Exercise({required this.id});

  final String id;

  factory Exercise.fromJson(JsonMap json) {
    final id = JsonReader.text(json, 'id');
    return switch (JsonReader.text(json, 'type')) {
      'multipleChoice' => MultipleChoice.fromJson(json),
      'matchPairs' => MatchPairs.fromJson(json),
      'fillInBlank' => FillInBlank.fromJson(json),
      'typeTranslation' => TypeTranslation.fromJson(json),
      'listening' => Listening.fromJson(json),
      'speaking' => Speaking.fromJson(json),
      final type => throw FormatException('Unknown exercise type $type ($id)'),
    };
  }

  JsonMap toJson();
}

final class Listening extends Exercise {
  Listening({
    required super.id,
    required this.audioText,
    this.audioUrl,
    required List<String> acceptedAnswers,
    List<String> options = const [],
  }) : acceptedAnswers = List.unmodifiable(acceptedAnswers),
       options = List.unmodifiable(options) {
    if (audioText.trim().isEmpty ||
        acceptedAnswers.isEmpty ||
        acceptedAnswers.any((s) => s.trim().isEmpty) ||
        (options.isNotEmpty &&
            (options.length < 2 || !options.any(acceptedAnswers.contains)))) {
      throw const FormatException('Invalid listening answers/options');
    }
    JsonReader.unique(options, 'listening option');
  }
  final String audioText;
  final String? audioUrl;
  final List<String> acceptedAnswers, options;
  factory Listening.fromJson(JsonMap json) => Listening(
    id: JsonReader.text(json, 'id'),
    audioText: JsonReader.text(json, 'audioText'),
    audioUrl: json['audioUrl'] == null
        ? null
        : JsonReader.text(json, 'audioUrl'),
    acceptedAnswers: JsonReader.strings(json, 'acceptedAnswers'),
    options: json['options'] == null
        ? const []
        : JsonReader.strings(json, 'options'),
  );
  @override
  JsonMap toJson() => {
    'id': id,
    'type': 'listening',
    'audioText': audioText,
    'acceptedAnswers': acceptedAnswers.toList(),
    if (options.isNotEmpty) 'options': options.toList(),
    if (audioUrl != null) 'audioUrl': audioUrl,
  };
}

final class Speaking extends Exercise {
  Speaking({
    required super.id,
    required this.phrase,
    this.audioUrl,
    this.minimumScore = .8,
    List<String> acceptedAnswers = const [],
  }) : acceptedAnswers = List.unmodifiable(acceptedAnswers) {
    if (acceptedAnswers.any((answer) => answer.trim().isEmpty) ||
        phrase.trim().isEmpty ||
        phrase.length > 300 ||
        !minimumScore.isFinite ||
        minimumScore < 0 ||
        minimumScore > 1) {
      throw const FormatException('Invalid speaking phrase or threshold');
    }
  }
  final String phrase;
  final String? audioUrl;
  final double minimumScore;
  final List<String> acceptedAnswers;
  factory Speaking.fromJson(JsonMap json) {
    final score = json['minimumScore'];
    if (score != null && score is! num) {
      throw const FormatException('Invalid minimumScore');
    }
    return Speaking(
      id: JsonReader.text(json, 'id'),
      phrase: JsonReader.text(json, 'phrase'),
      audioUrl: json['audioUrl'] == null
          ? null
          : JsonReader.text(json, 'audioUrl'),
      minimumScore: (score as num?)?.toDouble() ?? .8,
      acceptedAnswers: json['acceptedAnswers'] == null
          ? const []
          : JsonReader.strings(json, 'acceptedAnswers'),
    );
  }
  @override
  JsonMap toJson() => {
    'id': id,
    'type': 'speaking',
    'phrase': phrase,
    'minimumScore': minimumScore,
    if (acceptedAnswers.isNotEmpty) 'acceptedAnswers': acceptedAnswers.toList(),
    if (audioUrl != null) 'audioUrl': audioUrl,
  };
}

final class MultipleChoice extends Exercise {
  MultipleChoice({
    required super.id,
    required this.prompt,
    required List<String> options,
    required this.correctIndex,
  }) : options = List.unmodifiable(options) {
    if (options.length < 2 ||
        correctIndex < 0 ||
        correctIndex >= options.length) {
      throw const FormatException('Invalid multiple-choice options or index');
    }
    JsonReader.unique(options, 'option');
  }

  final String prompt;
  final List<String> options;
  final int correctIndex;

  factory MultipleChoice.fromJson(JsonMap json) => MultipleChoice(
    id: JsonReader.text(json, 'id'),
    prompt: JsonReader.text(json, 'prompt'),
    options: JsonReader.strings(json, 'options'),
    correctIndex: JsonReader.integer(json, 'correctIndex'),
  );

  @override
  JsonMap toJson() => {
    'id': id,
    'type': 'multipleChoice',
    'prompt': prompt,
    'options': options.toList(),
    'correctIndex': correctIndex,
  };
}

final class MatchPair {
  const MatchPair({required this.left, required this.right});

  final String left;
  final String right;

  factory MatchPair.fromJson(JsonMap json) => MatchPair(
    left: JsonReader.text(json, 'left'),
    right: JsonReader.text(json, 'right'),
  );

  JsonMap toJson() => {'left': left, 'right': right};
}

final class MatchPairs extends Exercise {
  MatchPairs({required super.id, required List<MatchPair> pairs})
    : pairs = List.unmodifiable(pairs) {
    if (pairs.length < 2) {
      throw const FormatException('Need at least two pairs');
    }
    JsonReader.unique(pairs.map((pair) => pair.left), 'pair left side');
    JsonReader.unique(pairs.map((pair) => pair.right), 'pair right side');
  }

  final List<MatchPair> pairs;

  factory MatchPairs.fromJson(JsonMap json) => MatchPairs(
    id: JsonReader.text(json, 'id'),
    pairs: JsonReader.list(json, 'pairs')
        .map((value) => MatchPair.fromJson(JsonReader.object(value, 'pair')))
        .toList(),
  );

  @override
  JsonMap toJson() => {
    'id': id,
    'type': 'matchPairs',
    'pairs': pairs.map((pair) => pair.toJson()).toList(),
  };
}

final class FillInBlank extends Exercise {
  FillInBlank({
    required super.id,
    required this.sentenceWithBlank,
    required this.answer,
    required List<String> choices,
  }) : choices = List.unmodifiable(choices) {
    if ('___'.allMatches(sentenceWithBlank).length != 1 ||
        !choices.contains(answer) ||
        choices.length < 2) {
      throw const FormatException(
        'Need one ___ blank and choices containing answer',
      );
    }
  }

  final String sentenceWithBlank;
  final String answer;
  final List<String> choices;

  factory FillInBlank.fromJson(JsonMap json) => FillInBlank(
    id: JsonReader.text(json, 'id'),
    sentenceWithBlank: JsonReader.text(json, 'sentenceWithBlank'),
    answer: JsonReader.text(json, 'answer'),
    choices: JsonReader.strings(json, 'choices'),
  );

  @override
  JsonMap toJson() => {
    'id': id,
    'type': 'fillInBlank',
    'sentenceWithBlank': sentenceWithBlank,
    'answer': answer,
    'choices': choices.toList(),
  };
}

final class TypeTranslation extends Exercise {
  TypeTranslation({
    required super.id,
    required this.prompt,
    required List<String> acceptedAnswers,
  }) : acceptedAnswers = List.unmodifiable(acceptedAnswers) {
    if (acceptedAnswers.isEmpty) {
      throw const FormatException('acceptedAnswers must not be empty');
    }
  }

  final String prompt;
  final List<String> acceptedAnswers;

  factory TypeTranslation.fromJson(JsonMap json) => TypeTranslation(
    id: JsonReader.text(json, 'id'),
    prompt: JsonReader.text(json, 'prompt'),
    acceptedAnswers: JsonReader.strings(json, 'acceptedAnswers'),
  );

  @override
  JsonMap toJson() => {
    'id': id,
    'type': 'typeTranslation',
    'prompt': prompt,
    'acceptedAnswers': acceptedAnswers.toList(),
  };
}
