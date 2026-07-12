# Module 1: Project Setup & CI/CD Foundation

## GitHub Steps

1. `develop` branch is the integration branch — all features merge here first
2. Enable branch protection on `main`: require PR + 1 review
3. Add `.github/workflows/flutter-ci.yml` for automated testing
4. Configure GitHub Secrets:
   - `NEON_DATABASE_URL`
   - `GOOGLE_MAPS_API_KEY`
   - `FIREBASE_KEY`

## Flutter Project Structure

```
lib/
  core/
    api/          # HTTP client, interceptors
    config/       # Environment config, constants
    database/     # Neon DB connection, local SQLite
    theme/        # App theme, colors, typography
  features/
    auth/
    alerts/
    map/
    incidents/
    resources/
    admin/
  shared/
    widgets/      # Reusable UI components
    models/       # Shared data models
    utils/        # Helpers, validators
test/
assets/
docs/
```

## CI/CD Workflow

```yaml
# .github/workflows/flutter-ci.yml
name: Flutter CI
on:
  pull_request:
    branches: [develop, main]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.x'
      - run: flutter pub get
      - run: flutter test
      - run: flutter analyze
```

## Neon DB Setup

1. Create Neon project: `flood-app-db`
2. Create branches:
   - `neon/main` → production
   - `neon/dev` → development
   - `neon/staging` → pre-release
3. Store connection string in GitHub Secret: `NEON_DATABASE_URL`
4. Enable `pg_stat_statements` extension for query monitoring

```sql
-- Run on neon/dev branch
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
```
