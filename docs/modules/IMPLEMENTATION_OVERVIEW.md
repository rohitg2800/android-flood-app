# Flood App — Module-Wise Implementation Overview

## Tech Stack
| Layer | Technology |
|---|---|
| Mobile App | Flutter / Dart |
| State Management | BLoC / Cubit |
| Database | Neon (PostgreSQL) |
| Auth | JWT + Firebase Auth |
| Push Notifications | Firebase Cloud Messaging |
| Maps | Google Maps Flutter |
| Storage | Firebase Storage |
| Charts | fl_chart |
| Offline Cache | SQLite (sqflite) |

## Module Summary
| # | Module | Branch | Priority |
|---|---|---|---|
| 1 | Project Setup & CI/CD | `develop` (base) | 🔴 Critical |
| 2 | Authentication & Users | `feature/auth-module` | 🔴 Critical |
| 3 | Flood Alerts & Notifications | `feature/alert-module` | 🔴 Critical |
| 4 | Real-Time Map & Location | `feature/map-module` | 🟡 High |
| 5 | Incident Reporting | `feature/incident-module` | 🟡 High |
| 6 | Resource & Relief Management | `feature/resources-module` | 🟡 High |
| 7 | Analytics & Admin Panel | `feature/admin-dashboard` | 🟢 Medium |

## Neon DB Branch Strategy
| Neon Branch | Maps To | Purpose |
|---|---|---|
| `main` (default) | Production | Live data |
| Feature branch | `feature/*` PRs | Schema testing |
| Temp branches | Migration testing | Auto-deleted after migration |

## Sprint Plan (Suggested)
### Sprint 1 (Weeks 1–2)
- Module 1: Setup, CI/CD, Neon project
- Module 2: Auth screens, user schema

### Sprint 2 (Weeks 3–4)
- Module 3: Alert system + FCM
- Module 4: Map integration, zones, water levels

### Sprint 3 (Weeks 5–6)
- Module 5: Incident reporting + offline sync
- Module 6: Relief camps + resources

### Sprint 4 (Weeks 7–8)
- Module 7: Admin dashboard + analytics
- End-to-end testing + UAT
- Production deployment

## Git Workflow
```
main ← develop ← feature/auth-module
                ← feature/alert-module
                ← feature/map-module
                ← feature/incident-module
                ← feature/resources-module
                ← feature/admin-dashboard
```

## Getting Started
```bash
# Clone and setup
git clone https://github.com/rohitg2800/android-flood-app
cd android-flood-app
git checkout develop
flutter pub get

# Set environment
cp .env.example .env
# Fill in NEON_DATABASE_URL, GOOGLE_MAPS_API_KEY, FIREBASE_KEY

# Run
flutter run
```
