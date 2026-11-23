/// Build-time configuration (`--dart-define=API_BASE_URL=...`).
///
/// The default is the staging server; local development uses e.g.
/// `--dart-define=API_BASE_URL=http://10.0.2.2:4000/api/v1` (Android emulator → host machine).
class ZoolConfig {
  const ZoolConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://zoolgo-api.nodeteam.site/api/v1',
  );

  /// Platform calendar (API_CONVENTIONS §6): Africa/Khartoum is a fixed UTC+2 (no DST).
  static const Duration sudanOffset = Duration(hours: 2);
}
