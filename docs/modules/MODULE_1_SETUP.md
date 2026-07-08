# Module 1: Project Setup & CI/CD Foundation

## GitHub Steps
1. Create a `develop` branch from `main` as the integration branch
2. Set up branch protection rules: require PRs + 1 review before merging to `main`
3. Add `.github/workflows/flutter-ci.yml` for automated testing on every PR
4. Configure GitHub Secrets: `NEON_DATABASE_URL`, `GOOGLE_MAPS_API_KEY`, `FIREBASE_KEY`

## Neon DB Steps
1. Create a Neon project named `flood-app-db`
2. Create branches: `neon/main` (prod), `neon/dev` (development), `neon/staging`
3. Store connection string as GitHub Secret `NEON_DATABASE_URL`

## CI/CD Workflow (`.github/workflows/flutter-ci.yml`)
```yaml
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
      - run: flutter analyze
      - run: flutter test
```

## Branch Strategy
| Branch | Purpose |
|---|---|
| `main` | Production-ready code only |
| `develop` | Integration branch for all features |
| `feature/*` | Individual feature modules |
| `fix/*` | Bug fixes |

## Environment Variables
```
NEON_DATABASE_URL=postgresql://...
GOOGLE_MAPS_API_KEY=...
FIREBASE_KEY=...
FCM_SERVER_KEY=...
```
