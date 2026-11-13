import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myapp/features/sync/data/remote_sync_store.dart';
import 'package:myapp/features/sync/domain/sync_record.dart';

class MockClient extends Mock implements SupabaseClient {}

class MockAuth extends Mock implements GoTrueClient {}

class MockUser extends Mock implements User {}

void main() {
  late HttpServer server;
  late SupabaseClient transport;
  late MockClient client;
  late MockAuth auth;
  late SupabaseSyncStore store;
  late List<({Uri uri, dynamic body})> requests;
  late Future<void> Function(HttpRequest, dynamic) respond;
  const stamp = '2026-11-12T08:00:00.123456Z';
  final cursor = SyncCursor(
    timestamp: DateTime.parse(stamp).microsecondsSinceEpoch,
    revision: 7,
  );
  Map<String, dynamic> delta() => {
    'schema_version': 2,
    'user_id': 'A',
    'last_synced_at': stamp,
    'revision': 8,
    'profile': null,
    'stats': null,
    'words': [],
    'lessons': [],
  };
  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    transport = SupabaseClient(
      'http://127.0.0.1:${server.port}',
      'test-public-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    client = MockClient();
    auth = MockAuth();
    final user = MockUser();
    when(() => user.id).thenReturn('A');
    when(() => client.auth).thenReturn(auth);
    when(() => auth.currentUser).thenReturn(user);
    when(() => client.from(any())).thenAnswer(
      (call) => transport.from(call.positionalArguments[0] as String),
    );
    when(() => client.rpc(any(), params: any(named: 'params'))).thenAnswer(
      (call) => transport.rpc(
        call.positionalArguments[0] as String,
        params: call.namedArguments[#params] as Map<String, dynamic>?,
      ),
    );
    store = SupabaseSyncStore(client);
    requests = [];
    respond = (request, body) async {
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode(request.uri.path.endsWith('pull_progress') ? delta() : body),
      );
    };
    server.listen((request) async {
      final body = jsonDecode(await utf8.decoder.bind(request).join());
      requests.add((uri: request.uri, body: body));
      try {
        await respond(request, body);
      } finally {
        await request.response.close();
      }
    });
  });
  tearDown(() async {
    await transport.dispose();
    await server.close(force: true);
  });

  test(
    'real HTTP requests upsert all primary keys then pull with saved cursor',
    () async {
      final snapshot = SyncSnapshot([
        SyncRecord.fromJson(SyncKind.stats, {
          'xp': 10,
          'streak': 1,
          'last_active_date': null,
          'updated_at': stamp,
        }),
        SyncRecord.fromJson(SyncKind.word, {
          'word_id': 'hello',
          'ease_factor': 2.5,
          'interval_days': 1,
          'repetitions': 1,
          'due_date': stamp,
          'updated_at': stamp,
        }),
        SyncRecord.fromJson(SyncKind.lesson, {
          'lesson_id': 'greetings',
          'completed': true,
          'best_score': 100,
          'completed_at': stamp,
          'updated_at': stamp,
        }),
        SyncRecord.fromJson(SyncKind.profile, {
          'display_name': 'Learner',
          'updated_at': stamp,
        }),
        SyncRecord.fromJson(SyncKind.activity, {
          'activity_date': '2026-11-13',
          'xp': 50,
          'updated_at': stamp,
        }),
        SyncRecord.fromJson(SyncKind.vocabulary, {
          'word_id': 'ai_example',
          'course_id': 'japanese_basics',
          'text': 'sample',
          'translation': 'example',
          'example': 'a sample sentence',
          'example_translation': 'an example sentence',
          'deleted': false,
          'updated_at': stamp,
        }),
      ]);
      final result = await store.exchange('A', snapshot, cursor: cursor);
      expect(requests, hasLength(7));
      expect(
        requests.take(6).map((r) => r.uri.queryParameters['on_conflict']),
        [
          'user_id',
          'user_id,word_id',
          'user_id,lesson_id',
          'user_id',
          'user_id,activity_date',
          'user_id,word_id',
        ],
      );
      for (final request in requests.take(6)) {
        expect(request.body[0]['user_id'], 'A');
        expect(
          DateTime.parse(request.body[0]['updated_at'] as String),
          DateTime.parse(stamp),
        );
      }
      expect(requests.last.uri.path, '/rest/v1/rpc/pull_progress');
      expect(requests.last.body['p_since'], cursor.isoTimestamp);
      expect(requests.last.body['p_after_version'], 7);
      expect(result.records, hasLength(6));
      expect(result.cursor.revision, 8);
    },
  );

  test('account mismatch is rejected before any request', () async {
    when(() => auth.currentUser).thenReturn(null);
    await expectLater(store.exchange('A', SyncSnapshot([])), throwsStateError);
    expect(requests, isEmpty);
  });

  test(
    'account change during upload prevents pull and application of response',
    () async {
      respond = (request, body) async {
        when(() => auth.currentUser).thenReturn(null);
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(body));
      };
      await expectLater(
        store.exchange(
          'A',
          SyncSnapshot([
            SyncRecord.fromJson(SyncKind.profile, {
              'display_name': 'Learner',
              'updated_at': stamp,
            }),
          ]),
        ),
        throwsStateError,
      );
      expect(requests, hasLength(1));
    },
  );

  test('server rejection leaves upload unacknowledged and does not advance to pull', () async {
    respond = (request, body) async {
      request.response.statusCode = HttpStatus.forbidden;
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({'code': '42501', 'message': 'Denied'}),
      );
    };
    await expectLater(
      store.exchange(
        'A',
        SyncSnapshot([
          SyncRecord.fromJson(SyncKind.profile, {
            'display_name': 'Learner',
            'updated_at': stamp,
          }),
        ]),
      ),
      throwsA(isA<PostgrestException>()),
    );
    expect(requests, hasLength(1));
  });
}
