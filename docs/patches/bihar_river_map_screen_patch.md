# bihar_river_map_screen_patch

> **Moved from `lib/screens/` on 15 Jun 2026.**
> Patch notes for `lib/screens/bihar_river_map_screen.dart`.

## Problem
GoogleMap markers were not refreshing when `liveLevelsProvider` emitted a
new list — the map stayed stale until a full hot-restart.

## Fix applied
- Wrapped the `GoogleMap` widget in a `Consumer` watching `liveLevelsProvider`.
- Changed marker set construction to use `Set.of(...)` with a unique key based
  on `FloodData.stationId` so Flutter's reconciler detects the diff.
- Added a `key: ValueKey(levels.length)` on the `GoogleMap` as a fallback
  force-rebuild when the station count changes.

## Files touched
- `lib/screens/bihar_river_map_screen.dart`
