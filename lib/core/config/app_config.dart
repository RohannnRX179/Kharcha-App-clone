/// Compile-time app configuration, per spec §5.6.
///
/// Never use `flutter_dotenv` here — it ships secrets as a readable asset.
/// Values are baked in at build time via `--dart-define-from-file`.
class AppConfig {
  const AppConfig._();

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const appEnv = String.fromEnvironment('APP_ENV', defaultValue: 'dev');

  /// Public URLs for the privacy policy / terms (spec F-15/F-18, T-M3.1/
  /// T-M3.6). Left blank until T-M3.1 actually publishes them — every
  /// caller treats an empty value as "not published yet" rather than
  /// launching a broken link.
  static const privacyPolicyUrl = String.fromEnvironment('PRIVACY_POLICY_URL');
  static const termsUrl = String.fromEnvironment('TERMS_URL');

  /// Feature flag for the Realtime listener (spec §9.6 T-4.8). Realtime is
  /// always an optimisation on top of the poll-based sync engine, never a
  /// correctness requirement — disabling it must leave the app fully
  /// correct, just slower to notice a change made on another device.
  static const realtimeEnabled = bool.fromEnvironment(
    'REALTIME_ENABLED',
    defaultValue: true,
  );

  static bool get isValid =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static void assertValid() {
    assert(
      supabaseUrl.isNotEmpty,
      'SUPABASE_URL missing — run with --dart-define-from-file=config/dev.json',
    );
    assert(
      supabaseAnonKey.isNotEmpty,
      'SUPABASE_ANON_KEY missing — run with --dart-define-from-file=config/dev.json',
    );
  }
}
