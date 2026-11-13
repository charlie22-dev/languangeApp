final class AuthIdentity {
  const AuthIdentity({
    required this.id,
    required this.email,
    this.needsPasswordReset = false,
  });
  final String id;
  final String email;
  final bool needsPasswordReset;
}

final class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;
}

enum AuthFormMode { login, register, forgotPassword, resetPassword }

const authConfigurationMessage =
    'Account connection is missing from this build. Start the app with its local configuration.';
const authStartupMessage =
    'Account services could not start. Restart the app and try again.';

abstract final class AuthValidation {
  static String? email(String? value) {
    final text = value?.trim() ?? '';
    return text.length <= 254 &&
            RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(text)
        ? null
        : 'Enter a valid email address.';
  }

  static String? password(String? value, {bool creating = false}) {
    if (value == null || value.isEmpty) return 'Enter your password.';
    if (creating && value.length < 8) return 'Use at least 8 characters.';
    return null;
  }

  static String? confirmation(String? value, String password) =>
      value == password ? null : 'Passwords do not match.';
}

String authMessageForCode(String? code) => switch (code) {
  'invalid_credentials' => 'The email or password is incorrect.',
  'email_not_confirmed' => 'Confirm your email before signing in.',
  'email_address_not_authorized' => 'Confirmation email delivery is not configured for this address. Contact the app administrator.',
  'email_address_invalid' =>
    'Use a valid email address that can receive confirmation messages.',
  'email_provider_disabled' => 'Email sign-in is currently unavailable.',
  'email_send_failed' || 'unexpected_failure' => 'The server could not complete account setup. Please try again or contact the app administrator.',
  'user_already_exists' ||
  'email_exists' => 'An account already uses this email. Try signing in.',
  'weak_password' => 'Choose a stronger password with at least 8 characters.',
  'over_request_rate_limit' || 'over_email_send_rate_limit' =>
    'Too many requests. Please wait and try again.',
  'signup_disabled' => 'Registration is currently unavailable.',
  'provider_disabled' ||
  'oauth_provider_not_supported' => 'Google sign-in is currently unavailable.',
  'same_password' => 'Choose a different password.',
  'network' => 'Check your connection and try again.',
  _ => 'We could not complete this request. Please try again.',
};
