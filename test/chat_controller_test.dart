import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/core/database/app_database.dart';
import 'package:myapp/features/chat/data/chat_api.dart';
import 'package:myapp/features/chat/data/chat_repository.dart';
import 'package:myapp/features/chat/presentation/chat_controller.dart';
import 'package:myapp/features/chat/domain/chat_models.dart';

import 'support/chat_fixtures.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late FakeChatApi api;
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    api = FakeChatApi();
    container = ProviderContainer(
      overrides: [
        chatRepositoryProvider.overrideWithValue(ChatRepository(db)),
        chatApiProvider.overrideWith((ref) async => api),
      ],
    );
    container.listen(chatControllerProvider, (_, _) {});
    await container.read(chatControllerProvider.future);
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });
  test(
    'a failed send is persisted and retry reuses its user message',
    () async {
      final controller = container.read(chatControllerProvider.notifier);
      api.error = 'chatOffline';
      await controller.send('こんにちは');
      var state = container.read(chatControllerProvider).requireValue;
      expect(state.messages.length, 1);
      expect(state.error, 'chatOffline');
      final id = state.pending!.id;
      api.error = null;
      await controller.retry();
      state = container.read(chatControllerProvider).requireValue;
      expect(state.messages.length, 2);
      expect(state.messages.first.id, id);
      expect(api.calls, 2);
      expect(state.pending, isNull);
    },
  );
  test(
    'scenario switching excludes the other scenario from model context',
    () async {
      final controller = container.read(chatControllerProvider.notifier);
      await controller.send('intro');
      await controller.selectScenario(ChatScenario.shopping);
      expect(
        container.read(chatControllerProvider).requireValue.messages,
        isEmpty,
      );
      await controller.send('shopping');
      expect(api.histories.last.single.content, 'shopping');
      expect(api.scenarios.last, ChatScenario.shopping);
      await controller.selectScenario(ChatScenario.introductions);
      expect(
        container
            .read(chatControllerProvider)
            .requireValue
            .messages
            .first
            .content,
        'intro',
      );
    },
  );
  test('invalid messages do not reach the model', () async {
    await container.read(chatControllerProvider.notifier).send('a' * 501);
    expect(api.calls, 0);
    expect(
      container.read(chatControllerProvider).requireValue.error,
      'chatMessageLimit',
    );
  });
  test('discarding a failed message leaves previous history intact', () async {
    final controller = container.read(chatControllerProvider.notifier);
    await controller.send('first');
    api.error = 'chatRateLimit';
    await controller.send('second');
    await controller.discardPending();
    expect(
      container.read(chatControllerProvider).requireValue.messages.length,
      2,
    );
    expect(container.read(chatControllerProvider).requireValue.pending, isNull);
  });
}
