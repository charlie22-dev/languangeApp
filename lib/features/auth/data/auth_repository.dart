import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../domain/auth_models.dart';

abstract interface class AuthRepository {
  Stream<AuthIdentity?> watchIdentity();
  Future<void> signIn(String email, String password);
  Future<bool> register(String email, String password);
  Future<void> resetPassword(String email);
  Future<void> updatePassword(String password);
  Future<void> signInGoogle();
  Future<void> signOut();
}

final authRepositoryProvider = FutureProvider<AuthRepository>((ref) async {
  final config = ref.watch(supabaseConfigProvider);
  final client = await ref.watch(supabaseClientProvider.future);
  return SupabaseAuthRepository(client, redirectTo: config.authRedirect);
}, retry: (count, error) => null);

final authStateProvider = StreamProvider<AuthIdentity?>((ref) async* {
  final repository = await ref.watch(authRepositoryProvider.future);
  yield* repository.watchIdentity();
}, retry: (count, error) => null);

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this.client, {required this.redirectTo});
  final SupabaseClient client;
  final String redirectTo;
  bool _recovering = false;

  AuthIdentity? _identity(Session? session) => session == null
      ? null
      : AuthIdentity(
          id: session.user.id,
          email: session.user.email ?? '',
          needsPasswordReset: _recovering,
        );

  @override
  Stream<AuthIdentity?> watchIdentity() =>
      client.auth.onAuthStateChange.transform(
        StreamTransformer.fromHandlers(
          handleData: (event, sink) {
            if (event.event == AuthChangeEvent.passwordRecovery) {
              _recovering = true;
            }
            if (event.event == AuthChangeEvent.signedOut ||
                event.event == AuthChangeEvent.userUpdated) {
              _recovering = false;
            }
            sink.add(_identity(event.session));
          },
          handleError: (Object error, StackTrace stack, sink) {
            // Network refresh failures must not lock a cached account out of local lessons.
            final cached = client.auth.currentSession;
            if (cached != null) {
              sink.add(_identity(cached));
            } else {
              // An expired/revoked session returns to Login without an unhandled stream error.
              sink.add(null);
            }
          },
        ),
      );

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AuthFailure {
      rethrow;
    } on AuthException catch (error) {
      throw AuthFailure(authMessageForCode(error.code));
    } catch (_) {
      throw AuthFailure(authMessageForCode('network'));
    }
  }

  @override
  Future<void> signIn(String email, String password) => _guard(() async {
    await client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  });
  @override
  Future<bool> register(String email, String password) => _guard(() async {
    final response = await client.auth.signUp(
      email: email.trim(),
      password: password,
      emailRedirectTo: redirectTo,
    );
    return response.session != null;
  });
  @override
  Future<void> resetPassword(String email) => _guard(
    () =>
        client.auth.resetPasswordForEmail(email.trim(), redirectTo: redirectTo),
  );
  @override
  Future<void> updatePassword(String password) => _guard(() async {
    await client.auth.updateUser(UserAttributes(password: password));
  });
  @override
  Future<void> signInGoogle() => _guard(() async {
    final launched = await client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: redirectTo,
    );
    if (!launched) {
      throw const AuthFailure('The sign-in browser could not be opened.');
    }
  });
  @override
  Future<void> signOut() async {
    try {
      await client.auth
          .signOut(scope: SignOutScope.local)
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      if (client.auth.currentSession != null) rethrow;
    }
  }
}
