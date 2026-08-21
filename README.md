# Questie Emberveil

> **Installer hotfix (2026-08-21):** the first beta1.16 package contained a PowerShell parse error in the new SavedVariables priority scanner. This corrected package keeps the beta1.16 addon payload unchanged, repairs the installer, and makes the launcher run PowerShell's own AST parser before installation.


Quest and objective markers for the Emberveil client, built from the proven [pfQuest](https://github.com/shagu/pfQuest) engine and adapted for Emberveil's Unreal-backed UI and Vanilla-style Lua API.

Current release: **2.0.0-beta1.18**

> This is a community beta, not an official Emberveil addon. It is deliberately conservative: if the client cannot prove that a coordinate or quest state is valid, the addon hides the affected marker instead of showing a potentially wrong one.

## What it provides

- Active quest objectives on the world map and minimap.
- Quest-turn-in markers only after official quest-level completion, plus live available quest-giver markers using authoritative history when available and local best-effort history otherwise.
- A searchable pfQuest database and tracker.
- Correct three-state quest handling: complete, failed, or incomplete.
- Indoor parent-zone continuity without mutating the native minimap.
- Adaptive minimap update cadence and spatial node caching for dense zones.
- `/qev` diagnostics and controlled refresh commands.

## Download and install

Download the ZIP from this repository's [GitHub Releases page](https://github.com/Kologria-main/QuestieXpfQuest-Emberveil/releases). The release asset and all readable source are hosted in this same public repository, as required by Emberveil's addon rules.

After extracting the ZIP, choose either method:

1. Double-click `INSTALL_QUESTIE_EMBERVEIL.cmd`. The offline installer validates every bundled file, backs up an existing `pfQuest` folder, stages the replacement, verifies it again, and rolls back on failure.
2. For a fully manual installation, copy `addon\pfQuest` to Emberveil's `Interface\AddOns` folder so the final path is `Interface\AddOns\pfQuest\pfQuest.toc`.

The usual launcher installation is:

```text
%LOCALAPPDATA%\Programs\Azeroth Launcher\Azeroth\Binaries\Win64\Games\Emberveil\live\Azeroth\Interface\AddOns\pfQuest
```

Restart Emberveil completely after installing. See [Installation](docs/installation.md) for alternate paths, upgrades, rollback, and uninstall steps.

## Safety and privacy

- The game addon is Lua/XML/data/images only; no executable content is placed inside `Interface\AddOns\pfQuest`.
- It performs no downloads, telemetry, chat messages, or addon-channel broadcasts.
- The installer is readable PowerShell source, uses no network access, and installs only the bundled payload.
- Native UI child/region enumeration, tooltip hyperlink bridge calls, forced client termination, native minimap zoom mutation, and undocumented profiling calls are prohibited by automated validation.
- Party and raid interior minimap pins are hidden because the supplied API has no reliable floor-aware coordinate surface.
- If Emberveil does not expose a character-wide completed-quest API, available quest-giver markers use pfQuest's local history as a best-effort fallback. Diagnostics report that state as non-authoritative instead of disabling live quest availability.
- The route arrow is disabled because Emberveil does not currently expose a safe player-facing value.

## Commands

```text
/qev          Show diagnostics
/qev force    Rebuild quest objectives, quest givers, and map nodes
/qev sync     Retry completed-quest synchronization
/qev map      Refresh map rendering and show diagnostics
```

When reporting a problem, include the `/qev` output, exact location, quest name, what happened immediately before the issue, and whether `/reload` changes it. Use the repository's [issue tracker](https://github.com/Kologria-main/QuestieXpfQuest-Emberveil/issues).

## Verification

The repository's validation suite parses every Lua file as Lua 5.1, verifies TOC/XML references, checks version and safety contracts, executes quest-state scenarios against the real compatibility layer, validates every payload hash, tests clean install/upgrade/rollback paths in an isolated fake game tree, and verifies the release ZIP can be read in full.

Run the developer checks with:

```powershell
pnpm install --frozen-lockfile
pnpm validate
powershell -NoProfile -File .\scripts\validate-release.ps1
```

The exact beta1.15 evidence is recorded in [Release validation](docs/release-validation.md).
The broader scope and remaining client-dependent checks are documented in
[Testing](docs/testing.md) and [Known issues](docs/known-issues.md).

## Credits and license

Questie Emberveil is a derivative of pfQuest, pinned to upstream commit `104f35678ca39ab1fb78b655f815cc7016f5e0c8`. pfQuest is copyright © 2017–2021 Eric Mauser (Shagu) and licensed under MIT. See [LICENSE](LICENSE) and [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

World of Warcraft, Emberveil, Unreal Engine, and their respective marks belong to their owners. This repository is not affiliated with or endorsed by them.
