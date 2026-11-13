import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/core/config/supabase_config.dart';
import 'package:myapp/features/auth/domain/auth_models.dart';

void main() {
  test(
    'email validation accepts trimmed addresses and rejects malformed input',
    () {
      expect(AuthValidation.email(' learner@example.com '), isNull);
      for (final value in ['', 'missing-at', 'a@b', 'a b@example.com']) {
        expect(AuthValidation.email(value), isNotNull);
      }
    },
  );
  test('new passwords need eight characters; sign-in accepts existing shorter passwords', () {
    expect(AuthValidation.password(''), isNotNull);
    expect(AuthValidation.password('short', creating: true), isNotNull);
    expect(AuthValidation.password('short'), isNull);
    expect(AuthValidation.password('secret123', creating: true), isNull);
    expect(AuthValidation.confirmation('secret123', 'secret123'), isNull);
    expect(AuthValidation.confirmation('different', 'secret123'), isNotNull);
  });
  test('auth error codes map to clear messages', () {
    expect(authMessageForCode('invalid_credentials'), contains('incorrect'));
    expect(
      authMessageForCode('email_not_confirmed'),
      contains('Confirm your email'),
    );
    expect(authMessageForCode('over_email_send_rate_limit'), contains('wait'));
    expect(
      authMessageForCode('email_address_not_authorized'),
      contains('email delivery'),
    );
    expect(authMessageForCode('email_send_failed'), contains('server'));
    expect(
      authMessageForCode('email_provider_disabled'),
      contains('unavailable'),
    );
    expect(authMessageForCode('network'), contains('connection'));
    expect(authMessageForCode('unknown'), contains('try again'));
  });
  test('configuration accepts only public client keys and valid URLs', () {
    expect(
      const SupabaseConfig(url: '', publishableKey: '').isConfigured,
      isFalse,
    );
    expect(
      const SupabaseConfig(
        url: 'https://example.supabase.co',
        publishableKey: 'sb_publishable_example',
      ).isConfigured,
      isTrue,
    );
    expect(
      const SupabaseConfig(
        url: 'https://example.supabase.co',
        publishableKey: 'sb_secret_private',
      ).isConfigured,
      isFalse,
    );
    String jwt(String role) =>
        'header.${base64Url.encode(utf8.encode(jsonEncode({'role': role})))}.signature';
    expect(
      SupabaseConfig(
        url: 'https://example.supabase.co',
        publishableKey: jwt('anon'),
      ).isConfigured,
      isTrue,
    );
    expect(
      SupabaseConfig(
        url: 'https://example.supabase.co',
        publishableKey: jwt('service_role'),
      ).isConfigured,
      isFalse,
    );
  });
}
