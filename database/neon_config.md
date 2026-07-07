# Neon Database Configuration — flood-app-db

## Project Details
- **Project Name:** flood-app-db
- **Project ID:** bold-wave-10613734
- **Branch:** main (ID: br-sweet-wave-ajjqjpcx)
- **Database:** neondb
- **Region:** us-east-2 (AWS)
- **Organization:** ROHIT

## Connection
Store the connection string as a GitHub Secret named `NEON_DATABASE_URL`.

> ⚠️ Never commit the raw connection string to the repository.

## Schema Modules

| Table | Module |
|---|---|
| `users` | Module 2 — Auth & User Management |
| `flood_alerts` | Module 3 — Alert & Notification System |
| `flood_zones` | Module 4 — Flood Map |
| `water_level_readings` | Module 4 — Flood Map |
| `incidents` | Module 5 — Incident Reporting |
| `relief_camps` | Module 6 — Resource Management |
| `resources` | Module 6 — Resource Management |
| `audit_logs` | Module 7 — Admin Dashboard |

## Neon Branch Strategy

| Neon Branch | Mirrors Git Branch | Purpose |
|---|---|---|
| `main` | `main` | Production data |
| `dev` | `develop` | Integration testing |
| `staging` | `staging` | Pre-prod validation |

## Setup Instructions

1. Add `NEON_DATABASE_URL` to GitHub Secrets (Settings → Secrets → Actions)
2. Use the pooled connection string for the Flutter app API layer
3. Create dev/staging branches in Neon console to mirror your Git workflow

## Useful Commands

```bash
# Test connection
psql "$NEON_DATABASE_URL"

# List tables
\dt

# Check schema
\d users
```
