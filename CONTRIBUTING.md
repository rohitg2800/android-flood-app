# Contributing to OpsFlood

Thank you for considering a contribution! Please read this guide before opening a pull request.

---

## Branch Strategy

| Branch | Purpose |
|---|---|
| `main` | Production-ready code; protected |
| `feat/<short-description>` | New features |
| `fix/<short-description>` | Bug fixes |
| `chore/<short-description>` | Tooling, deps, refactoring |
| `docs/<short-description>` | Documentation only |

Branch off `main`, never commit directly to it.

---

## Commit Conventions

We follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <short summary>

[optional body]
```

| Type | When to use |
|---|---|
| `feat` | New feature |
| `fix` | Bug fix |
| `test` | Tests only |
| `docs` | Documentation |
| `chore` | Build/tooling/deps |
| `ci` | CI/CD workflows |
| `perf` | Performance improvement |
| `refactor` | Code restructure (no behaviour change) |

**Examples:**
```
feat(alerts): add CRITICAL banner for HFL breach
fix(sparkline): handle empty cache gracefully
test(unit): add AlertEngine debounce test
```

---

## Pull Request Checklist

Before marking your PR ready for review, confirm:

- [ ] `flutter analyze --fatal-infos` passes with zero warnings
- [ ] `dart format --set-exit-if-changed lib/ test/` passes
- [ ] All existing tests pass (`flutter test`)
- [ ] New code is covered by unit or widget tests
- [ ] Coverage stays ≥ 60% (`flutter test --coverage`)
- [ ] If UI changed: golden tests updated (`flutter test --update-goldens test/golden/`)
- [ ] If new strings added: all 4 ARB files updated (`app_en`, `app_hi`, `app_bn`, `app_or`)
- [ ] If new interactive widget: `AccessibleButton` / `AccessibleCard` semantics applied
- [ ] PR title follows Conventional Commits format
- [ ] PR description explains **what** changed and **why**

---

## Running the Full Test Suite Locally

```bash
# 1. Dependencies + codegen
flutter pub get
flutter gen-l10n
dart run build_runner build --delete-conflicting-outputs

# 2. Lint
dart format --set-exit-if-changed lib/ test/
flutter analyze --fatal-infos

# 3. Unit + widget tests
flutter test --coverage

# 4. Goldens (first time)
flutter test --update-goldens test/golden/

# 5. Goldens (compare)
flutter test --tags golden test/golden/
```

---

## Code Style

- Follow `flutter_lints` rules (enforced by CI)
- Prefer `const` constructors wherever possible
- Keep widget `build()` methods short — extract sub-widgets
- Riverpod providers go in `lib/providers/`; one provider per file
- Screen files go in `lib/screens/`; widget files in `lib/widgets/`
- All user-facing strings must use l10n (`context.l10n.xxx`)
- New interactive widgets must use `AccessibleButton` or `AccessibleCard` from `lib/widgets/accessible_card.dart`

---

## Environment Setup

1. Copy `.env.example` → `.env` and fill in your values
2. Run `flutterfire configure` to generate `google-services.json` and `firebase_options.dart`
3. Both files are gitignored — do not commit them

---

## Reporting Issues

Open a GitHub Issue with:
- Device / Android version
- Steps to reproduce
- Expected vs actual behaviour
- Relevant logcat output (redact any PII)

---

## License

By contributing you agree your code will be released under the [MIT License](LICENSE).
