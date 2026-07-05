/// Environment configuration.
/// Set these via --dart-define or a .env loader at build time.
/// Example:
///   flutter run --dart-define=BETTER_AUTH_URL=https://your-neon-auth-url
///               --dart-define=API_BASE_URL=https://your-api.railway.app
class EnvConfig {
  /// Neon Auth (Better Auth) base URL — from Neon console.
  static const betterAuthUrl = String.fromEnvironment(
    'BETTER_AUTH_URL',
    defaultValue: 'https://your-neon-auth-url.neon.tech',
  );

  /// Your FastAPI backend base URL.
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://your-api.railway.app',
  );

  /// Better Auth secret (used server-side only — never in client builds).
  /// Included here only for reference; actual usage is in FastAPI backend.
  static const betterAuthSecret = String.fromEnvironment(
    'BETTER_AUTH_SECRET',
    defaultValue: '',
  );
}
