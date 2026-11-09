import 'dart:async';

import 'package:myapp/features/auth/data/auth_repository.dart';
import 'package:myapp/features/auth/domain/auth_models.dart';

class MemoryAuthRepository implements AuthRepository {
  MemoryAuthRepository({this.identity});
  AuthIdentity? identity;
  final changes = StreamController<AuthIdentity?>.broadcast();
  bool failLogin = false;
  bool confirmEmail = true;
  int loginCalls = 0;
  int googleCalls = 0;
  String? resetEmail;
  String? updatedPassword;
  Completer<void>? loginGate;

  void emit(AuthIdentity? value) {
    identity = value;
    changes.add(value);
  }

  Future<void> close() => changes.close();
  @override
  Stream<AuthIdentity?> watchIdentity() async* {
    yield identity;
    yield* changes.stream;
  }

  @override
  Future<void> signIn(String email, String password) async {
    loginCalls++;
    await loginGate?.future;
    if (failLogin) {
      throw const AuthFailure('The email or password is incorrect.');
    }
    emit(AuthIdentity(id: 'account-a', email: email.trim()));
  }

  @override
  Future<bool> register(String email, String password) async {
    if (!confirmEmail) emit(AuthIdentity(id: 'account-a', email: email.trim()));
    return !confirmEmail;
  }

  @override
  Future<void> resetPassword(String email) async {
    resetEmail = email.trim();
  }

  @override
  Future<void> updatePassword(String password) async {
    updatedPassword = password;
    emit(AuthIdentity(id: identity!.id, email: identity!.email));
  }

  @override
  Future<void> signInGoogle() async {
    googleCalls++;
  }

  @override
  Future<void> signOut() async {
    emit(null);
  }
}
