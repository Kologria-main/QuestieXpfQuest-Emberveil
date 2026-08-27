# Changelog

## 2.0.0-beta1.21 — 2026-08-26

- Move every non-English database into a sibling `LoadOnDemand` locale addon. The core now parses English plus only the active client locale instead of loading and scanning all nine language databases at startup.
- If Emberveil records a newly installed active locale pack as disabled, enable and retry only that requested pack once; never wake the other translations.
- Build the exact quest-title lookup lazily and cache it by database revision, avoiding repeated full quest-table scans during normal quest-log reconciliation.
- Cache map-node generations and dense world-map render buckets so unchanged map refreshes reuse their prepared data.
- Fix blank world maps caused by a deferred `WORLD_MAP_UPDATE` race. KoQuest now performs one bounded immediate render, snapshots the selected map once, and uses a trailing retry only when selection or layout is still transitioning.
- Reject transient zero-size map surfaces and empty zone tables without poisoning the selection cache or hiding pins permanently.
- Extend `/koquest` with world-refresh event, immediate/deferred, retry, result, selection-key, map, and surface-size diagnostics.
- Add Lua runtime regression tests for locale loading, lazy title indexing, empty-zone recovery, zero-size layout recovery, refresh coalescing, and immediate map-event rendering.
- Install, verify, back up, roll back, and uninstall the core plus all eight managed locale packs transactionally on Windows and Linux.

## 2.0.0-beta1.20 — 2026-08-25

- Restore the small colored pfQuest objective circles to dense world maps. Every visible circle is a real hoverable/clickable pfQuest button with the original spawn, quest, progress, and drop-rate tooltip.
- Keep the original route, cluster, quest-giver, turn-in, and player-marker icons unchanged; no decorative or non-interactive dot overlay is used.
- Compact repeated locations for the same quest/spawn/item identity into a bounded 320-button world-map set. Visible circles stay on real database coordinates instead of synthetic averaged positions.
- Cache the compacted world-map set by quest-node generation, so the dense-zone scan and grouping run only when the selected map or quest nodes change.
- Extend `/koquest` diagnostics with raw/rendered world objective counts and the selected compaction grid.
- Preserve the beta1.19 quest-state, completed-history, localization, Linux/Wine/Proton, and installer hardening unchanged.

## 2.0.0-beta1.19 — 2026-08-25

- Enable database-matched available quest-giver markers by default on both the world map and minimap, filtered by eligibility, the active log, and KoQuest's recorded completion history.
- Keep an explicitly labeled control that can disable unverified quest-giver markers. Emberveil has no verified character-wide completion getter, so quests completed before KoQuest was installed remain the one unavoidable best-effort limitation.
- Keep only the original hoverable pfQuest world-map icons in dense zones; remove the experimental non-hoverable raw-dot overlay and its texture cost.
- Normalize runtime-decorated quest titles such as `[24] Weapons of Choice`, including late-loaded CT_QuestLevels compatibility, fixing localized title-to-ID matching.
- Treat any collapsed quest-log header as an incomplete snapshot; hidden quests are no longer removed from map state, history, or the tracker.
- Use Thomas's measured numeric race/class return IDs for locale-independent bitmask filtering, with the original tokens as fallback.
- Add Russian, Simplified Chinese, and Traditional Chinese text for the new safety option, and validate that those databases contain every enUS lookup ID.
- Restrict normal SavedVariables discovery to the exact supplied root, install-adjacent named data directories, and the confirmed Azeroth account root. Profile-wide scanning now requires an explicit support switch.
- Add isolated SavedVariables repair regression testing so release validation cannot touch a real player profile.
- Add the offline, hash-verifying, transactional `INSTALL_KOQUEST_LINUX.sh` installer for Linux/Wine/Proton.
- Adopt KoQuest public branding while retaining the internal `pfQuest` folder, SavedVariables, `/qev`, and old Windows launcher for compatibility.

## 2.0.0-beta1.18 — 2026-08-22

- Move the route 50 ms throttle ahead of the player-map-position bridge call, preventing high-refresh clients from invoking that bridge at render-frame frequency.
- Suspend route computation when no route nodes exist and when no route consumer is visible/enabled.
- Stop continuously drawing invisible world-map route lines while the world map is closed.
- Cap navigation-arrow visual math to about 60 Hz.
- Consolidate tracker row visual polling into one ~30 Hz tracker update instead of one full-rate callback per visible row.
- Cache successful localized zone-name to map-ID lookups.
- Unify the beta1.17 quest render-nudge deadline on `QuestieEV`, preserving true event/node coalescing and the intended near-immediate render path.
- Preserve existing minimap spatial filtering, FPS-adaptive cadence, transition backoff, world-map throttling, and beta1.17 quest behavior.

## 2.0.0-beta1.17 — 2026-08-22

- Makes accepted-quest objective markers render on the minimap/world map immediately after pfQuest finishes the NEW quest node transaction.
- Fixes a stale minimap spatial-cache race where QUEST_LOG_UPDATE could rebuild the cache before SearchQuestID inserted the new objective nodes.
- Removes the expensive full available-quest scan from the normal quest-accept path.
- Defers reward/abandon availability reconciliation by 650 ms so visible quest-state transitions render first.
- Services quest render nudges before the 200 ms map-maintenance throttle while retaining the adaptive FPS limiter and spatial minimap filtering.


## 2.0.0-beta1.16 — 2026-08-21

### Live quest/map correctness
- Fix newly available quest-giver markers being permanently hidden whenever Emberveil lacks a bulk completed-quest history API. Local pfQuest history now powers classic best-effort live availability instead of acting as a global render kill-switch.
- Fix live quest-log scanning to use Emberveil's documented first `GetNumQuestLogEntries()` return (visible row count), removing the old two-return Vanilla assumption and fixed 40-row scan.
- Apply the same quest-log row-count fix to the tracker.
- Rework active quest ID resolution to avoid undocumented `GetQuestLink()`. Unique titles resolve without changing quest-log selection; duplicate titles use the documented `GetQuestLogSelection`, `SelectQuestLogEntry`, and `GetQuestLogQuestText` path only.
- Quest events now directly invalidate minimap/world-map render caches so newly accepted/updated quests are consumed without opening the world map.
- Available quest-giver rescans are limited to quest accept/remove, player level/skill/world changes rather than every objective-progress tick.

### Map/minimap/indoor behavior
- Preserve the beta1.14+ parent-zone continuity model for houses, inns, caves, castles, and other subzones.
- Preserve event-driven indoor/outdoor minimap scale selection: `ZONE_CHANGED_INDOORS` changes environment, manual zoom only reprojects pins.
- Preserve spatial minimap node indexing and FPS-aware throttling.

### Installer
- Add the confirmed Emberveil SavedVariables layout `%LOCALAPPDATA%\Azeroth\Saved\Account\<ACCOUNT>\SavedVariables` as the priority recovery path before broad Windows user-data fallback scanning.

## 2.0.0-beta1.15.3 — 2026-08-21

- Fix Windows PowerShell 5.1 rejecting the SavedVariables scanner's initially empty `List[string]` accumulator.
- Add `AllowEmptyCollection()` to internal scanner collection parameters and an explicit null-state guard.
- Keep the beta1.15.2 broad SavedVariables discovery/recovery behavior unchanged.
- Installer still aborts transactionally if recovery code throws before installation.

## 2.0.0-beta1.15.2 — 2026-08-21

- Fix the beta1.15.1 recovery installer failing to find SavedVariables on the affected laptop because it assumed a nearby classic `WTF` directory.
- Search the Emberveil install ancestry plus `%LOCALAPPDATA%`, `%APPDATA%`, `Saved Games`, and `Documents` for pfQuest SavedVariables.
- Add a filename-independent `.lua` fallback scan in persisted-state directories for files containing `pfQuest_config`, `pfQuest_track`, or the known unsafe tracking texture path.
- Back up every matched file before mutation.
- Remove only the top-level `pfQuest_track` assignment when it can be isolated safely.
- Quarantine only a file containing the exact unsafe tracking-path signature when surgical repair is impossible.
- Stop falsely reporting that no repair is required: a missing SavedVariables location now emits a visible warning and a diagnostic log.

## 2.0.0-beta1.15.1 — 2026-08-21

- Fix a deterministic Emberveil `LUA PANIC` on machines with legacy `pfQuest_track` SavedVariables containing runtime texture paths such as `Interface\AddOns\pfQuest\img\tracking\...`.
- Persist only logical tracking query data; reconstruct texture/runtime metadata after login.
- Migrate parseable legacy `{ query, meta }` tracking state in memory.
- Installer now scans the detected Emberveil `WTF` tree before installation, backs up affected `pfQuest.lua` / `pfQuest.lua.bak` files, and removes only the unsafe top-level `pfQuest_track` assignment.
- If a known-corrupt tracking path is present but the assignment is too malformed to isolate, the installer backs up and quarantines that SavedVariables file so Emberveil can boot instead of panicking before addon load.

## 2.0.0-beta1.15 — 2026-08-21

- Preserve Emberveil's documented `GetQuestLogTitle` three-state result: `1` complete, `-1` failed, and `nil` incomplete.
- Treat Emberveil's documented quest-level `1` as the only completion proof.
  Finished counters no longer imply completion because money, hidden/scripted
  conditions, or server validation may still be outstanding.
- Include failed/completed/incomplete state in quest fingerprints so transitions rebuild tracker and map data.
- Render failed tracked quests explicitly instead of showing 100% completion.
- Gate automatic available quest-giver markers on an authoritative server
  completion snapshot. When Emberveil exposes no bulk history API, active
  objectives and turn-ins remain visible but uncertain starters are hidden.
- Stop treating every quest-log removal as completion. Only a last verified
  complete state enters local history; abandoned, failed, and uncertain
  removals are cleared and trigger reconciliation.
- Capture the documented reward call so an immediate turn-in cannot outrun the
  quest-log scan; retain that session-confirmed completion across a briefly
  stale server snapshot.
- Show automatic quest-end markers only after the official quest-level
  completion flag; incomplete and failed quests no longer advertise a
  premature turn-in location.
- Preserve the last verified parent zone while indoor zone-name APIs are temporarily blank.
- Remove the incorrect zoom-event environment toggle; zoom and zone transitions now coalesce for 80 ms before reprojection.
- Increase heavy minimap cadence to 250 ms during transitions and retain adaptive low-FPS throttling.
- Add stricter numeric/dimension guards and fail-closed native API wrappers.
- Remove inherited native memory-popup introspection and `ForceQuit` behavior.
- Remove legacy addon-channel update broadcasts; the addon performs no network messaging.
- Add reproducible validation, transactional offline installer, documentation, issue templates, CI, and release tooling.

## 2.0.0-beta1.13

- Supplied stable beta baseline.
- Direct Emberveil world-map/minimap renderer with hidden-map context recovery.
- Spatial minimap node cache and adaptive update cadence.
- Completed-quest synchronization with safe local-history fallback.
- Compatibility guards for Unreal-backed UI bridge objects.
