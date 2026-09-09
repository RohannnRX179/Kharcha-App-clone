class AppConstants {
  const AppConstants._();

  static const appName = 'Kharcha';
  static const defaultCurrencyCode = 'INR';
  static const timeZoneName = 'Asia/Kolkata';
  static const dbFileName = 'kharcha.sqlite';
  static const receiptsCacheDir = 'receipts';

  /// Spec §11.2: an expense (or income, same sanity bound) amount must be
  /// > 0 and ≤ ₹10,00,00,000.
  static const maxTransactionAmountPaise = 10000000000;

  /// Custom URL scheme auth emails (sign-up confirmation, password reset,
  /// resend) redirect to, so the OS hands the link back to this app instead
  /// of a dead `localhost` in a mobile browser. Must match the intent-filter
  /// data scheme/host in `AndroidManifest.xml` and the `CFBundleURLSchemes`
  /// entry in `Info.plist` exactly, and the Supabase Dashboard's Site URL
  /// (Authentication → URL Configuration) as a safety-net default for any
  /// auth email type not passing `emailRedirectTo` explicitly.
  static const authCallbackUrl = 'io.supabase.kharcha://login-callback/';
}
