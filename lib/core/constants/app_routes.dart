abstract final class AppRoutes {
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const resetPassword = '/reset-password';
  static const authLoading = '/auth-loading';
  static const welcome = '/welcome';
  static const startup = '/startup';
  static const languages = '/languages';
  static const dailyGoal = '/daily-goal';
  static const home = '/home';
  static const lesson = '/lesson/:id';
  static const review = '/review';
  static const reviewSession = '/review/session';
  static const profile = '/profile';

  static String lessonLocation(String id) =>
      '/lesson/${Uri.encodeComponent(id)}';
}
