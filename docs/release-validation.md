# Release validation: 2.0.0-beta1.19

Validation date: 2026-08-25

Target: Emberveil live client 1.12.1, launcher build/revision 2286, Windows x64

## Release result

`2.0.0-beta1.19` passed the repository's source, quest-state, package,
installer, localization-coverage, and payload-integrity gates. The exact addon
payload was then installed into the path-qualified Emberveil client and exercised
without accepting, abandoning, failing, or turning in a quest.

The tested executable was:

```text
%LOCALAPPDATA%\Programs\Azeroth Launcher\Azeroth\Binaries\Win64\Games\Emberveil\live\Azeroth\Binaries\Win64\Azeroth-Win64-Shipping.exe
```

No similarly named WoW client or unrelated game process was used for this test.

## Automated evidence

- All 146 runtime Lua files parse as Lua 5.1.
- All TOC/XML paths, version contracts, source safety contracts, and required
  release files pass validation.
- Quest-state scenarios cover complete, failed, incomplete, zero-objective,
  malformed/API-error, abandoned-removal, reward-turn-in, stale-snapshot, and
  collapsed-quest-log paths.
- The 293-file addon payload manifest verifies exactly; undeclared, missing, and
  modified files are rejected.
- Russian, Simplified Chinese, and Traditional Chinese database coverage has no
  missing IDs relative to the English item, unit, quest, zone, profession, or
  object tables.
- Windows validation-only, clean install, upgrade/backup, scoped SavedVariables
  repair, rollback, and tamper-rejection cases pass in isolated trees.
- Linux installer syntax, hash verification, staging, installation, and installed
  payload verification pass through Git Bash in an isolated tree.
- The release ZIP is checked for traversal, duplicate paths, decompression, CRC,
  required files, and exact addon manifest contents.
- The final SHA-256 is published beside the ZIP in `SHA256SUMS.txt`; reproducible
  build equality is checked after this document and the feedback audit are frozen.

## Live-client evidence

- The installer targeted only the confirmed Emberveil `Interface\AddOns` tree and
  the explicitly supplied Emberveil account SavedVariables root.
- One obsolete unsafe `pfQuest_track` assignment was removed surgically. The
  complete SavedVariables file and prior addon folder were backed up first; no
  unrelated settings were deleted.
- The AddOn List displayed `KoQuest (Emberveil, pfQuest Engine)` enabled.
- The client entered the world on the level 11 rogue Kologria in Stormwind without
  a visible Lua error, crash, frozen UI, or startup loop.
- `/koquest` reported:

  ```text
  questState ready=true sync=local-history-no-server-api
  availability=local-best-effort historyAuthoritative=false availableGivers=true
  logSnapshot=complete completed=29 history=29 liveQuestlog=9
  activeNodes covered=9/9 missing= unresolvedAudits=0
  render worldVisible=13 miniVisible=30
  ```

- Database-matched available quest-giver `!` markers were visible on both the
  Westfall world map and minimap. Known active and locally recorded completed
  quests remained filtered; the client exposes no verified API for discovering
  completions from before KoQuest was installed.
- All nine active quests had objective-node coverage. Dense Westfall rendering
  retained 13 original clickable/hoverable pfQuest summary nodes and suppressed
  997 redundant individual world-map buttons. The minimap retained 30 nearby
  individual nodes through its current-map spatial query.
- No experimental raw-dot textures were present on the world map. This preserves
  original icon tooltips and avoids hundreds of additional dense-map textures.
- The Westfall world map, minimap bridge, tracker startup, diagnostics, and a
  zone-to-continent-to-zone map transition remained responsive. Full minimap
  pins returned immediately when the continent map closed.
- The 20 Hz minimap projection reported a 0.05-second interval, 1,010 cached
  Westfall nodes, and 52 candidates in the current spatial query. The diagnostic
  rolling average was about 100 FPS; observed steady-state overlay values in the
  tested Sentinel Hill interior returned to approximately 106-113 FPS.

## Scope boundary

The live session did not alter the user's character state. Quest accept, abandon,
failure, objective completion, and reward transitions are covered by the executed
compatibility-layer tests and should also be exercised on disposable characters
as the Emberveil client evolves.

Russian and Chinese datasets are structurally complete and parse-tested, but this
pass did not have separate authenticated ruRU, zhCN, or zhTW clients available for
live font and localized-title verification. The Linux installer was tested through
Git Bash on Windows, not on every Wine, Proton, or native Linux layout. For those
reasons the public beta label remains appropriate even though all release-blocking
gates in the available environment passed.
