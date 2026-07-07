# GitHub Secrets Setup for Flood App

Add the following secrets in **Settings → Secrets and variables → Actions → New repository secret**:

## 🔐 Neon Database Secrets

| Secret Name | Value | Branch |
|---|---|---|
| `NEON_DATABASE_URL` | `postgresql://neondb_owner:npg_baqZUn9vjz4B@ep-damp-star-at2nqwvc-pooler.c-9.us-east-1.aws.neon.tech/neondb?sslmode=require` | `main` (Production) |
| `NEON_DEV_DB_URL` | `postgresql://neondb_owner:npg_baqZUn9vjz4B@ep-super-morning-at2htdqp-pooler.c-9.us-east-1.aws.neon.tech/neondb?sslmode=require` | `neon/dev` |
| `NEON_STAGING_DB_URL` | `postgresql://neondb_owner:npg_baqZUn9vjz4B@ep-fancy-butterfly-atfxhk7c-pooler.c-9.us-east-1.aws.neon.tech/neondb?sslmode=require` | `neon/staging` |
| `NEON_PROJECT_ID` | `muddy-sunset-31125820` | All branches |

## 🔐 App Secrets (Add manually)

| Secret Name | Description |
|---|---|
| `GOOGLE_MAPS_API_KEY` | Google Maps Android API key |
| `FIREBASE_GOOGLE_SERVICES` | Base64 encoded google-services.json |
| `FCM_SERVER_KEY` | Firebase Cloud Messaging server key |

## Usage in Flutter

In `lib/config/env.dart`:
```dart
class Env {
  static const String dbUrl = String.fromEnvironment('NEON_DATABASE_URL');
  static const String mapsKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');
}
```

Pass at build time:
```bash
flutter build apk --dart-define=NEON_DATABASE_URL=$NEON_DATABASE_URL
```
