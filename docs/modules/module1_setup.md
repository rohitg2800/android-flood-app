# Module 1: Project Setup & CI/CD Foundation

## GitHub Steps
1. `develop` branch is your integration branch — all features PR into here
2. Set up branch protection: require PRs + 1 review before merging to `main`
3. Add `.github/workflows/flutter-ci.yml` for automated Flutter tests on every PR
4. Configure GitHub Secrets:
   - `NEON_DATABASE_URL`
   - `GOOGLE_MAPS_API_KEY`
   - `FIREBASE_KEY`

## Neon DB Steps
1. Project: `flood-app-db` (ID: `muddy-sunset-31125820`)
2. Branches:
   - `main` → production
   - `dev` → development
   - `staging` → pre-release testing
3. Store connection string as GitHub Secret `NEON_DATABASE_URL`

## Flutter CI Workflow (`.github/workflows/flutter-ci.yml`)
```yaml
name: Flutter CI
on:
  pull_request:
    branches: [main, develop]
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
