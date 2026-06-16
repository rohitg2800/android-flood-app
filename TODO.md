# TODO (Priority Issue Fixes)

## ML artifacts not in version control
- [ ] Decide DVC vs remote object storage + implement artifact fetcher
- [ ] Remove tracked model/scaler binaries from git index (keep local files working)
- [ ] Add startup hook in backend/app.py to ensure artifacts exist

## google-services.json injection
- [ ] Confirm both `android/google-services.json` and `android/app/google-services.json` handling
- [ ] Remove from git tracking if present and ensure .gitignore covers them
- [ ] Add CI step to write google-services.json from encrypted secret

## Purge ephemeral paths from git history
- [ ] Identify exact ephemeral directories in history (e.g. ios/ephemeral/ etc.)
- [ ] Run history rewrite (git filter-repo) and force-push
- [ ] Add ignore rules so they never re-enter

## Add ML inference + endpoint tests
- [ ] Add pytest test fixtures with mocked model loading (no .pt dependency)
- [ ] Add unit tests for FloodPredictor.predict() schema/shape
- [ ] Add endpoint tests for /predict/legacy, /predict/v2, /api/river-severity
- [ ] Integrate tests in CI (if not already)

## Transfer learning refactor (behind new model_version)
- [ ] Create multi-station training dataset builder
- [ ] Implement shared backbone + station conditioning + training entrypoints
- [ ] Add inference loader for the new bundle format (new model_version)
- [ ] Keep existing per-station models as fallback

