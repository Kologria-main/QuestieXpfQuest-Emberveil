# Release validation: 2.0.0-beta1.22

Validation date: 2026-08-28

Target: Emberveil live client 1.12.1, launcher build/revision 2312, Windows x64

## Release result

`2.0.0-beta1.22` passed the repository's source, quest-state, package,
installer, namespace-isolation, localization-coverage, and payload-integrity
gates. The exact addon payload was installed into the path-qualified Emberveil
client and exercised at Sentinel Hill, Westfall. The live pass covered legacy
KoQuest migration, startup, active and available markers on both map surfaces,
the original objective-circle tooltip behavior, minimap recovery, and
steady-state performance.

The tested executable was:

```text
%LOCALAPPDATA%\Programs\Azeroth Launcher\Azeroth\Binaries\Win64\Games\Emberveil\live\Azeroth\Binaries\Win64\Azeroth-Win64-Shipping.exe
```

No similarly named WoW client or unrelated game process was used.

## Automated evidence

- All 146 runtime Lua files parse as Lua 5.1.
- All TOC/XML paths, version contracts, source-safety contracts, isolated runtime
  identifiers, and required release files pass validation.
- Quest-state scenarios cover complete, failed, incomplete, zero-objective,
  transient unreadable objective rows, malformed/API-error, abandoned-removal,
  reward-turn-in, stale-snapshot, and collapsed-quest-log paths.
- The 293-file addon payload manifest verifies exactly; undeclared, missing, and
  modified files are rejected.
- Russian, Simplified Chinese, and Traditional Chinese database coverage has no
  missing IDs relative to the English item, unit, quest, zone, profession, or
  object tables.
- Windows validation-only, clean install, upgrade/backup, legacy KoQuest folder
  and SavedVariables migration, genuine pfQuest coexistence, rollback, and
  tamper-rejection cases pass in isolated trees.
- Linux installer syntax, hash verification, staging, legacy migration,
  installation, and installed-payload verification pass through Git Bash in an
  isolated tree.
- The launcher archive is checked for the required `KoQuest/KoQuest.toc` root
  layout, matching directory/TOC names, safe paths, forbidden client data,
  duplicate entries, decompression, CRC, size limits, and exact manifest
  contents.
- Both release archives are built twice and compared byte-for-byte; their final
  SHA-256 values are published in `SHA256SUMS.txt`.

## Real migration evidence

- The previous beta1.20 installation at `Interface\AddOns\pfQuest` was identified
  as KoQuest by its title and `EV-` version before any migration occurred.
- Its addon directory was backed up, replaced by `Interface\AddOns\KoQuest`, and
  the installed 293-file payload matched the candidate manifest exactly.
- Character and account-wide `pfQuest.lua` files were preserved and migrated to
  `KoQuest.lua`; the migrated files contained the isolated KoQuest variables.
- An obsolete unsafe beta1.15 `pfQuest_track` assignment was removed only after a
  full-file backup. A genuine pfQuest installation is not selected by this
  migration and is preserved by the automated coexistence test.

## Live-client evidence

- The AddOn List displayed `KoQuest (Emberveil, pfQuest Engine)` enabled, with no
  duplicate legacy KoQuest folder loaded.
- The client entered the world on the level 11 rogue Kologria at Sentinel Hill,
  Westfall, without a visible Lua error, crash, frozen UI, or startup loop.
- Startup reported compatibility and map-engine version `2.0.0-beta1.22`, a
  reconciled quest state, and local best-effort completion history.
- The tracker displayed seven active quests and their objective progress.
- Database-matched available quest-giver `!` markers and active objective circles
  were visible on the minimap and Westfall world map.
- The world map retained the original route, summary, giver, and player icons.
  Its added small colored circles were the original pfQuest node buttons, not a
  replacement texture layer.
- Hovering a world-map circle displayed the expected original tooltip for
  `Great Goretusk`: level `16-17`, unit, five-minute respawn, quest
  `Goretusk Liver Pie`, and `Goretusk Liver: 0/8 36.96%`.
- Closing the world map restored the minimap nodes on the next scheduled
  projection.
- The full settings panel opened in stable source order with all labels and
  controls visible. The unsupported route-arrow checkbox was absent. Every
  remaining visible setting has a validated runtime consumer outside the config
  screen.
- The welcome screen opened cleanly, displayed only Simple Markers, Combined,
  and Spawn Points, highlighted the saved Combined mode, and Save & Close used
  the same safe application/rebuild path as the full settings panel.
- An intentionally excessive tracker font size of `999` was clamped to the safe
  maximum `32` when applied; the player's original value `12` was then restored
  and saved. The legacy `/kodb arrow` command kept the feature disabled and
  explained the missing trustworthy-facing API instead of silently toggling it.
- `/koquest` reported 1,009 cached Westfall nodes, 80 spatial candidates,
  224 visible world-map nodes, 27 visible minimap nodes, 212 visible objective
  buttons from 997 objective coordinates, and a six-percent compaction grid.
- The minimap projection ran at its healthy 0.05-second interval. After startup,
  observed steady-state FPS readings were 69, 79, 83, 87, and 88; the diagnostic
  rolling average was about 85.8 FPS.

## Scope boundary

The live session did not accept, abandon, fail, complete, or turn in a quest.
The immediate rendering fallback for Emberveil's transient unreadable objective
rows is source-validated and covered by the executed quest-state contract, but a
fresh quest-accept transition should continue to be included in community beta
testing as the client evolves.

Russian and Chinese datasets are structurally complete and parse-tested, but
separate authenticated ruRU, zhCN, and zhTW clients were not available for live
font and localized-title verification. The Linux installer was tested through
Git Bash on Windows, not every Wine, Proton, or native Linux layout. Emberveil
also exposes no verified passive API for character-wide quests completed before
KoQuest was installed. Those limits are documented in `docs/known-issues.md`, and
the public beta label remains appropriate.
