import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/core/database/app_database.dart';
import 'package:myapp/features/chat/data/chat_repository.dart';
import 'package:myapp/features/chat/domain/chat_models.dart';
import 'package:myapp/features/flashcards/data/review_repository.dart';
import 'package:myapp/features/home/domain/learning_path.dart';
import 'package:myapp/features/lessons/data/lesson_completion_repository.dart';
import 'package:myapp/features/lessons/domain/lesson_session.dart';

import 'multilingual_content_test.dart' show readCourse;
import 'support/chat_fixtures.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test(
    'completing Spanish unlocks only Spanish and enrolls only its words',
    () async {
      final es = readCourse('spanish'), fr = readCourse('french');
      final lesson = es.units.first.lessons.first;
      await LessonCompletionRepository(db).save(
        LessonResult(
          lessonId: lesson.id,
          totalExercises: 8,
          correctCount: 8,
          attempts: 8,
          perfectCount: 8,
          hearts: 3,
        ),
        wordIds: lesson.wordIds,
      );
      final records = (await db.select(db.lessonProgress).get())
          .map(
            (r) => LessonRecord(
              lessonId: r.lessonId,
              completed: r.completed,
              bestScore: r.bestScore,
            ),
          )
          .toList();
      final esPath = LearningPath.fromCourse(es, records).lessons.toList();
      final frPath = LearningPath.fromCourse(fr, records).lessons.toList();
      expect(esPath[0].availability, LessonAvailability.completed);
      expect(esPath[1].availability, LessonAvailability.available);
      expect(frPath[0].availability, LessonAvailability.available);
      expect(frPath[1].availability, LessonAvailability.locked);
      expect(await ReviewRepository(db).loadDueCards(es), hasLength(10));
      expect(await ReviewRepository(db).loadDueCards(fr), isEmpty);
      expect((await db.select(db.userStats).getSingle()).xp, 50);
    },
  );

  test(
    'chat history, last scenario and tutor replies stay in their course',
    () async {
      final repo = ChatRepository(db);
      final japanese = await repo.addUser('hello', ChatScenario.shopping);
      final french = await repo.addUser(
        'bonjour',
        ChatScenario.introductions,
        courseId: 'fr_basics_en',
      );
      await repo.complete(french, sampleTutorTurn());
      expect(await repo.load(ChatScenario.introductions), isEmpty);
      final messages = await repo.load(
        ChatScenario.introductions,
        courseId: 'fr_basics_en',
      );
      expect(messages, hasLength(2));
      expect(messages.every((m) => m.courseId == 'fr_basics_en'), isTrue);
      expect(await repo.lastScenario(), ChatScenario.shopping);
      expect(
        await repo.lastScenario(courseId: 'fr_basics_en'),
        ChatScenario.introductions,
      );
      expect((await repo.load(ChatScenario.shopping)).single.id, japanese.id);
      expect(
        await repo.load(ChatScenario.shopping, courseId: 'fr_basics_en'),
        isEmpty,
      );
    },
  );

  test(
    'version 5 retains its Japanese chat rows during the course migration',
    () async {
      await db.close();
      final legacy = AppDatabase.forTesting(
        NativeDatabase.memory(
          setup: (raw) {
            raw.execute('''
        CREATE TABLE chat_entries (id INTEGER PRIMARY KEY AUTOINCREMENT, scenario TEXT NOT NULL,
          role TEXT NOT NULL, content TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'sent', metadata TEXT NOT NULL DEFAULT '{}');
        INSERT INTO chat_entries (scenario,role,content) VALUES ('introductions','user','legacy hello');
        PRAGMA user_version = 5;
      ''');
          },
        ),
      );
      addTearDown(legacy.close);
      final repo = ChatRepository(legacy);
      final japanese = await repo.load(ChatScenario.introductions);
      expect(japanese.single.content, 'legacy hello');
      expect(japanese.single.courseId, 'ja_basics_en');
      expect(
        await repo.load(ChatScenario.introductions, courseId: 'es_basics_en'),
        isEmpty,
      );
      await repo.addUser(
        'hola',
        ChatScenario.introductions,
        courseId: 'es_basics_en',
      );
      expect(
        await repo.load(ChatScenario.introductions, courseId: 'es_basics_en'),
        hasLength(1),
      );
      expect(await repo.load(ChatScenario.introductions), hasLength(1));
    },
  );
}
