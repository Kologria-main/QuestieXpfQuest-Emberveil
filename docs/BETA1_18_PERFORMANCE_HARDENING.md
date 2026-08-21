# beta1.18 — Performance hardening

## Goal

Preserve beta1.17 behavior while removing unnecessary high-refresh work. The target is smooth normal gameplay with fast quest transitions, without solving latency by increasing global polling frequency.

## Audit result

The custom Emberveil minimap renderer is already structurally bounded:

- It rebuilds its spatial cache only when the current map changes or node data is marked dirty.
- Each cache rebuild replaces the old `entries`/`grid` tables, so the previous generation becomes garbage-collectable.
- Normal minimap movement queries only nearby spatial-grid cells.
- Minimap rendering is cadence-limited and backs off further when FPS is low.
- World-map and minimap frame pools grow only to the maximum simultaneously required pin count and are then reused.
- Quest queues are drained and entries removed.
- Tracker rows are hard-capped at 25.
- Route texture arrays are reused as pools rather than recreated from scratch.

No new unbounded per-frame accumulator was found in the beta1.16/beta1.17 Emberveil map/quest code.

## High-refresh hotspots fixed

### Route frame

The inherited route `OnUpdate` called `QuestieEV_SafeGetPlayerMapPosition()` before its 50 ms throttle. At 240 FPS that could invoke the bridge around 240 times/second despite route output being capped to 20 Hz. The throttle is now before the bridge call.

The route frame also used to keep world-map-only route math active while `WorldMapFrame` was closed. Heavy route processing now returns early unless one of these is actually visible/needed:

1. World-map route lines while the world map is open.
2. Minimap route lines when explicitly enabled.
3. The navigation arrow when explicitly enabled.

### Tracker

Each visible tracker row previously owned a full-rate `OnUpdate`. Tracker visual state is now refreshed from one ~30 Hz container update. Quest/event data refresh remains event-driven; this change affects only hover/background visual polling.

### Map ID resolution

`pfMap:GetMapIDByName()` previously scanned the full localized zone table for every lookup. The result is immutable during a session, so successful name-to-ID lookups are now cached.

### Quest render nudge

The event fallback timer and post-node-transaction timer previously lived on different tables (`driver` versus `QuestieEV`). They now share one deadline, preserving true coalescing and the intended ~10 ms post-transaction render path.

## Deliberately not changed

- No increase to ordinary minimap polling frequency.
- No per-frame quest database scans.
- No periodic full available-quest scan.
- No aggressive garbage collection calls.
- No frame destruction/recreation churn.
- No change to quest eligibility, indoor policy, completion semantics, or map coordinates.
