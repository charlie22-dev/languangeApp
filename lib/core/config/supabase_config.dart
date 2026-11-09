import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final class SupabaseConfig {
  const SupabaseConfig({
    this.url = const String.fromEnvironment('SUPABASE_URL'),
    this.publishableKey = const String.fromEnvironment(
      'SUPABASE_PUBLISHABLE_KEY',
    ),
    this.authRedirect = const String.fromEnvironment(
      'AUTH_REDIRECT_URL',
      defaultValue: 'io.languagelearning.app://auth-callback',
    ),
  });
  final String url;
  final String publishableKey;
  final String authRedirect;
  bool get isConfigured {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !uri.hasAuthority ||
        !{'https', 'http'}.contains(uri.scheme)) {
      return false;
    }
    if (publishableKey.startsWith('sb_publishable_')) return true;
    // Legacy anon JWTs are also public client keys; service-role keys are rejected.
    try {
      final parts = publishableKey.split('.');
      if (parts.length != 3) return false;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      return payload is Map && payload['role'] == 'anon';
    } catch (_) {
      return false;
    }
  }
}

final supabaseConfigProvider = Provider<SupabaseConfig>(
  (ref) => const SupabaseConfig(),
);

final supabaseClientProvider = FutureProvider<SupabaseClient>((ref) async {
  final config = ref.watch(supabaseConfigProvider);
  if (!config.isConfigured) {
    throw StateError('Supabase configuration is missing');
  }
  final instance = await Supabase.initialize(
    url: config.url,
    publishableKey: config.publishableKey,
    debug: false,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );
  return instance.client;
}, retry: (count, error) => null);
