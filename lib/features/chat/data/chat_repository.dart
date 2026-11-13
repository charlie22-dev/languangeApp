import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/json_reader.dart';
import '../../../core/utils/sync_timestamp.dart';
import '../../lessons/domain/course.dart';
import '../../flashcards/data/word_enrollment.dart';
import '../domain/chat_models.dart';

final chatRepositoryProvider = Provider(
  (ref) => ChatRepository(
    ref.watch(appDatabaseProvider),
    clock: ref.watch(clockProvider),
  ),
);

class ChatRepository {
  ChatRepository(this.database, {DateTime Function()? clock})
    : clock = clock ?? DateTime.now;
  final AppDatabase database;
  final DateTime Function() clock;
  ChatMessage _message(ChatEntryRow row) {
    final metadata = JsonReader.object(
      jsonDecode(row.metadata),
      'chat metadata',
    );
    return ChatMessage(
      id: row.id,
      scenario: ChatScenario.parse(row.scenario),
      role: row.role,
      content: row.content,
      status: row.status,
      translation: metadata['translation'] as String?,
      corrections: (metadata['corrections'] as List? ?? [])
          .map(
            (c) => ChatCorrection.fromJson(JsonReader.object(c, 'correction')),
          )
          .toList(),
      newWords: (metadata['newWords'] as List? ?? [])
          .map((w) => SuggestedWord.fromJson(JsonReader.object(w, 'newWord')))
          .toList(),
    );
  }

  Future<ChatScenario> lastScenario() async {
    final row =
        await (database.select(database.chatEntries)
              ..orderBy([(r) => OrderingTerm.desc(r.id)])
              ..limit(1))
            .getSingleOrNull();
    return row == null
        ? ChatScenario.introductions
        : ChatScenario.parse(row.scenario);
  }

  Future<List<ChatMessage>> load(ChatScenario scenario) async =>
      (await (database.select(database.chatEntries)
                ..where((r) => r.scenario.equals(scenario.id))
                ..orderBy([(r) => OrderingTerm.asc(r.id)]))
              .get())
          .map(_message)
          .toList(growable: false);

  Future<void> _trim() => database.customUpdate(
    'DELETE FROM chat_entries WHERE id NOT IN (SELECT id FROM chat_entries ORDER BY id DESC LIMIT 20)',
    updates: {database.chatEntries},
  );
  Future<ChatMessage> addUser(String text, ChatScenario scenario) =>
      database.transaction(() async {
        final id = await database
            .into(database.chatEntries)
            .insert(
              ChatEntriesCompanion.insert(
                scenario: scenario.id,
                role: 'user',
                content: text,
                status: const Value('pending'),
              ),
            );
        await _trim();
        return ChatMessage(
          id: id,
          scenario: scenario,
          role: 'user',
          content: text,
          status: 'pending',
        );
      });
  Future<void> markFailed(int id) =>
      (database.update(database.chatEntries)
            ..where((r) => r.id.equals(id) & r.status.equals('sent').not()))
          .write(const ChatEntriesCompanion(status: Value('failed')));
  Future<void> discard(int id) => (database.delete(
    database.chatEntries,
  )..where((r) => r.id.equals(id) & r.status.equals('sent').not())).go();

  Future<void> complete(ChatMessage user, TutorTurn turn) =>
      database.transaction(() async {
        final persisted = await (database.select(
          database.chatEntries,
        )..where((r) => r.id.equals(user.id))).getSingleOrNull();
        if (persisted == null || persisted.status == 'sent') return;
        // No correction may attach to a different turn even if the provider misbehaves.
        if (turn.corrections.any((c) => !user.content.contains(c.original))) {
          throw const FormatException('Invalid correction owner');
        }
        await (database.update(
          database.chatEntries,
        )..where((r) => r.id.equals(user.id))).write(
          ChatEntriesCompanion(
            status: const Value('sent'),
            metadata: Value(
              jsonEncode({
                'corrections': turn.corrections.map((c) => c.toJson()).toList(),
              }),
            ),
          ),
        );
        await database
            .into(database.chatEntries)
            .insert(
              ChatEntriesCompanion.insert(
                scenario: user.scenario.id,
                role: 'assistant',
                content: turn.reply,
                metadata: Value(
                  jsonEncode({
                    'translation': turn.translation,
                    'newWords': turn.newWords.map((w) => w.toJson()).toList(),
                  }),
                ),
              ),
            );
        await _trim();
      });

  Future<void> saveWord(
    SuggestedWord word,
    Course course,
  ) => database.transaction(() async {
    // Validate even locally constructed suggestions before writing them.
    SuggestedWord.fromJson(word.toJson());
    final known = course.words
        .where((w) => vocabularyKey(w.text) == vocabularyKey(word.text))
        .firstOrNull;
    final id =
        known?.id ??
        'ai_${sha256.convert(utf8.encode('${course.id}\u0000${vocabularyKey(word.text)}'))}';
    final now = clock();
    if (known == null) {
      final current = await (database.select(
        database.savedVocabulary,
      )..where((r) => r.wordId.equals(id))).getSingleOrNull();
      if (current == null || current.deleted) {
        await database
            .into(database.savedVocabulary)
            .insertOnConflictUpdate(
              SavedVocabularyCompanion.insert(
                wordId: id,
                courseId: course.id,
                wordText: word.text,
                translation: word.translation,
                example: word.example,
                exampleTranslation: word.exampleTranslation,
                updatedAt: Value(
                  nextSyncTimestamp(current?.updatedAt ?? 0, now),
                ),
                deleted: const Value(false),
                dirty: const Value(true),
              ),
            );
      }
    }
    await enrollWords(database, [id], now);
  });
}
