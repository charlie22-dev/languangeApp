import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/core/config/supabase_config.dart';

void main() {
  const absent = SupabaseConfig(url: '', publishableKey: '');
  const local = {
    'SUPABASE_URL': 'https://local.supabase.co',
    'SUPABASE_PUBLISHABLE_KEY': 'sb_publishable_local',
    'AUTH_REDIRECT_URL': 'example://auth-callback',
  };

  test('plain launches use the local public configuration', () {
    final config = SupabaseConfig.fromEnvironment(local, compiled: absent);
    expect(config.isConfigured, isTrue);
    expect(config.url, local['SUPABASE_URL']);
    expect(config.authRedirect, local['AUTH_REDIRECT_URL']);
  });

  test('Dart defines override the entire local URL and key pair', () {
    const compiled = SupabaseConfig(
      url: 'https://compiled.supabase.co',
      publishableKey: 'sb_publishable_compiled',
    );
    expect(
      SupabaseConfig.fromEnvironment(local, compiled: compiled),
      same(compiled),
    );
  });

  test(
    'an incomplete override cannot mix credentials from different projects',
    () {
      const incomplete = SupabaseConfig(
        url: 'https://other.supabase.co',
        publishableKey: '',
      );
      final config = SupabaseConfig.fromEnvironment(
        local,
        compiled: incomplete,
      );
      expect(config.isConfigured, isFalse);
      expect(config.publishableKey, isEmpty);
    },
  );

  test('missing optional settings do not crash configuration parsing', () {
    expect(
      SupabaseConfig.fromEnvironment(const {}, compiled: absent).isConfigured,
      isFalse,
    );
  });

  test('fallback accepts the anon alias and rejects server secrets', () {
    final alias = SupabaseConfig.fromEnvironment(const {
      'SUPABASE_URL': 'https://local.supabase.co',
      'SUPABASE_ANON_KEY': 'sb_publishable_alias',
    }, compiled: absent);
    expect(alias.isConfigured, isTrue);
    final secret = SupabaseConfig.fromEnvironment({
      ...local,
      'SUPABASE_PUBLISHABLE_KEY': 'sb_secret_private',
    }, compiled: absent);
    expect(secret.isConfigured, isFalse);
  });
}
