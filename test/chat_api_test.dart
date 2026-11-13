import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myapp/features/chat/data/chat_api.dart';
import 'package:myapp/features/chat/domain/chat_models.dart';

import 'support/chat_fixtures.dart';

class _Client extends Mock implements SupabaseClient {}

class _Auth extends Mock implements GoTrueClient {}

class _Session extends Mock implements Session {}

class _User extends Mock implements User {}

void main() {
  late HttpServer server;
  late SupabaseClient transport;
  late _Client client;
  late _Auth auth;
  late _Session session;
  late SupabaseChatApi api;
  late int status;
  late Map<String, dynamic> body;
  late List<({String path, String? authorization, Map<String, dynamic> body})>
  requests;
  final messages = [
    ChatMessage(
      id: 1,
      scenario: ChatScenario.introductions,
      role: 'user',
      content: 'hello',
      status: 'pending',
    ),
  ];
  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    transport = SupabaseClient(
      'http://127.0.0.1:${server.port}',
      'test-public-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    client = _Client();
    auth = _Auth();
    session = _Session();
    final user = _User();
    when(() => user.id).thenReturn('A');
    when(() => client.auth).thenReturn(auth);
    when(() => client.functions).thenReturn(transport.functions);
    when(() => auth.currentUser).thenReturn(user);
    when(() => auth.currentSession).thenReturn(session);
    when(() => session.isExpired).thenReturn(false);
    when(() => session.accessToken).thenReturn('verified-user-token');
    when(() => session.user).thenReturn(user);
    api = SupabaseChatApi(client, 'A');
    status = 200;
    body = {
      'reply': sampleTutorTurn().reply,
      'translation': 'Hello',
      'corrections': [],
      'newWords': [],
    };
    requests = [];
    server.listen((request) async {
      requests.add((
        path: request.uri.path,
        authorization: request.headers.value('Authorization'),
        body: jsonDecode(
          await utf8.decoder.bind(request).join(),
        ) as Map<String, dynamic>,
      ));
      request.response.statusCode = status;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(body));
      await request.response.close();
    });
  });
  tearDown(() async {
    await transport.dispose();
    await server.close(force: true);
  });
  test(
    'uses the deployed function path, user JWT and bounded request contract',
    () async {
      final result = await api.send(messages, ChatScenario.introductions);
      expect(result.translation, 'Hello');
      expect(requests.single.path, '/functions/v1/chat');
      expect(requests.single.authorization, 'Bearer verified-user-token');
      expect(requests.single.body, {
        'messages': [
          {'role': 'user', 'content': 'hello'},
        ],
        'scenario': 'introductions',
        'level': 'beginner',
      });
    },
  );
  for (final entry in {
    401: 'chatSignInRequired',
    429: 'chatRateLimit',
    504: 'chatTimeout',
    404: 'chatNotConfigured',
  }.entries) {
    test('HTTP ${entry.key} becomes ${entry.value}', () async {
      status = entry.key;
      body = {'error': 'stable_server_error'};
      await expectLater(
        api.send(messages, ChatScenario.introductions),
        throwsA(isA<ChatFailure>().having((e) => e.key, 'key', entry.value)),
      );
    });
  }
  test('expired access tokens refresh before the function call', () async {
    when(() => session.isExpired).thenReturn(true);
    when(() => auth.refreshSession())
        .thenAnswer((_) async => AuthResponse(session: session));
    await api.send(messages, ChatScenario.introductions);
    verify(() => auth.refreshSession()).called(1);
  });
  test(
    'an account change prevents a request from using the previous account',
    () async {
      when(() => auth.currentUser).thenReturn(null);
      await expectLater(
        api.send(messages, ChatScenario.introductions),
        throwsA(
          isA<ChatFailure>().having((e) => e.key, 'key', 'chatSignInRequired'),
        ),
      );
      expect(requests, isEmpty);
    },
  );
}
