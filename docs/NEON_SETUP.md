# Neon Database Setup — Flood App

## Project Details

| Field | Value |
|---|---|
| **Project Name** | flood-app-db |
| **Project ID** | `muddy-sunset-31125820` |
| **Region** | `aws-us-east-1` |
| **PostgreSQL Version** | 17 |
| **Default Database** | `neondb` |

---

## Connection String (Pooler — use this in your backend)

```
postgresql://neondb_owner:<password>@ep-damp-star-at2nqwvc-pooler.c-9.us-east-1.aws.neon.tech/neondb?sslmode=require
```

> ⚠️ Never commit the real password. Store as `NEON_DATABASE_URL` in GitHub Secrets and your `.env` file.

---

## Neon Auth

| Field | Value |
|---|---|
| **Auth Base URL** | `https://ep-damp-star-at2nqwvc.neonauth.c-9.us-east-1.aws.neon.tech/neondb/auth` |
| **JWKS URL** | `https://ep-damp-star-at2nqwvc.neonauth.c-9.us-east-1.aws.neon.tech/neondb/auth/.well-known/jwks.json` |
| **Sign In** | `POST /sign-in/email` |
| **Sign Up** | `POST /sign-up/email` |
| **Sign Out** | `POST /sign-out` |
| **Session** | `GET /get-session` |

---

## GitHub Secrets Required

Add these in **GitHub → Settings → Secrets and variables → Actions**:

| Secret Name | Value |
|---|---|
| `NEON_DATABASE_URL` | Full connection string (with password) |
| `NEON_AUTH_URL` | `https://ep-damp-star-at2nqwvc.neonauth.c-9.us-east-1.aws.neon.tech/neondb/auth` |
| `NEON_JWKS_URL` | `https://ep-damp-star-at2nqwvc.neonauth.c-9.us-east-1.aws.neon.tech/neondb/auth/.well-known/jwks.json` |
| `API_BASE_URL` | Your backend API base URL |

---

## Row-Level Security (RLS)

All tables have RLS enabled. Access is governed by JWT claims:

| Role | Permissions |
|---|---|
| `admin` | Full access to all tables |
| `field_agent` | Read all alerts/incidents, write alerts/incidents/resources/water-levels |
| `citizen` | Read all alerts/camps, own incidents only |

JWT claims are read from `request.jwt.claims` (set by your backend before each query).

---

## Performance Indexes Created

```sql
-- flood_alerts
idx_flood_alerts_is_active    → flood_alerts(is_active)
idx_flood_alerts_severity     → flood_alerts(severity)
idx_flood_alerts_issued_at    → flood_alerts(issued_at DESC)

-- incidents  
idx_incidents_status          → incidents(status)
idx_incidents_assigned_to     → incidents(assigned_to)
idx_incidents_created_at      → incidents(created_at DESC)

-- relief_camps
idx_relief_camps_is_active    → relief_camps(is_active)

-- users
idx_users_role                → users(role)
idx_users_email               → users(email)

-- water_level_readings
idx_water_level_recorded_at   → water_level_readings(recorded_at DESC)
```

---

## Local Development

```bash
# Run app with Neon config injected
flutter run \
  --dart-define=NEON_DATABASE_URL=<your-connection-string> \
  --dart-define=NEON_AUTH_URL=https://ep-damp-star-at2nqwvc.neonauth.c-9.us-east-1.aws.neon.tech/neondb/auth \
  --dart-define=NEON_JWKS_URL=https://ep-damp-star-at2nqwvc.neonauth.c-9.us-east-1.aws.neon.tech/neondb/auth/.well-known/jwks.json
```

Or create a `.env` file (add to `.gitignore`):

```env
NEON_DATABASE_URL=postgresql://neondb_owner:<password>@ep-damp-star-at2nqwvc-pooler.c-9.us-east-1.aws.neon.tech/neondb?sslmode=require
NEON_AUTH_URL=https://ep-damp-star-at2nqwvc.neonauth.c-9.us-east-1.aws.neon.tech/neondb/auth
NEON_JWKS_URL=https://ep-damp-star-at2nqwvc.neonauth.c-9.us-east-1.aws.neon.tech/neondb/auth/.well-known/jwks.json
API_BASE_URL=http://localhost:8080/api
```
