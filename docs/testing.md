# Testing and release gates

## Automated offline gates

Every release must pass:

- Lua 5.1 parsing for all runtime Lua files.
- TOC and XML reference resolution, including case-insensitive Windows paths.
- Version synchronization across code and package metadata.
- Runtime namespace isolation from pfQuest globals, frames, SavedVariables,
  slash registrations, and map-node buckets.
- Runtime file count/size checks and rejection of executables inside the addon.
- Static rejection of known unsafe native bridge and transmission calls.
- Contract checks for three-state quest status, completed-history authority, safe
  removal/turn-in capture, failed-state fingerprints, indoor parent continuity,
  collapsed-header preservation, localized title cleanup, numeric race/class IDs,
  and debounced zoom projection.
- Executed quest-state scenarios using the real compatibility layer: explicit completion, explicit failure, finished counters without quest-level completion, zero-objective quests, numeric zero, invalid indices, API-error fail-closed behavior, local-history gating, server-snapshot gating, abandoned/failed removal, fast reward turn-in, and stale post-turn-in snapshot handling.
- Full SHA-256 payload-manifest verification.
- ruRU, zhCN, and zhTW coverage checks requiring every base enUS item, unit, quest, zone, profession, and object ID.
- Windows installer validation-only, isolated SavedVariables repair, legacy KoQuest namespace migration, genuine pfQuest coexistence, clean install, upgrade/backup, exact installed-hash comparison, and invalid-payload rejection in an isolated test game tree.
- Linux installer shell parsing, offline hash verification, legacy migration, isolated installation, and exact installed-hash comparison.
- Primary launcher ZIP root-layout/size/client-data checks plus traversal, duplicate-path, full decompression/CRC, required-file, and SHA-256 checks for both release archives.

## In-game acceptance matrix

The maintainer should confirm these on the current public Emberveil client before promoting a beta to stable:

1. Fresh install and `/reload` without first opening the world map.
2. Outdoor movement across a subzone boundary.
3. Enter/leave an inn or building with zoom changes.
4. Manual minimap zoom at every zoom index.
5. Browse world, continent, current-zone, and another-zone maps without corrupting current minimap pins.
6. Accept, progress, complete, fail, abandon, and turn in quests, including a zero-objective talk/exploration quest.
7. Relog with previously completed quests and verify `/koquest` synchronization
   source. In local-best-effort mode, verify KoQuest-recorded completions remain
   absent and eligible starters remain visible; an older completion unknown to
   KoQuest may appear because the client exposes no passive character-wide
   history. With authoritative history, verify all completed starters remain
   absent.
8. Enter party and raid interiors and verify uncertain pins are hidden.
9. Test at 30, 45, and 60+ FPS or under representative load.
10. Run alongside the most common Emberveil UI addons and a genuine upstream pfQuest installation; both addon folders, SavedVariables, map nodes, frames, and slash commands must remain independent.
11. Collapse and expand every quest-log zone header; map nodes and tracker rows for hidden quests must remain stable and no false completion/removal may be recorded.
12. Repeat title matching and settings checks on ruRU, zhCN, and zhTW clients. Confirm prefixed titles (for example `[24]`) do not duplicate levels or prevent marker resolution.
13. Install and upgrade through a representative Linux Wine/Proton prefix using an explicit `Interface/AddOns` path.
14. Install the primary ZIP through Emberveil's launcher and verify it produces `Interface/AddOns/KoQuest/KoQuest.toc` with no wrapper directory.

Offline automation can prove syntax, packaging, safety invariants, and deterministic logic. Only the client can prove rendering and server-specific database behavior; reports must distinguish those scopes.
