import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/core/database/app_database.dart';
import 'package:myapp/features/chat/data/chat_repository.dart';
import 'package:myapp/features/chat/domain/chat_models.dart';
import 'package:myapp/features/activity/data/activity_repository.dart';
import 'package:myapp/features/flashcards/data/review_repository.dart';
import 'package:myapp/features/flashcards/domain/word.dart';
import 'package:myapp/features/lessons/domain/course.dart';
import 'package:myapp/features/sync/data/local_sync_store.dart';
import 'package:myapp/features/sync/domain/sync_record.dart';

import 'support/phase3_fixtures.dart';
import 'support/chat_fixtures.dart';

void main() {
  late AppDatabase db;
  late ChatRepository repository;
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = ChatRepository(
      db,
      clock: () => DateTime.utc(2026, 11, 13, 10),
    );
  });
  tearDown(() => db.close());
  test(
    'completing the same turn twice cannot duplicate tutor messages',
    () async {
      final user = await repository.addUser(
        'hello',
        ChatScenario.introductions,
      );
      await repository.complete(user, sampleTutorTurn());
      await repository.markFailed(user.id);
      await repository.complete(user, sampleTutorTurn());
      final messages = await repository.load(ChatScenario.introductions);
      expect(messages.length, 2);
      expect(messages.first.pending, isFalse);
    },
  );
  test(
    'keeps exactly the last 20 messages globally and restores scenarios',
    () async {
      for (var i = 0; i < 12; i++) {
        final user = await repository.addUser(
          'message $i',
          i.isEven ? ChatScenario.introductions : ChatScenario.shopping,
        );
        await repository.complete(user, sampleTutorTurn());
      }
      final all = await db.select(db.chatEntries).get();
      expect(all.length, 20);
      expect(all.any((r) => r.content == 'message 0'), isFalse);
      expect(await repository.lastScenario(), ChatScenario.shopping);
      final restored = await ChatRepository(db).load(ChatScenario.shopping);
      expect(
        restored.every((m) => m.scenario == ChatScenario.shopping),
        isTrue,
      );
      expect(restored.last.translation, 'Hello. What is your name?');
      expect(restored.last.newWords.single.translation, 'cat');
    },
  );
  test('failed requests retain the same user row, and corrections attach to that row', () async {
    final user = await repository.addUser(
      'hello mistake',
      ChatScenario.introductions,
    );
    await repository.markFailed(user.id);
    expect(
      (await repository.load(ChatScenario.introductions)).single.pending,
      isTrue,
    );
    await repository.complete(
      user,
      sampleTutorTurn(
        corrections: const [
          ChatCorrection(
            original: 'mistake',
            corrected: 'correction',
            explanation: 'Use this.',
          ),
        ],
      ),
    );
    final messages = await repository.load(ChatScenario.introductions);
    expect(messages.length, 2);
    expect(messages.first.id, user.id);
    expect(messages.first.corrections.single.corrected, 'correction');
    expect(messages.last.corrections, isEmpty);
  });
  test(
    'rejects correction text from another message transactionally',
    () async {
      final user = await repository.addUser(
        'hello',
        ChatScenario.introductions,
      );
      await expectLater(
        repository.complete(
          user,
          sampleTutorTurn(
            corrections: const [
              ChatCorrection(
                original: 'another turn',
                corrected: 'x',
                explanation: 'x',
              ),
            ],
          ),
        ),
        throwsFormatException,
      );
      expect((await db.select(db.chatEntries).get()).length, 1);
    },
  );
  test('new words create metadata plus due WordProgress; duplicate saves preserve SM-2', () async {
    final course = sampleCourse();
    final word = sampleTutorTurn().newWords.single;
    await repository.saveWord(word, course);
    final metadata = await db.select(db.savedVocabulary).getSingle();
    final progress = await db.select(db.wordProgress).getSingle();
    expect(metadata.wordText, word.text);
    expect(progress.wordId, metadata.wordId);
    expect(progress.dueDate.toUtc(), DateTime.utc(2026, 11, 13, 10));
    await db
        .update(db.wordProgress)
        .write(
          const WordProgressCompanion(
            repetitions: Value(3),
            intervalDays: Value(15),
          ),
        );
    await repository.saveWord(word, course);
    expect((await db.select(db.savedVocabulary).get()).length, 1);
    expect((await db.select(db.wordProgress).getSingle()).repetitions, 3);
    final saved = Word(
      id: metadata.wordId,
      text: metadata.wordText,
      translation: metadata.translation,
      example: metadata.example,
      exampleTranslation: metadata.exampleTranslation,
      tags: const ['ai'],
    );
    final augmented = Course(
      id: course.id,
      title: course.title,
      targetLanguage: course.targetLanguage,
      nativeLanguage: course.nativeLanguage,
      words: [...course.words, saved],
      units: course.units,
    );
    expect(
      (await ReviewRepository(
        db,
        clock: () => DateTime.utc(2026, 11, 14),
      ).loadDueCards(augmented)).single.id,
      saved.id,
    );
  });
  test('existing course words reuse their IDs and do not create duplicate vocabulary', () async {
    final course = sampleCourse();
    final word = course.words.first;
    await repository.saveWord(
      SuggestedWord(
        text: word.text,
        translation: word.translation,
        example: word.example,
        exampleTranslation: word.exampleTranslation,
      ),
      course,
    );
    expect((await db.select(db.wordProgress).getSingle()).wordId, word.id);
    expect(await db.select(db.savedVocabulary).get(), isEmpty);
  });
  test(
    'saved vocabulary syncs and reset cannot be undone by a stale snapshot',
    () async {
      await repository.saveWord(
        sampleTutorTurn().newWords.single,
        sampleCourse(),
      );
      final snapshot = await LocalSyncStore(db).snapshot();
      expect(
        snapshot.records.any((r) => r.kind == SyncKind.vocabulary),
        isTrue,
      );
      await ActivityRepository(
        db,
        clock: () => DateTime.utc(2026, 11, 14),
      ).reset();
      await LocalSyncStore(db).merge(snapshot);
      expect((await db.select(db.savedVocabulary).getSingle()).deleted, isTrue);
      expect((await db.select(db.wordProgress).getSingle()).deleted, isTrue);
      await repository.saveWord(
        sampleTutorTurn().newWords.single,
        sampleCourse(),
      );
      expect(
        (await db.select(db.savedVocabulary).getSingle()).deleted,
        isFalse,
      );
    },
  );
}
