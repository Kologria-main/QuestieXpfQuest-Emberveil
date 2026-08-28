# KoQuest for Emberveil

Quest and objective markers for the Emberveil client, built from the proven [pfQuest](https://github.com/shagu/pfQuest) engine and adapted for Emberveil's Unreal-backed UI and Vanilla-style Lua API.

Current development release: **2.0.0-beta1.21**

> KoQuest is a community beta, not an official Emberveil addon. It is deliberately conservative: if the client cannot prove that a coordinate or quest state is valid, the addon hides the affected marker instead of showing a potentially wrong one.

## What it provides

- Active quest objectives on the world map and minimap.
- Small colored world-map objective circles with the same detailed hover tooltips as minimap nodes, compacted only when a zone would otherwise create an excessive number of buttons.
- Quest-turn-in markers only after official quest-level completion.
- Available quest-giver markers on the world map and minimap, filtered by level, race, class, prerequisites, the active quest log, and KoQuest's recorded completion history.
- A searchable pfQuest database and tracker.
- Correct three-state quest handling: complete, failed, or incomplete.
- Indoor parent-zone continuity without mutating the native minimap.
- Adaptive minimap update cadence and spatial node caching for dense zones.
- `/koquest` diagnostics and controlled refresh commands (`/qev` remains an alias).
- English, Russian, Simplified Chinese, and Traditional Chinese quest databases and UI support.

## Download and install

Download the primary `KoQuest_Emberveil_v2.0.0-beta1.21.zip` from this repository's [GitHub Releases page](https://github.com/Kologria-main/QuestieXpfQuest-Emberveil/releases). It is the Emberveil-launcher-compatible package: the ZIP contains `KoQuest/KoQuest.toc` directly at its root and nothing outside the runtime addon. The release asset and all readable source are hosted in this same public repository, as required by Emberveil's addon rules.

For Emberveil's launcher/site installer, use the primary ZIP. For a manual installation, exit Emberveil completely, extract it, and copy its `KoQuest` folder into `Interface\AddOns`.

The optional `*_Full_Offline_Package.zip` contains readable transactional installers:

1. Windows: double-click `INSTALL_KOQUEST.cmd`. The old `INSTALL_QUESTIE_EMBERVEIL.cmd` name remains as a compatibility launcher.
2. Linux/Wine/Proton: run `./INSTALL_KOQUEST_LINUX.sh "/path/to/Interface/AddOns" ["/path/to/SavedVariables"]`.
3. Manual: copy `addon\KoQuest` so the final path is `Interface\AddOns\KoQuest\KoQuest.toc`.

The usual Windows launcher installation is:

```text
%LOCALAPPDATA%\Programs\Azeroth Launcher\Azeroth\Binaries\Win64\Games\Emberveil\live\Azeroth\Interface\AddOns\KoQuest
```

### Updating from beta1.20 or older

Those builds used a `pfQuest` folder. The full offline installers recognize only a legacy folder whose TOC identifies **KoQuest**, back it up, migrate its settings/history into `KoQuest.lua`, and remove the duplicate. A genuine upstream pfQuest folder is left untouched.

If you update through the Emberveil launcher or install manually, exit the game and inspect `Interface\AddOns\pfQuest\pfQuest.toc`. If its title says **KoQuest**, remove that old `pfQuest` folder before installing beta1.21. Never remove it when the title says **pfQuest**. The new isolated `KoQuest` folder and genuine pfQuest can coexist.

Restart Emberveil completely after installing. See [Installation](docs/installation.md) for alternate paths, upgrades, rollback, and uninstall steps.

## Safety and privacy

- The game addon is Lua/XML/data/images only; no executable content is placed inside `Interface\AddOns\KoQuest`.
- It performs no downloads, telemetry, chat messages, or addon-channel broadcasts.
- The Windows and Linux installers are offline, verify SHA-256 hashes, stage changes on the target volume, back up an existing addon, and roll back on failure.
- Native UI child/region enumeration, tooltip hyperlink bridge calls, forced client termination, native minimap zoom mutation, dynamic code execution, and unsolicited transmissions are prohibited by automated validation.
- Party and raid interior minimap pins are hidden because the supplied API has no reliable floor-aware coordinate surface.
- Emberveil does not currently expose a verified character-wide completed-quest API. KoQuest therefore hides every completion it records, but an older quest completed before KoQuest was installed can still appear as available. The clearly labeled best-effort quest-giver setting can be disabled for a fail-closed map.
- The route arrow is disabled because Emberveil does not currently expose a safe player-facing value.

## Commands

```text
/koquest          Show diagnostics
/koquest force    Rebuild quest objectives, quest givers, and map nodes
/koquest sync     Retry completed-quest synchronization
/koquest map      Refresh map rendering and show diagnostics
```

When reporting a problem, include the `/koquest` output, client locale, exact location, quest name, what happened immediately before the issue, and whether `/reload` changes it. Use the repository's [issue tracker](https://github.com/Kologria-main/QuestieXpfQuest-Emberveil/issues).

## Verification

The validation suite parses every Lua file as Lua 5.1, verifies TOC/XML references, checks requested-locale database coverage, enforces safety contracts, executes quest-state scenarios against the real compatibility layer, validates every payload hash, tests Windows and Linux installation in isolated fake game trees, rejects tampered payloads, and fully reads the release ZIP.

Run the developer checks with:

```powershell
pnpm install --frozen-lockfile
pnpm validate
powershell -NoProfile -File .\scripts\validate-release.ps1
```

The exact beta1.21 evidence is recorded in [Release validation](docs/release-validation.md). The broader scope and remaining client-dependent checks are documented in [Testing](docs/testing.md) and [Known issues](docs/known-issues.md).

## Credits and license

KoQuest is a derivative of pfQuest, pinned to upstream commit `104f35678ca39ab1fb78b655f815cc7016f5e0c8`. Since beta1.21, the runtime folder, globals, map buckets, commands, frames, and SavedVariables use an isolated KoQuest namespace so a genuine pfQuest installation can coexist. pfQuest is copyright © 2017–2021 Eric Mauser (Shagu) and licensed under MIT. See [LICENSE](LICENSE) and [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

World of Warcraft, Emberveil, Unreal Engine, and their respective marks belong to their owners. This repository is not affiliated with or endorsed by them.
