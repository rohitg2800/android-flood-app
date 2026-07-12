/// Environment configuration.
/// Set these via --dart-define at build/run time when needed.
class EnvConfig {
  /// Neon Auth / Better Auth base URL.
  /// Full path is valid because Better Auth supports a base URL with a path component.
  static const betterAuthUrl = String.fromEnvironment(
    'BETTER_AUTH_URL',
    defaultValue:
        'https://ep-fragrant-bonus-aj8ovok4.neonauth.c-3.us-east-2.aws.neon.tech/neondb/auth',
  );

  /// FastAPI backend base URL.
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://opsflood-bihar-v2.onrender.com',
  );

  /// Better Auth secret.
  /// Keep empty in client builds; provide only where appropriate.
  static const betterAuthSecret = String.fromEnvironment(
    'BETTER_AUTH_SECRET',
    defaultValue: '',
  );

  /// Backward-compatible alias used by older code/tests.
  static const backendBaseUrl = apiBaseUrl;

  /// Google official Android test ad unit IDs.
  static const admobBannerIdAndroid = String.fromEnvironment(
    'ADMOB_BANNER_ID_ANDROID',
    defaultValue: 'ca-app-pub-3940256099942544/6300978111',
  );

  static const admobInterstitialIdAndroid = String.fromEnvironment(
    'ADMOB_INTERSTITIAL_ID_ANDROID',
    defaultValue: 'ca-app-pub-3940256099942544/1033173712',
  );

  /// Runtime tuning defaults.
  static const httpTimeout = Duration(seconds: 30);
  static const liveCacheTtl = Duration(minutes: 15);
}
