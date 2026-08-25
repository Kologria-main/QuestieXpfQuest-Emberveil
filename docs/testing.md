# Testing and release gates

## Automated offline gates

Every release must pass:

- Lua 5.1 parsing for all runtime Lua files.
- TOC and XML reference resolution, including case-insensitive Windows paths.
- Version synchronization across code and package metadata.
- Runtime file count/size checks and rejection of executables inside the addon.
- Static rejection of known unsafe native bridge and transmission calls.
- Contract checks for three-state quest status, completed-history authority, safe
  removal/turn-in capture, failed-state fingerprints, indoor parent continuity,
  collapsed-header preservation, localized title cleanup, numeric race/class IDs,
  and debounced zoom projection.
- Executed quest-state scenarios using the real compatibility layer: explicit completion, explicit failure, finished counters without quest-level completion, zero-objective quests, numeric zero, invalid indices, API-error fail-closed behavior, local-history gating, server-snapshot gating, abandoned/failed removal, fast reward turn-in, and stale post-turn-in snapshot handling.
- Full SHA-256 payload-manifest verification.
- ruRU, zhCN, and zhTW coverage checks requiring every base enUS item, unit, quest, zone, profession, and object ID.
- Windows installer validation-only, isolated SavedVariables repair, clean install, upgrade/backup, exact installed-hash comparison, and invalid-payload rejection in an isolated test game tree.
- Linux installer shell parsing, offline hash verification, isolated installation, and exact installed-hash comparison.
- Release ZIP entry traversal checks, duplicate-path checks, full decompression/CRC read, required-file checks, and SHA-256 generation.

## In-game acceptance matrix

The maintainer should confirm these on the current public Emberveil client before promoting a beta to stable:

1. Fresh install and `/reload` without first opening the world map.
2. Outdoor movement across a subzone boundary.
3. Enter/leave an inn or building with zoom changes.
4. Manual minimap zoom at every zoom index.
5. Browse world, continent, current-zone, and another-zone maps without corrupting current minimap pins.
6. Accept, progress, complete, fail, abandon, and turn in quests, including a zero-objective talk/exploration quest.
7. Relog with previously completed quests and verify `/koquest` synchronization
   source. If `historyAuthoritative=false`, verify automatic available starters
   are absent while active objectives and turn-ins remain; if `true`, verify
   completed starters remain absent and eligible starters remain visible.
8. Enter party and raid interiors and verify uncertain pins are hidden.
9. Test at 30, 45, and 60+ FPS or under representative load.
10. Run alongside the most common Emberveil UI addons and test with only pfQuest enabled if a conflict appears.
11. Collapse and expand every quest-log zone header; map nodes and tracker rows for hidden quests must remain stable and no false completion/removal may be recorded.
12. Repeat title matching and settings checks on ruRU, zhCN, and zhTW clients. Confirm prefixed titles (for example `[24]`) do not duplicate levels or prevent marker resolution.
13. Install and upgrade through a representative Linux Wine/Proton prefix using an explicit `Interface/AddOns` path.

Offline automation can prove syntax, packaging, safety invariants, and deterministic logic. Only the client can prove rendering and server-specific database behavior; reports must distinguish those scopes.
