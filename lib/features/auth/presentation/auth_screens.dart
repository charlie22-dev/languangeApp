import '../../../shared/widgets/lingo_components.dart';
import '../../../core/localization/lingo_localizations.dart';
import '../../../core/theme/lingo_tokens.dart';

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
import '../../../shared/widgets/pip_mascot.dart';

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
    final auth = ref.watch(authStateProvider);
    final unavailable = auth.hasError;
    final creating =
        mode == AuthFormMode.register || mode == AuthFormMode.resetPassword;
    if (mode == AuthFormMode.forgotPassword &&
        !action.busy &&
        action.message != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.text('emailSentTitle')),
          leading: BackButton(onPressed: () => context.go(AppRoutes.login)),
        ),
        body: ResponsiveBody(
          child: LingoEmptyState(
            title: context.l10n.text('emailSentTitle'),
            message: context.l10n.message(action.message!),
            mood: PipMood.happy,
            action: LingoButton(
              onPressed: () => context.go(AppRoutes.login),
              child: Text(context.l10n.text('returnToLogin')),
            ),
          ),
        ),
      );
    }
    final title = switch (mode) {
      AuthFormMode.login => context.l10n.text('uib807833efc'),
      AuthFormMode.register => context.l10n.text('ui4046b58182'),
      AuthFormMode.forgotPassword => context.l10n.text('ui4c29f7f033'),
      AuthFormMode.resetPassword => context.l10n.text('ui1e83ae49d1'),
    };
    final label = switch (mode) {
      AuthFormMode.login => context.l10n.text('uiada2e9e96f'),
      AuthFormMode.register => context.l10n.text('uid672995a14'),
      AuthFormMode.forgotPassword => context.l10n.text('uib8ec554332'),
      AuthFormMode.resetPassword => context.l10n.text('ui350c355e16'),
    };
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          mode == AuthFormMode.login ? context.l10n.text('account') : label,
        ),
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
                Center(
                  child: PipMascot(
                    mood: mode == AuthFormMode.register
                        ? PipMood.celebrating
                        : PipMood.happy,
                  ),
                ),
                const SizedBox(height: LingoSpace.s24),
                Text(title, style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: LingoSpace.s8),
                Text(
                  mode == AuthFormMode.login
                      ? context.l10n.text('uicee6febc4c')
                      : context.l10n.text('ui9cf4f75313'),
                ),
                const SizedBox(height: LingoSpace.s24),
                if (unavailable) ...[
                  Text(
                    context.l10n.message(
                      auth.error is AuthFailure
                          ? (auth.error as AuthFailure).message
                          : authStartupMessage,
                    ),
                  ),
                  LingoButton.ghost(
                    onPressed: () => ref.invalidate(supabaseClientProvider),
                    child: Text(context.l10n.text('uia351235680')),
                  ),
                  const SizedBox(height: LingoSpace.s16),
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
                    validator: (value) =>
                        context.l10n.validation(AuthValidation.email(value)),
                    decoration: InputDecoration(
                      labelText: context.l10n.text('ui84add5b295'),
                      errorMaxLines: 3,
                      border: const OutlineInputBorder(),
                    ),
                    onFieldSubmitted: mode == AuthFormMode.forgotPassword
                        ? (_) => _submit()
                        : null,
                  ),
                  const SizedBox(height: LingoSpace.s16),
                ],
                if (mode != AuthFormMode.forgotPassword) ...[
                  PasswordField(
                    key: const ValueKey('auth-password'),
                    controller: _password,
                    label: context.l10n.text('ui8be3c943b1'),
                    enabled: !action.busy,
                    validator: (value) =>
                        AuthValidation.password(value, creating: creating),
                    onSubmitted: creating ? null : (_) => _submit(),
                  ),
                  const SizedBox(height: LingoSpace.s16),
                ],
                if (creating) ...[
                  PasswordField(
                    key: const ValueKey('auth-confirmation'),
                    controller: _confirmation,
                    label: context.l10n.text('ui4a7c565d4c'),
                    enabled: !action.busy,
                    validator: (value) =>
                        AuthValidation.confirmation(value, _password.text),
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: LingoSpace.s16),
                ],
                _AuthNotice(action: action),
                LingoButton(
                  onPressed: action.busy ? null : _submit,
                  child: Text(
                    action.busy ? context.l10n.text('pleaseWait') : label,
                  ),
                ),
                if (mode == AuthFormMode.login ||
                    mode == AuthFormMode.register) ...[
                  const SizedBox(height: LingoSpace.s8),
                  LingoButton.outlined(
                    onPressed: action.busy
                        ? null
                        : ref
                              .read(authControllerProvider(mode).notifier)
                              .google,
                    child: Text(context.l10n.text('uiccc5b0edaa')),
                  ),
                ],
                if (mode == AuthFormMode.login) ...[
                  LingoButton.ghost(
                    onPressed: action.busy
                        ? null
                        : () => context.go(AppRoutes.register),
                    child: Text(context.l10n.text('ui3f4f547d73')),
                  ),
                  LingoButton.ghost(
                    onPressed: action.busy
                        ? null
                        : () => context.go(AppRoutes.forgotPassword),
                    child: Text(context.l10n.text('ui4c29f7f033')),
                  ),
                ] else if (mode != AuthFormMode.resetPassword)
                  LingoButton.ghost(
                    onPressed: action.busy
                        ? null
                        : () => context.go(AppRoutes.login),
                    child: Text(context.l10n.text('ui4da821676b')),
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
      if (action.message != null) const Icon(Icons.mark_email_read_outlined),
      if (action.message != null)
        Semantics(
          liveRegion: true,
          child: Text(context.l10n.message(action.message!)),
        ),
      if (action.error != null || action.message != null)
        const SizedBox(height: LingoSpace.s16),
    ],
  );
}
