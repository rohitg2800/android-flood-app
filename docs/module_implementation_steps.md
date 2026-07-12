# Module-Wise Implementation Steps

## Project: Android Flood App
## Stack: Flutter/Dart + Neon PostgreSQL + Firebase

---

## Module 1: Project Setup & CI/CD Foundation

**GitHub Steps:**
1. `develop` branch is integration branch; all features merge here via PR
2. Branch protection: require PR + 1 review before merging to `main`
3. CI: `.github/workflows/flutter-ci.yml` runs tests on every PR
4. Secrets: `NEON_DATABASE_URL`, `GOOGLE_MAPS_API_KEY`, `FIREBASE_KEY`

**Neon DB Steps:**
1. Project: `flood-app-db`
2. Branches: `neon/main` (prod), `neon/dev` (dev), `neon/staging`
3. Store connection string as `NEON_DATABASE_URL` in GitHub Secrets

---

## Module 2: Authentication & User Management
**Branch:** `feature/auth-module`

**Steps:**
1. `lib/features/auth/` — login, register, auth_bloc
2. Firebase Auth or JWT with roles: Admin, Field Agent, Citizen
3. PR → `develop`

---

## Module 3: Flood Alert & Notification System
**Branch:** `feature/alert-module`

**Steps:**
1. `lib/features/alerts/` — model, list screen, detail screen
2. Firebase Cloud Messaging for push notifications
3. Severity levels: Low / Medium / High / Critical
4. Unit tests in `test/alerts/`

---

## Module 4: Real-Time Flood Map & Location
**Branch:** `feature/map-module`

**Steps:**
1. `google_maps_flutter` integration
2. `lib/features/map/flood_map_screen.dart` with flood zone overlays
3. Water level markers from Neon via REST API
4. Geofencing: alert when user enters flood zone

---

## Module 5: Incident Reporting & Field Agent Tools
**Branch:** `feature/incident-module`

**Steps:**
1. `lib/features/incidents/` — report form, photo upload, GPS tagging
2. Offline-first with local SQLite cache, sync to Neon when online
3. Field Agent dashboard: assigned incidents, status, route navigation
4. Firebase Storage for images, URL stored in Neon

---

## Module 6: Resource & Relief Management
**Branch:** `feature/resources-module`

**Steps:**
1. `lib/features/resources/` — relief camps, evacuation routes, inventory
2. Admin panel: add/edit camps, assign resources
3. Citizen view: nearest relief camp with directions
4. Search filters: distance, capacity, medical support

---

## Module 7: Analytics Dashboard & Admin Panel
**Branch:** `feature/admin-dashboard`

**Steps:**
1. `lib/features/admin/` — admin-only screens
2. Analytics: active alerts, incidents by area, resource utilization
3. `fl_chart` for in-app graphs
4. Export reports as CSV/PDF

---

## Branch Strategy

| Branch | Purpose |
|---|---|
| `main` | Production-ready only |
| `develop` | Integration branch |
| `feature/auth-module` | Module 2 |
| `feature/alert-module` | Module 3 |
| `feature/map-module` | Module 4 |
| `feature/incident-module` | Module 5 |
| `feature/resources-module` | Module 6 |
| `feature/admin-dashboard` | Module 7 |
