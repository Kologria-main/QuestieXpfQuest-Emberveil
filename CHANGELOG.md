# Changelog

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
