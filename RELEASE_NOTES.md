# KoQuest 2.0.0-beta1.21 — Launcher, Namespace, and Quest-Node Repair

This update addresses every actionable report from the recent KoQuest addon-page comments: failed/hanging launcher downloads, the pfQuest installation collision, accepted objectives appearing only after the first kill, and low FPS in dense questing zones.

## Download and installation

- The primary release asset is now a launcher-native ZIP with `KoQuest/KoQuest.toc` directly at its root. It contains only the runtime addon—no wrapper directory, installer bundle, documentation tree, or unrelated files.
- The readable Windows/Linux installers and documentation remain available in a separately named full offline package.
- Release validation enforces Emberveil's 64 MiB ZIP, 512 MiB unpacked, 256 MiB-per-file, safe-path, root-folder, manifest-name, and no-client-data requirements and fully reads both archives.

## pfQuest coexistence and safe migration

- The runtime folder and TOC are now `KoQuest/KoQuest.toc`.
- KoQuest's globals, SavedVariables, frames, map-node buckets, popup keys, and database slash commands are isolated from pfQuest. The database commands are now `/kodb` and `/koquestdb`; `/koquest` and `/qev` remain diagnostics commands.
- The full offline installers recognize a legacy `pfQuest` directory only when its metadata clearly says KoQuest with an `EV-` version. They back it up, migrate settings/history to the new namespace, and remove the duplicate. A genuine upstream pfQuest installation is never modified.
- Launcher/manual users receive exact cleanup instructions for beta1.20-or-older KoQuest folders. A runtime guard disables only a clearly identified duplicate legacy KoQuest folder and asks the player to remove it and restart.

## Quest markers and correctness

- Accepted quest objectives no longer disappear when Emberveil advertises objective rows one frame before the rows are readable. KoQuest now renders database locations immediately and refines done/in-progress state on the next quest-log update.
- Active objective locations remain visible on both world map and minimap. Completed objective locations and completed quests continue to be removed by the official quest state and recorded history paths.
- Available quest-giver markers remain enabled by default on both map surfaces and continue to honor level, race, class, prerequisites, active quests, and every completion KoQuest can verify.
- The original hoverable/clickable colored objective circles and quest icons are retained. Dense maps compact only matching quest/spawn/item identities and use real database coordinates.

## Performance

- The minimap stays at the measured 20 Hz cadence during map/zoom transitions and on healthy systems, but steps down to 13.3 or 10 Hz when smoothed FPS is already below 50 or 30. It never returns to the visibly laggy old 4–7 Hz behavior.
- Repeated highlight hide and pin show/hide calls are skipped when the visual state is already correct.
- Dense world-map objectives remain tooltip-capable real buttons, with the upper button budget reduced from 320 to 240 to lower UI/frame pressure.

## Verification

The release gates cover Lua 5.1 parsing, runtime namespace isolation, localized database coverage, quest-state simulation, packaging constraints, deterministic archive generation, SHA-256 payload integrity, Windows legacy migration, genuine pfQuest coexistence, Linux migration, transactional rollback, and tamper rejection. Target-client results are recorded in `docs/release-validation.md`.
