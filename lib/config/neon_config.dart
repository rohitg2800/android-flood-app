/// Neon Database & Auth Configuration for Flood App
/// All sensitive values are loaded from environment variables.
/// Never hardcode credentials — use --dart-define or a .env loader.
library neon_config;

class NeonConfig {
  // ─── Database ───────────────────────────────────────────────
  /// Full Neon connection string (pooler endpoint).
  /// Set via: flutter run --dart-define=NEON_DATABASE_URL=<value>
  static const String databaseUrl = String.fromEnvironment(
    'NEON_DATABASE_URL',
    defaultValue: '',
  );

  // ─── Neon Auth (Better Auth / JWT) ──────────────────────────
  /// Base URL of the Neon Auth service for this branch.
  static const String authBaseUrl = String.fromEnvironment(
    'NEON_AUTH_URL',
    defaultValue:
        'https://ep-damp-star-at2nqwvc.neonauth.c-9.us-east-1.aws.neon.tech/neondb/auth',
  );

  /// JWKS endpoint — used by your backend to verify JWTs.
  static const String jwksUrl = String.fromEnvironment(
    'NEON_JWKS_URL',
    defaultValue:
        'https://ep-damp-star-at2nqwvc.neonauth.c-9.us-east-1.aws.neon.tech/neondb/auth/.well-known/jwks.json',
  );

  // ─── Auth Endpoints ─────────────────────────────────────────
  static String get signInUrl => '$authBaseUrl/sign-in/email';
  static String get signUpUrl => '$authBaseUrl/sign-up/email';
  static String get signOutUrl => '$authBaseUrl/sign-out';
  static String get sessionUrl => '$authBaseUrl/get-session';
  static String get refreshUrl => '$authBaseUrl/token/refresh';

  // ─── Helpers ────────────────────────────────────────────────
  static bool get isConfigured => databaseUrl.isNotEmpty;
}
