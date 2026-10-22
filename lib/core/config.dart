/// Build-time configuration. Override per build with --dart-define, e.g.
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000 --dart-define=WEB_BASE_URL=http://10.0.2.2:3000
///
/// Defaults mirror lms_k12's `.env.example`: the Laravel ERP serves /api/*, the
/// Next.js app (lms_k12) serves every screen.
class AppConfig {
  AppConfig._();

  /// Laravel ERP (login, menu rights, web handoff).
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://dev.triz.co.in',
  );

  /// Where lms_k12 (the Next.js web app) is hosted. Must be an origin the ERP
  /// trusts in config/cors.php, or the handoff ticket is refused.
  static const String webBaseUrl = String.fromEnvironment(
    'WEB_BASE_URL',
    defaultValue: 'https://dev.triz.co.in',
  );

  static const String appName = 'Teach Connect';

  /// Same limits the web app enforces in AuthContext.
  static const Duration inactivityTimeout = Duration(minutes: 30);

  static String get apiBase => apiBaseUrl.replaceAll(RegExp(r'/+$'), '');
  static String get webBase => webBaseUrl.replaceAll(RegExp(r'/+$'), '');
}
