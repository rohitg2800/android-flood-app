# TODO — Android Flutter UI improvements (frontendUI)

## Plan
- Unify routing: remove duplicated/competing route generation logic.
- Standardize navigation + arguments passing across tiles, deep links, and notification handlers.
- Improve critical overlay stability/perf: throttle overlays, prune dedup IDs, reduce blur cost adaptively.
- Fix alerts filtering correctness: filter by stable station identity (not just `city`) and align with notification payload resolution.
- Optimize dashboard rebuilds: minimize refresh-triggered full tree rebuilds and keep heavy subtrees stable.

## Steps
1. Audit routing usage
   - Locate which navigation mechanism is actually used in runtime (main.dart vs app_router.dart).
   - Decide single source of truth.
2. Routing unification implementation
   - Remove/disable the unused route switch.
   - Route arguments handling: add typed helpers/validators.
3. Navigation consistency pass
   - Replace direct `Navigator.push(...)` calls from dashboard tiles / overlay actions with `AppRouter.push(...)`.
   - Ensure `stationFilter` is passed as the correct canonical station identifier.
4. Critical overlay hardening
   - Add overlay throttle (min time between overlays).
   - Prune `_shownAlertIds` (keep last N).
   - Add adaptive blur sigma based on device performance / last frame time (if feasible) or a simple conservative setting.
5. Alerts filtering fix
   - Update `AlertsScreen` filtering from `city` to stable station identity.
   - Ensure deep-link from notification payload resolves to the same key used by AlertsScreen.
6. Dashboard performance optimization
   - Refactor dashboard to isolate rebuilds (listen/select only the fields needed).
   - Make tile builders/sections const where possible.
   - Ensure refreshIndicator only rebuilds lightweight header/tiles.
7. Verify
   - Run Flutter analyze + tests (if any).
   - Smoke test: navigation between tiles, notification deep-link, overlay dismissal, alerts filter.

