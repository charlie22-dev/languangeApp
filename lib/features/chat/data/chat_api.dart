import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/utils/json_reader.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/chat_models.dart';

abstract interface class ChatApi {
  Future<TutorTurn> send(List<ChatMessage> messages, ChatScenario scenario);
}

final chatApiProvider = FutureProvider<ChatApi>((ref) async {
  final user = ref.watch(authStateProvider).asData?.value;
  if (user == null) throw const ChatFailure('chatSignInRequired');
  final client = await ref.watch(supabaseClientProvider.future);
  return SupabaseChatApi(client, user.id);
}, retry: (count, error) => null);

class SupabaseChatApi implements ChatApi {
  const SupabaseChatApi(this.client, this.userId);
  final SupabaseClient client;
  final String userId;
  void _checkAccount() {
    if (client.auth.currentUser?.id != userId) {
      throw const ChatFailure('chatSignInRequired');
    }
  }

  @override
  Future<TutorTurn> send(
    List<ChatMessage> messages,
    ChatScenario scenario,
  ) async {
    _checkAccount();
    try {
      final session = client.auth.currentSession;
      if (session == null) throw const ChatFailure('chatSignInRequired');
      if (session.isExpired) await client.auth.refreshSession();
      _checkAccount();
      final token = client.auth.currentSession?.accessToken;
      if (token == null) throw const ChatFailure('chatSignInRequired');
      final response = await client.functions
          .invoke(
            'chat',
            body: {
              'messages': messages.map((m) => m.toApiJson()).toList(),
              'level': 'beginner',
              'scenario': scenario.id,
            },
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 35));
      _checkAccount();
      return TutorTurn.fromJson(JsonReader.object(response.data, 'tutor'));
    } on ChatFailure {
      rethrow;
    } on TimeoutException {
      throw const ChatFailure('chatTimeout');
    } on AuthException {
      throw const ChatFailure('chatSignInRequired');
    } on FunctionException catch (error) {
      final details = error.details;
      final code = details is Map ? details['error'] : null;
      throw ChatFailure(switch ((error.status, code)) {
        (401, _) => 'chatSignInRequired',
        (429, _) => 'chatRateLimit',
        (504, _) => 'chatTimeout',
        (_, 'chat_not_configured') || (404, _) => 'chatNotConfigured',
        (400, _) || (413, _) => 'chatMessageLimit',
        _ => 'chatUnavailable',
      });
    } on FormatException {
      throw const ChatFailure('chatInvalidResponse');
    } catch (_) {
      throw const ChatFailure('chatOffline');
    }
  }
}
