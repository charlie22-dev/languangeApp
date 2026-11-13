import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app/app.dart';
import 'core/config/supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: 'assets/local/client.env', isOptional: true);
  final config = SupabaseConfig.fromEnvironment(dotenv.env);
  // Keep a failed initialization retryable from the existing auth error screen.
  Future<SupabaseClient>? initialization;
  if (config.isConfigured) {
    initialization = Supabase.initialize(
      url: config.url,
      publishableKey: config.publishableKey,
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    ).then((supabase) => supabase.client);
    try {
      await initialization;
    } catch (_) {
      initialization = null;
    }
  }
  final client = initialization;
  runApp(
    ProviderScope(
      overrides: [
        if (client != null)
          supabaseClientProvider.overrideWith((ref) => client),
      ],
      child: const LanguageApp(),
    ),
  );
}
