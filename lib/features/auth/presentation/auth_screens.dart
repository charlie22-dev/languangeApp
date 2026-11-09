import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/constants/app_routes.dart';
import '../../../shared/widgets/password_field.dart';
import '../../../shared/widgets/responsive_body.dart';
import '../data/auth_repository.dart';
import '../domain/auth_models.dart';
import 'auth_controller.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const AuthFormScreen(mode: AuthFormMode.login);
}

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const AuthFormScreen(mode: AuthFormMode.register);
}

class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const AuthFormScreen(mode: AuthFormMode.forgotPassword);
}

class ResetPasswordScreen extends StatelessWidget {
  const ResetPasswordScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const AuthFormScreen(mode: AuthFormMode.resetPassword);
}

class AuthFormScreen extends ConsumerStatefulWidget {
  const AuthFormScreen({super.key, required this.mode});
  final AuthFormMode mode;
  @override
  ConsumerState<AuthFormScreen> createState() => _AuthFormScreenState();
}

class _AuthFormScreenState extends ConsumerState<AuthFormScreen> {
  final _key = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  void _submit() {
    if (_key.currentState?.validate() != true) return;
    FocusScope.of(context).unfocus();
    ref
        .read(authControllerProvider(widget.mode).notifier)
        .submit(_email.text, _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final mode = widget.mode;
    final action = ref.watch(authControllerProvider(mode));
    final unavailable = ref.watch(authStateProvider).hasError;
    final creating =
        mode == AuthFormMode.register || mode == AuthFormMode.resetPassword;
    final title = switch (mode) {
      AuthFormMode.login => 'Welcome back',
      AuthFormMode.register => 'Create your account',
      AuthFormMode.forgotPassword => 'Forgot password?',
      AuthFormMode.resetPassword => 'Set a new password',
    };
    final label = switch (mode) {
      AuthFormMode.login => 'Sign in',
      AuthFormMode.register => 'Register',
      AuthFormMode.forgotPassword => 'Send reset link',
      AuthFormMode.resetPassword => 'Update password',
    };
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(mode == AuthFormMode.login ? 'Account' : label),
        leading:
            mode == AuthFormMode.login || mode == AuthFormMode.resetPassword
            ? null
            : BackButton(onPressed: () => context.go(AppRoutes.login)),
      ),
      body: ResponsiveBody(
        child: Form(
          key: _key,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 12),
                Text(
                  mode == AuthFormMode.login
                      ? 'Keep your progress with your account.'
                      : 'Your learning journey belongs to you.',
                ),
                const SizedBox(height: 28),
                if (unavailable) ...[
                  const Text('Sign-in is unavailable on this build.'),
                  TextButton(
                    onPressed: () => ref.invalidate(supabaseClientProvider),
                    child: const Text('Retry connection'),
                  ),
                  const SizedBox(height: 16),
                ],
                if (mode != AuthFormMode.resetPassword) ...[
                  TextFormField(
                    key: const ValueKey('auth-email'),
                    controller: _email,
                    enabled: !action.busy,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    textInputAction: mode == AuthFormMode.forgotPassword
                        ? TextInputAction.done
                        : TextInputAction.next,
                    validator: AuthValidation.email,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      errorMaxLines: 3,
                      border: OutlineInputBorder(),
                    ),
                    onFieldSubmitted: mode == AuthFormMode.forgotPassword
                        ? (_) => _submit()
                        : null,
                  ),
                  const SizedBox(height: 16),
                ],
                if (mode != AuthFormMode.forgotPassword) ...[
                  PasswordField(
                    key: const ValueKey('auth-password'),
                    controller: _password,
                    label: 'Password',
                    enabled: !action.busy,
                    validator: (value) =>
                        AuthValidation.password(value, creating: creating),
                    onSubmitted: creating ? null : (_) => _submit(),
                  ),
                  const SizedBox(height: 16),
                ],
                if (creating) ...[
                  PasswordField(
                    key: const ValueKey('auth-confirmation'),
                    controller: _confirmation,
                    label: 'Confirm password',
                    enabled: !action.busy,
                    validator: (value) =>
                        AuthValidation.confirmation(value, _password.text),
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 16),
                ],
                _AuthNotice(action: action),
                FilledButton(
                  onPressed: action.busy ? null : _submit,
                  child: Text(action.busy ? 'Please wait…' : label),
                ),
                if (mode == AuthFormMode.login ||
                    mode == AuthFormMode.register) ...[
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: action.busy
                        ? null
                        : ref
                              .read(authControllerProvider(mode).notifier)
                              .google,
                    child: const Text('Continue with Google'),
                  ),
                ],
                if (mode == AuthFormMode.login) ...[
                  TextButton(
                    onPressed: action.busy
                        ? null
                        : () => context.go(AppRoutes.register),
                    child: const Text('Create an account'),
                  ),
                  TextButton(
                    onPressed: action.busy
                        ? null
                        : () => context.go(AppRoutes.forgotPassword),
                    child: const Text('Forgot password?'),
                  ),
                ] else if (mode != AuthFormMode.resetPassword)
                  TextButton(
                    onPressed: action.busy
                        ? null
                        : () => context.go(AppRoutes.login),
                    child: const Text('Back to sign in'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthNotice extends StatelessWidget {
  const _AuthNotice({required this.action});
  final AuthActionState action;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (action.error != null)
        Semantics(
          liveRegion: true,
          child: Text(
            action.error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      if (action.message != null)
        Semantics(liveRegion: true, child: Text(action.message!)),
      if (action.error != null || action.message != null)
        const SizedBox(height: 16),
    ],
  );
}
