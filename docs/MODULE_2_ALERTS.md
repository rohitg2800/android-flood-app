# Module 2: Flood Alert & Notification System

## Overview
Real-time flood alerts with severity levels, push notifications via FCM, and area-based filtering.

## Implementation Status
- [x] FloodAlert model (fromJson/toJson)
- [x] Alert list screen UI
- [x] Neon DB Schema (flood_alerts + notification_log)
- [ ] AlertBloc (fetch, create, filter)
- [ ] FCM push notification integration
- [ ] Alert detail screen
- [ ] Severity filter chips

## Severity Levels
| Level    | Color   | Action           |
|----------|---------|------------------|
| Critical | Red     | Immediate evacuation |
| High     | Orange  | Prepare to evacuate |
| Medium   | Yellow  | Stay alert       |
| Low      | Green   | Monitor          |

## Neon DB
- Migration: `db/migrations/02_flood_alerts_schema.sql`
- Tables: `flood_alerts`, `notification_log`

## Branches
- Feature: `feature/alert-module`
- Merges into: `develop`
