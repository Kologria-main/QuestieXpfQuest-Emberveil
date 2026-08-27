# KoQuest 2.0.0-beta1.21 — Fast Locale Loading and Reliable Map Refresh

This update removes the largest avoidable startup cost and fixes the map-event
race that could leave a valid zone with no KoQuest icons until `/koquest map`
was run manually.

The Discord distribution is a compact `.7z` under 20 MB. It retains the same
verified installer, complete addon payload, and all locale packs as the normal
ZIP, while omitting only repository screenshots that are not installed in game.

## Performance changes

- The core keeps the English fallback database resident and loads only the
  active non-English locale pack on demand. The other seven translations are
  not parsed or scanned during startup.
- If Emberveil initially records that active pack as disabled, KoQuest enables
  and retries only that pack once. It does not modify account JSON or load the
  inactive translations.
- Exact localized quest-title matching now builds its index only when needed
  and reuses it until the database revision changes.
- Unchanged node generations and compacted dense-map render sets are reused
  across UI refreshes instead of being flattened and regrouped repeatedly.
- Refresh work is event-driven and bounded. A map-event burst performs at most
  one immediate render per 80 ms window plus one coalesced trailing refresh.

## Map fix

- `WORLD_MAP_UPDATE` now renders synchronously while the selected zone and map
  surface are valid, so opening the full-screen map no longer depends on a
  timer surviving the client's transition sequence.
- Selection is sampled once per render. Transient unresolved selections, empty
  zone lists, and map surfaces smaller than 16 pixels are deferred without
  committing a stale cache key or permanently hiding the pin pool.
- `/koquest` reports refresh events, immediate runs/skips, deferred runs,
  retries, the last result, selected map/key, and map dimensions.

## Live result

The beta1.21 map runtime was installed into the Emberveil live client and tested
on the level 40 character Rom in Dustwallow Marsh. Opening the map without a
manual refresh displayed four quest-giver icons. Moving out to the Kalimdor
continent cleared the zone-only icons, and selecting Dustwallow again
repopulated all four automatically. Diagnostics reported six map events, four
immediate renders, two bounded burst skips, no deferred retries, and a
successful 1002x668 map render.

After that live pass, only version/release metadata and the disabled active-pack
locale recovery were added; neither changes the English map path. The final
302-file beta1.21 candidate was then installed transactionally and independently
rehashed against its manifest.

The complete payload passed Lua 5.1 parsing, locale coverage,
quest-state, on-demand locale, title-index, map-runtime, Windows install/upgrade,
rollback/tamper rejection, Linux install, and ZIP integrity validation.

---

# Previous: 2.0.0-beta1.20 — Interactive World-Map Objectives

This patch restores the small colored objective circles players expected on the
Westfall world map without bringing back the earlier non-interactive dot layer
or the unbounded 1,000-button dense-zone cost.

## What changed

- Dense world maps again show small colored pfQuest objective circles alongside
  the original route, summary, quest-giver, turn-in, and player-marker icons.
- The circles are real pfQuest buttons. Hovering shows the original unit/object,
  level, type, respawn, quest, objective progress, and drop-rate tooltip; clicking
  retains pfQuest's normal color control.
- Repeated coordinates are compacted only when a zone is dense. Grouping is
  limited to the same quest/spawn/item identity, and every displayed circle is
  placed on a real database coordinate rather than a synthetic average.
- The compacted set is cached by selected map and quest-node generation. Normal
  map redraws reuse it instead of rescanning and regrouping the database.
- `/koquest` now reports rendered/raw objective counts and the selected grid so
  dense-map behavior can be diagnosed from player reports.

## Live result

On the exact Emberveil live client, Westfall rendered 277 interactive objective
circles from 997 raw objective points, plus 12 original summary/giver icons (289
world-map nodes total). The final installed candidate displayed the expected
`Slark` / `Westfall Stew` / `Murloc Eye` tooltip from one of those circles. Zone → continent → zone transitions
kept the world circles intact and restored nearby minimap pins after closing the
map. Steady-state observed FPS returned to approximately 104–113, with the
diagnostic rolling average around 101 FPS.

All beta1.19 correctness, available-quest, completed-history, localization,
Linux/Wine/Proton, installer, and minimap protections remain unchanged.

---

# Previous: 2.0.0-beta1.19 — Correctness, Localization, and Linux

This update is driven by KoQuest page feedback and the measured UnrealRuntimeCompat database supplied by Thomas. It prioritizes truthful quest state over marker quantity.

## Correctness changes

- Available quest-giver markers are enabled by default on both map surfaces and are filtered through level, race, class, prerequisites, the active quest log, and KoQuest's recorded completion history.
- The clearly labeled **Allow Best-Effort Quest Givers (May Include Completed Quests)** control remains available for players who prefer to disable all unverified starters. Emberveil exposes no verified character-wide completion getter, so no addon can passively identify every quest completed before its installation.
- Accepted-quest objective nodes keep the original hoverable pfQuest icons on the world map. Dense zones use the existing bounded summary nodes; the experimental non-hoverable dot overlay is not shipped.
- Russian-style runtime level prefixes such as `[24]` and `[15G5]` are removed before database title matching. A CT_QuestLevels original getter loaded after KoQuest is discovered dynamically.
- Collapsed quest-log headers no longer make hidden quests look abandoned or completed, and no longer erase them from the tracker.
- Measured numeric race/class IDs are used for locale-independent quest filtering.

## Platform, language, and packaging

- Added a transactional, offline Linux/Wine/Proton installer with the same payload-hash, backup, staging, verification, and rollback policy as Windows.
- Added requested-locale validation for ruRU, zhCN, and zhTW; every base enUS item, unit, quest, zone, profession, and object ID must be present.
- KoQuest is now the public name. The `pfQuest` folder and SavedVariables names stay unchanged so upgrades preserve settings and history.
- Windows SavedVariables recovery is now bounded and release tests use an explicit isolated root. Broad profile scanning is disabled unless a support operator deliberately opts in.

## Retained performance protections

All beta1.18 route, tracker, spatial cache, fixed 20 Hz minimap projection, world-map throttle, render-nudge, and bounded-pool hardening remains in place. Removing the experimental world-map dot overlay also removes hundreds of extra textures from dense maps.

## Validation scope

Offline gates cover Lua 5.1 syntax, safety contracts, localized database coverage, quest-state simulation, collapsed-log preservation, installer isolation, payload hashes, tamper rejection, Linux installation, ZIP traversal/CRC, and deterministic builds. Target-client smoke results are recorded separately in `docs/release-validation.md`; a beta is not called stable based on offline tests alone.

---

# Previous: 2.0.0-beta1.18 — Performance Hardening

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
