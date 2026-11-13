import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository.dart';
import '../domain/auth_models.dart';

final class AuthActionState {
  const AuthActionState({this.busy = false, this.message, this.error});
  final bool busy;
  final String? message;
  final String? error;
}

final authControllerProvider = NotifierProvider.autoDispose
    .family<AuthController, AuthActionState, AuthFormMode>(AuthController.new);

class AuthController extends Notifier<AuthActionState> {
  AuthController(this.mode);
  final AuthFormMode mode;
  @override
  AuthActionState build() => const AuthActionState();

  Future<void> submit(String email, String password) async {
    await _run((repository) async {
      switch (mode) {
        case AuthFormMode.login:
          await repository.signIn(email, password);
          return null;
        case AuthFormMode.register:
          final signedIn = await repository.register(email, password);
          return signedIn
              ? null
              : 'Check your email to confirm your account, then sign in.';
        case AuthFormMode.forgotPassword:
          await repository.resetPassword(email);
          return 'If an account exists for this email, a password reset link has been sent.';
        case AuthFormMode.resetPassword:
          await repository.updatePassword(password);
          return 'Your password has been updated.';
      }
    });
  }

  Future<void> google() => _run((repository) async {
    await repository.signInGoogle();
    return 'Finish signing in in the browser.';
  });

  Future<void> _run(Future<String?> Function(AuthRepository) action) async {
    if (state.busy) return;
    state = const AuthActionState(busy: true);
    try {
      final repository = await ref.read(authRepositoryProvider.future);
      final message = await action(repository);
      if (ref.mounted) state = AuthActionState(message: message);
    } on AuthFailure catch (error) {
      if (ref.mounted) state = AuthActionState(error: error.message);
    } catch (_) {
      if (ref.mounted) {
        state = const AuthActionState(error: authStartupMessage);
      }
    }
  }
}
