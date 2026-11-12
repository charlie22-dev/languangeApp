import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:myapp/features/auth/data/auth_repository.dart';
import 'package:myapp/features/auth/domain/auth_models.dart';

class MockClient extends Mock implements SupabaseClient {}

class MockAuth extends Mock implements GoTrueClient {}

class MockSession extends Mock implements Session {}

class MockUser extends Mock implements User {}

void main() {
  late MockClient client;
  late MockAuth auth;
  late MockSession session;
  late SupabaseAuthRepository repository;
  late StreamController<AuthState> events;
  setUp(() {
    client = MockClient();
    auth = MockAuth();
    session = MockSession();
    final user = MockUser();
    events = StreamController<AuthState>.broadcast(sync: true);
    when(() => client.auth).thenReturn(auth);
    when(() => auth.onAuthStateChange).thenAnswer((_) => events.stream);
    when(() => auth.currentSession).thenReturn(session);
    when(() => session.user).thenReturn(user);
    when(() => user.id).thenReturn('account-a');
    when(() => user.email).thenReturn('a@example.com');
    repository = SupabaseAuthRepository(
      client,
      redirectTo: 'io.languagelearning.app://auth-callback',
    );
  });
  tearDown(() => events.close());

  test(
    'refresh network errors retain a cached identity for offline lessons',
    () {
      final received = <AuthIdentity?>[];
      final subscription = repository.watchIdentity().listen(received.add);
      addTearDown(subscription.cancel);
      events.add(AuthState(AuthChangeEvent.initialSession, session));
      events.addError(const AuthException('Network unavailable'));
      expect(received.map((identity) => identity!.id), [
        'account-a',
        'account-a',
      ]);
    },
  );
  test('password recovery event routes to reset until password is updated', () {
    final received = <AuthIdentity?>[];
    final subscription = repository.watchIdentity().listen(received.add);
    addTearDown(subscription.cancel);
    events.add(AuthState(AuthChangeEvent.passwordRecovery, session));
    events.add(AuthState(AuthChangeEvent.userUpdated, session));
    expect(received.map((identity) => identity!.needsPasswordReset), [
      true,
      false,
    ]);
  });
  test('invalid credentials become a friendly domain failure', () async {
    when(
      () => auth.signInWithPassword(email: 'a@example.com', password: 'wrong'),
    ).thenThrow(
      const AuthException(
        'Invalid login credentials',
        code: 'invalid_credentials',
      ),
    );
    await expectLater(
      repository.signIn(' a@example.com ', 'wrong'),
      throwsA(
        isA<AuthFailure>().having(
          (error) => error.message,
          'message',
          contains('incorrect'),
        ),
      ),
    );
  });
  test(
    'expired session without cached credentials emits logged out safely',
    () {
      when(() => auth.currentSession).thenReturn(null);
      final received = <AuthIdentity?>[];
      final subscription = repository.watchIdentity().listen(received.add);
      addTearDown(subscription.cancel);
      events.addError(
        const AuthException(
          'Refresh token revoked',
          code: 'refresh_token_not_found',
        ),
      );
      expect(received, [null]);
    },
  );
}
