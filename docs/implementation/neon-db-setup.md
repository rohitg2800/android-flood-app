# Neon DB Setup Guide

## Project Configuration

- **Project Name**: `flood-app-db`
- **Region**: `ap-south-1` (Mumbai — closest to Bihar)
- **PostgreSQL Version**: 16

## Branch Strategy

| Neon Branch | Maps To | Purpose |
|-------------|---------|----------|
| `main` | `main` GitHub branch | Production data |
| `staging` | `develop` GitHub branch | Integration testing |
| `dev` | Feature branches | Active development |
| `temp-*` | Migration testing | Auto-deleted after use |

## Environment Variables

```env
# .env.development
NEON_DATABASE_URL=postgresql://user:pass@ep-xxx.ap-south-1.aws.neon.tech/flood_app_db?sslmode=require

# .env.production
NEON_DATABASE_URL=postgresql://user:pass@ep-xxx.ap-south-1.aws.neon.tech/flood_app_db?sslmode=require
```

## Migration Workflow

1. Write migration SQL
2. Test on `neon/temp-*` branch using `prepare_database_migration`
3. Verify schema with `compare_database_schema`
4. Promote to `neon/dev` → `neon/staging` → `neon/main`

## Extensions to Enable

```sql
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";        -- UUID generation
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;  -- Query monitoring
CREATE EXTENSION IF NOT EXISTS postgis;             -- Geospatial (optional)
```

## Connection from Flutter

Flutter communicates with Neon DB via a **REST API backend** (Node.js/Express or FastAPI), NOT directly. Never expose database credentials in the Flutter app.

```
Flutter App
    ↕ HTTPS
REST API (Node/FastAPI)
    ↕ PostgreSQL connection
Neon DB
```

## All Module Schemas — Execution Order

Run in this order to respect foreign key dependencies:

1. `module-02-auth.md` → `users`, `user_sessions`
2. `module-03-alerts.md` → `flood_alerts`, `alert_subscriptions`, `notification_logs`
3. `module-04-map.md` → `flood_zones`, `water_level_stations`, `water_level_readings`, `evacuation_routes`
4. `module-05-incidents.md` → `incidents`, `incident_updates`
5. `module-06-resources.md` → `relief_camps`, `resources`, `resource_requests`
6. `module-07-admin.md` → `audit_logs`, `system_settings`, `analytics_snapshots`, views
