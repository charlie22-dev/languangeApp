import 'dart:async';

import 'package:myapp/features/chat/data/chat_api.dart';
import 'package:myapp/features/chat/domain/chat_models.dart';

TutorTurn sampleTutorTurn({List<ChatCorrection> corrections = const []}) =>
    TutorTurn(
      reply: 'こんにちは。お名前は何ですか。',
      translation: 'Hello. What is your name?',
      corrections: corrections,
      newWords: const [
        SuggestedWord(
          text: '猫',
          translation: 'cat',
          example: '猫がいます。',
          exampleTranslation: 'There is a cat.',
        ),
      ],
    );

class FakeChatApi implements ChatApi {
  int calls = 0;
  String? error;
  Completer<TutorTurn>? gate;
  TutorTurn? response;
  final histories = <List<ChatMessage>>[];
  final scenarios = <ChatScenario>[];
  @override
  Future<TutorTurn> send(
    List<ChatMessage> messages,
    ChatScenario scenario,
  ) async {
    calls++;
    histories.add(messages);
    scenarios.add(scenario);
    if (error != null) throw ChatFailure(error!);
    return gate?.future ?? response ?? sampleTutorTurn();
  }
}
