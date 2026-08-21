# Questie Emberveil 2.0.0-beta1.18 — Performance Hardening

This build keeps the beta1.17 quest/map behavior that was verified in game and focuses only on reducing unnecessary work during normal play. No quest-database or marker-visibility policy was intentionally changed.

## Performance audit findings

The beta1.17 minimap path was already protected by a current-map spatial grid, FPS-adaptive cadence, forced-update coalescing, and world-map throttling. The audit did **not** find an unbounded per-frame node/table accumulator in the Emberveil map path. The main remaining waste was high-refresh UI work inherited from pfQuest.

## Changes

- Route processing now applies its 50 ms cap **before** calling the Emberveil player-map-position bridge. On 144/240 Hz displays this prevents the old 144/240 bridge calls per second when the route output itself can update only 20 times per second.
- When there are no route nodes, the route callback now returns after its cheap cadence guard, before player-position bridge calls, sorting, distance math, or texture work.
- Invisible world-map route lines are no longer continuously sorted/repainted while the world map is closed. Work continues only when the world-map route is visible, the minimap route is enabled, or the navigation arrow is enabled.
- Navigation-arrow trigonometry/texture work is capped to roughly 60 Hz. This does not reduce responsiveness on 60 FPS-or-lower clients and prevents high-refresh displays from multiplying visual-only Lua work.
- Tracker row visual updates are centralized in the tracker frame at roughly 30 Hz instead of installing one full-rate `OnUpdate` callback per visible tracker row.
- Zone-name-to-map-ID lookup is now cached, avoiding repeated full zone-table scans during the 250 ms location-context refresh loop.
- The beta1.17 near-immediate quest-render nudge now uses one shared `QuestieEV.questRenderNudgeAt` deadline from event through node transaction to renderer. This fixes the intended coalescing path instead of maintaining separate event/frame timer fields.

## Existing protections retained

- Current-map-only minimap node cache.
- 5x5-zone-unit spatial grid candidate filtering.
- FPS-adaptive minimap cadence.
- Slower minimap cadence during indoor/zoom transitions.
- World-map update throttle.
- Quest event coalescing and post-node-transaction cache invalidation.
- Full available-quest database scans remain excluded from ordinary quest acceptance/progress updates.
- Frame/node pools are reused rather than recreated every movement update.

## Scope / limitation

Offline analysis can verify the control flow, cache lifetime, bounded pools, package integrity, and absence of accidental high-frequency scans. Only the Emberveil client can measure actual frame time on the target PC. beta1.18 therefore keeps the changes deliberately narrow and preserves beta1.17 behavior that was already reported working in game.
