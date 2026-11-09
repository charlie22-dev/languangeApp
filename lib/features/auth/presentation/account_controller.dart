import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository.dart';
import 'auth_controller.dart';

final accountControllerProvider =
    NotifierProvider.autoDispose<AccountController, AuthActionState>(
      AccountController.new,
    );

class AccountController extends Notifier<AuthActionState> {
  @override
  AuthActionState build() => const AuthActionState();

  Future<void> signOut() async {
    if (state.busy) return;
    state = const AuthActionState(busy: true);
    try {
      final repository = await ref.read(authRepositoryProvider.future);
      await repository.signOut();
      if (ref.mounted) state = const AuthActionState();
    } catch (_) {
      if (ref.mounted) {
        state = const AuthActionState(
          error: 'We could not sign you out. Please try again.',
        );
      }
    }
  }
}
