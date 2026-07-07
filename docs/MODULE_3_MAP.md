# Module 3: Real-Time Flood Map & Location

## Overview
Google Maps integration with flood zone overlays, water level station markers, and real-time data from Neon DB.

## Implementation Status
- [x] FloodMapScreen with Google Maps
- [x] Flood zone polygon overlays (UI)
- [x] Water level station markers (UI)
- [x] Neon DB Schema (flood_zones, water_level_stations, water_level_readings)
- [ ] Neon API integration for live data
- [ ] Geofencing for entry into flood zones
- [ ] Offline map caching

## Neon DB
- Migration: `db/migrations/03_map_schema.sql`
- Tables: `flood_zones`, `water_level_stations`, `water_level_readings`

## API Endpoints (To Implement)
- `GET /api/flood-zones` - All active flood zones with GeoJSON
- `GET /api/water-levels/latest` - Latest reading per station
- `GET /api/water-levels/{stationId}/history` - Historical readings

## Branches
- Feature: `feature/map-module`
- Merges into: `develop`
