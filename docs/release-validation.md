# Release validation: 2.0.0-beta1.15

Validation date: 2026-08-21

Target: Emberveil live client, Windows, character with six active quests and eight locally recorded completions

## Release result

`2.0.0-beta1.15` passed the repository's automated source, quest-state, package,
installer, and deterministic-build gates. The exact packaged addon was then
installed into the live Emberveil client and exercised without changing quest or
character state.

## Automated evidence

- All 146 runtime Lua files parse as Lua 5.1.
- All TOC/XML paths, version contracts, and safety contracts pass.
- Executed quest-state cases pass for complete, failed, incomplete, zero-objective,
  malformed/API-error, abandoned-removal, reward-turn-in, and stale-snapshot paths.
- The 293-file payload manifest verifies exactly.
- Installer validation-only, clean install, upgrade/backup, rollback, and tamper
  rejection pass in isolated game trees.
- The 310-entry release ZIP passes traversal, duplicate-path, decompression, CRC,
  and required-file checks.
- Two independent release builds produced the same SHA-256. The final value is
  published beside the ZIP in `SHA256SUMS.txt` so it does not create a
  self-referential checksum inside the archive.

## Live-client evidence

- Clean addon load and `/reload` both completed without a visible Lua error,
  crash, or frozen UI.
- The tracker rendered all six active quests and their current objective counts.
- The world map rendered 276 current quest/objective nodes after the final quest
  state reconciliation.
- Exactly one yellow turn-in marker remained, belonging to the active quest whose
  official quest-log state was complete. Automatic yellow available-quest markers
  were absent.
- `/qev` reported `questState ready=true`,
  `sync=local-history-no-server-api`, `historyAuthoritative=false`,
  `availableGivers=false`, `completed=8`, `history=8`, and `liveQuestlog=6`.
- Because Emberveil did not expose an authoritative character-wide completion
  snapshot in this session, the addon correctly failed closed: it hid every
  automatic available quest-giver marker instead of risking a marker for a quest
  already completed before installation.
- Minimap zoom-in and zoom-out both remained responsive; diagnostics recorded two
  zoom events. Interior minimap quest pins stayed hidden.
- Observed frame rate remained approximately 129-154 FPS during the final map,
  tracker, zoom, reload, and diagnostics checks.

## Scope boundary

No live quest was accepted, abandoned, failed, or turned in during this pass,
because those actions would permanently alter the user's character. Those state
transitions are covered by the executed compatibility-layer tests and should be
rechecked on disposable test characters as Emberveil's client/API evolves. A beta
label remains appropriate until broader combinations of zones, interiors, quests,
and third-party UI addons have been exercised by players.
