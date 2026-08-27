# Release validation: 2.0.0-beta1.21

Validation date: 2026-08-26

Target: Emberveil live client 1.12.1, Windows x64

## Release result

`2.0.0-beta1.21` passed the source, runtime-scenario, localization-coverage,
package, installer, and payload-integrity gates. The exact packaged candidate
was installed transactionally into the path-qualified Emberveil client after
the game and launcher were closed. All 302 installed files matched the release
manifest.

## Automated evidence

- All 147 runtime Lua files parse as Lua 5.1.
- Core and locale-pack TOC/XML references, version contracts, source safety
  contracts, and required release files pass validation.
- Runtime scenarios cover quest-state synchronization, requested-locale
  loading/fallback, disabled active-pack recovery, lazy exact-title indexing,
  map-selection caching, zero-size layout recovery, trailing-edge refresh
  coalescing, and immediate `WORLD_MAP_UPDATE` rendering.
- Every non-English database is packaged in one of eight sibling
  `LoadOnDemand` addons; the English fallback remains in the core.
- The 302-file manifest rejects undeclared, missing, and modified files.
- Windows clean install, upgrade/backup, scoped SavedVariables repair,
  rollback, and tamper rejection pass in isolated trees.
- Linux shell syntax, staging, hash verification, install, and installed-copy
  verification pass in an isolated tree.
- The release ZIP passes path traversal, duplicate-path, decompression, CRC,
  required-file, and exact-manifest checks.

## Live-client evidence

The live pass used the final beta1.21 map code. The only runtime change afterward
was disabled active-locale pack recovery, which is outside the English map path;
the final candidate was then installed and independently rehashed.

- The client entered the world on the level 40 character Rom in Dustwallow
  Marsh without a visible Lua error, crash, frozen UI, or startup loop.
- Opening the world map without `/koquest map` displayed four quest-giver icons.
- Moving to the Kalimdor continent cleared zone-only pins; selecting Dustwallow
  again repopulated all four icons automatically.
- Final `/koquest` diagnostics reported:

  ```text
  worldRefresh events=6 immediate=4/2 deferred=0 retries=0 pending=false
  last=rendered map=15 key=1:11:Dustwallow:15 size=1002x668
  ```

- The installed candidate was independently rehashed against the bundled
  302-file manifest after installation.

## Scope boundary

The live pass exercised an English client and the world-map transition that
originally failed; a second native launch after the isolated locale-recovery
addition is not claimed. Automated tests cover non-English on-demand loading,
disabled-pack recovery, and fallback. Native-client smoke tests for every
supported locale remain a release follow-up rather than an inferred claim.

---

# Previous release validation: 2.0.0-beta1.20

Validation date: 2026-08-25

Target: Emberveil live client 1.12.1, launcher build/revision 2286, Windows x64

## Release result

`2.0.0-beta1.20` passed the repository's source, quest-state, package,
installer, localization-coverage, and payload-integrity gates. The exact addon
payload was then installed into the path-qualified Emberveil client and exercised
without abandoning, failing, or turning in a quest. The beta1.20-specific live
pass covered dense world-map rendering, objective tooltips, zone/continent map
transitions, minimap recovery, and steady-state performance.

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
- The client entered the world on the level 11 rogue Kologria at Sentinel Hill,
  Westfall, without
  a visible Lua error, crash, frozen UI, or startup loop.
- `/koquest` reported a complete quest-log snapshot, local best-effort completion
  history, available quest givers enabled, 1,009 cached Westfall nodes, and:

  ```text
  questState ready=true sync=local-history-no-server-api
  availability=local-best-effort historyAuthoritative=false availableGivers=true
  logSnapshot=complete completed=30 history=30 liveQuestlog=10
  worldDense=true worldNodes=289/1009 suppressed=720
  objectives=277/997 grid=6
  ```

- Database-matched available quest-giver `!` markers were visible on both the
  Westfall world map and minimap. Known active and locally recorded completed
  quests remained filtered; the client exposes no verified API for discovering
  completions from before KoQuest was installed.
- Dense Westfall rendering retained 12 original summary/giver icons and restored
  277 small colored objective circles from 997 raw objective coordinates. Every
  visible circle is a real pfQuest Button; no experimental raw-dot texture layer
  is present.
- Hovering a colored world-map circle in the final installed candidate displayed
  the expected original tooltip: `Slark`, level `15`, unit, 90-minute respawn,
  quest `Westfall Stew`, and `Murloc Eye: 0/3 30.84%`.
- Compaction grouped only matching quest/spawn/item identities. Each displayed
  circle uses a real source database coordinate, never an averaged or invented
  position. The selected six-percent grid bounded the dense world-map pool at
  289 total buttons.
- The Westfall world map, minimap bridge, tracker startup, diagnostics, and a
  zone-to-continent-to-zone map transition remained responsive. Full minimap
  pins returned on the first scheduled projection after the continent map closed.
- The 20 Hz minimap projection reported a 0.05-second interval, 1,009 cached
  Westfall nodes, and 80 candidates in the sampled spatial query. The diagnostic
  rolling average was about 101 FPS; observed steady-state overlay values at
  Sentinel Hill returned to approximately 104-113 FPS.

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
