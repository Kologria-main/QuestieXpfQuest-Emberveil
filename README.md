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
- Load-on-demand database locales, so startup parses English plus only the active client language instead of every translation.
- `/koquest` diagnostics and controlled refresh commands (`/qev` remains an alias).
- English, Russian, Simplified Chinese, and Traditional Chinese quest databases and UI support.

## Download and install

Download the ZIP from this repository's [GitHub Releases page](https://github.com/Kologria-main/QuestieXpfQuest-Emberveil/releases). The release asset and all readable source are hosted in this same public repository, as required by Emberveil's addon rules.

After extracting the ZIP and exiting Emberveil completely:

1. Windows: double-click `INSTALL_KOQUEST.cmd`. The old `INSTALL_QUESTIE_EMBERVEIL.cmd` name remains as a compatibility launcher.
2. Linux/Wine/Proton: run `./INSTALL_KOQUEST_LINUX.sh "/path/to/Interface/AddOns"`.
3. Manual: copy every folder inside `addon` to Emberveil's `Interface\AddOns` folder. The core path must be `Interface\AddOns\pfQuest\pfQuest.toc`; the sibling `pfQuest_Locale_*` folders supply on-demand translations.

The usual Windows launcher installation is:

```text
%LOCALAPPDATA%\Programs\Azeroth Launcher\Azeroth\Binaries\Win64\Games\Emberveil\live\Azeroth\Interface\AddOns\pfQuest
```

Restart Emberveil completely after installing. See [Installation](docs/installation.md) for alternate paths, upgrades, rollback, and uninstall steps.

## Safety and privacy

- The managed game-addon folders contain Lua/XML/data/images only; no executable content is placed inside `Interface\AddOns`.
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

The validation suite parses every Lua file as Lua 5.1, verifies core and locale-pack TOC/XML references, checks requested-locale database coverage and on-demand loading behavior, enforces safety contracts, executes runtime scenarios against the real compatibility layer, validates every payload hash, tests transactional Windows and Linux installation in isolated fake game trees, rejects tampered payloads, and fully reads the release ZIP.

Run the developer checks with:

```powershell
pnpm install --frozen-lockfile
pnpm validate
powershell -NoProfile -File .\scripts\validate-release.ps1
```

The exact beta1.21 evidence is recorded in [Release validation](docs/release-validation.md). The broader scope and remaining client-dependent checks are documented in [Testing](docs/testing.md) and [Known issues](docs/known-issues.md).

## Credits and license

KoQuest is a derivative of pfQuest, pinned to upstream commit `104f35678ca39ab1fb78b655f815cc7016f5e0c8`. The internal addon folder and SavedVariables names remain `pfQuest` for upgrade compatibility. pfQuest is copyright © 2017–2021 Eric Mauser (Shagu) and licensed under MIT. See [LICENSE](LICENSE) and [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

World of Warcraft, Emberveil, Unreal Engine, and their respective marks belong to their owners. This repository is not affiliated with or endorsed by them.
