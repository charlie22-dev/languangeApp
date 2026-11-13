import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../home/data/home_providers.dart';
import '../../flashcards/domain/word.dart';
import '../../lessons/domain/course.dart';
import '../domain/chat_models.dart';

final reviewCourseProvider = StreamProvider.autoDispose<Course>((ref) async* {
  final course = await ref.watch(selectedCourseProvider.future);
  if (!ref.mounted) return;
  final db = ref.watch(appDatabaseProvider);
  yield* (db.select(db.savedVocabulary)
        ..where((r) => r.courseId.equals(course.id) & r.deleted.equals(false)))
      .watch()
      .map(
        (rows) => Course(
          id: course.id,
          title: course.title,
          targetLanguage: course.targetLanguage,
          nativeLanguage: course.nativeLanguage,
          targetLocale: course.targetLocale,
          units: course.units,
          words: [
            ...course.words,
            for (final row in rows.where(
              (r) => !course.words.any((w) => w.id == r.wordId),
            ))
              Word(
                id: row.wordId,
                text: row.wordText,
                translation: row.translation,
                example: row.example,
                exampleTranslation: row.exampleTranslation,
                tags: const ['ai'],
              ),
          ],
        ),
      );
});

final savedChatWordTextsProvider = StreamProvider.autoDispose<Set<String>>((
  ref,
) async* {
  final course = await ref.watch(selectedCourseProvider.future);
  if (!ref.mounted) return;
  final db = ref.watch(appDatabaseProvider);
  final known = {for (final w in course.words) w.id: w.text};
  yield* db
      .customSelect(
        '''SELECT w.word_id, v.text FROM word_progress w
    LEFT JOIN saved_vocabulary v ON v.word_id=w.word_id AND v.course_id=? AND v.deleted=0
    WHERE w.deleted=0''',
        variables: [Variable.withString(course.id)],
        readsFrom: {db.wordProgress, db.savedVocabulary},
      )
      .watch()
      .map(
        (rows) => {
          for (final r in rows)
            if ((r.readNullable<String>('text') ??
                    known[r.read<String>('word_id')])
                case final String text)
              vocabularyKey(text),
        },
      );
});
