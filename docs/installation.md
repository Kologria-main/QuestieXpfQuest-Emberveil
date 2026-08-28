# Installation

Use `KoQuest_Emberveil_v2.0.0-beta1.21.zip` for the Emberveil launcher or a normal manual install. It contains exactly one root addon folder:

```text
KoQuest/KoQuest.toc
KoQuest/compat/emberveil.lua
KoQuest/emberveil_map.lua
```

The separate `KoQuest_Emberveil_v2.0.0-beta1.21_Full_Offline_Package.zip` contains the same runtime addon plus documentation and optional Windows/Linux installers.

## Updating from beta1.20 or older

Old KoQuest builds installed into `Interface/AddOns/pfQuest`, which can collide with the real pfQuest addon. beta1.21 uses an isolated `KoQuest` directory, SavedVariables, globals, frames, slash commands, and map-node buckets.

- Full offline installer: automatically recognizes an old `pfQuest` folder only when its TOC title says KoQuest and its version begins with `EV-`. It backs that folder up, migrates settings/history to `KoQuest.lua`, and removes the duplicate. A genuine pfQuest folder is preserved.
- Emberveil launcher/manual update: exit the game and inspect `Interface/AddOns/pfQuest/pfQuest.toc`. If the title says **KoQuest**, remove only that old `pfQuest` folder before installing beta1.21. If the title says **pfQuest**, keep it.

The new KoQuest and a genuine pfQuest can coexist. KoQuest also detects and disables a clearly identified legacy KoQuest `pfQuest` folder, then prints a removal/restart warning, as a last-resort duplicate-load guard.

## Emberveil launcher

Use the primary release ZIP. Its `KoQuest/KoQuest.toc` root layout follows Emberveil's addon packaging guide. The launcher ZIP contains no wrapper directory, installer, documentation tree, SavedVariables, cache, repository metadata, or executable content.

## Manual installation

Exit Emberveil completely, extract the primary ZIP, and copy the `KoQuest` folder into the game's `Interface/AddOns` directory. Do not create a double-nested `KoQuest/KoQuest` folder.

The usual Windows target is:

```text
%LOCALAPPDATA%\Programs\Azeroth Launcher\Azeroth\Binaries\Win64\Games\Emberveil\live\Azeroth\Interface\AddOns\KoQuest
```

## Windows full offline installer

Extract the full offline package and double-click `INSTALL_KOQUEST.cmd`. The legacy `INSTALL_QUESTIE_EMBERVEIL.cmd` launcher calls the same installer.

The readable PowerShell installer makes no network requests. It verifies the payload manifest, rejects executables in the runtime addon, stages on the target volume, backs up current/recognized-legacy KoQuest folders, verifies the installed copy, and rolls back on failure. It also performs the scoped beta1.15 SavedVariables recovery before migrating an old KoQuest namespace.

Backups and logs are stored under:

```text
%LOCALAPPDATA%\QuestieEV\Backups
%LOCALAPPDATA%\QuestieEV\Logs
```

If detection fails, drag the Emberveil `AddOns` folder onto `INSTALL_KOQUEST.cmd`, or run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\installer\Install-Questie-Emberveil.ps1 -InstallHint "L:\Path\To\Emberveil\live\Azeroth\Interface\AddOns"
```

For a known nonstandard SavedVariables location, add:

```powershell
-SavedVariablesRoot "L:\Path\To\Azeroth\Saved\Account"
```

## Linux, Wine, and Proton

Extract the full offline package, then run the POSIX installer with the exact `Interface/AddOns` path. Pass the SavedVariables directory as the optional second argument when migrating beta1.20 settings:

```sh
chmod +x ./INSTALL_KOQUEST_LINUX.sh
./INSTALL_KOQUEST_LINUX.sh \
  "$HOME/path/to/Emberveil/live/Azeroth/Interface/AddOns" \
  "$HOME/path/to/Azeroth/Saved/Account/<ACCOUNT>/SavedVariables"
```

For Wine, the AddOns directory is commonly under:

```text
$WINEPREFIX/drive_c/users/<user>/AppData/Local/Programs/Azeroth Launcher/Azeroth/Binaries/Win64/Games/Emberveil/live/Azeroth/Interface/AddOns
```

For Steam/Proton, locate Emberveil's compatdata prefix and use its `pfx/drive_c/.../Interface/AddOns` directory. The script intentionally requires an explicit path, never downloads anything, and never modifies Wine configuration or the game executable. Backups go to `${XDG_STATE_HOME:-$HOME/.local/state}/koquest/backups`.

## Rollback and uninstall

- Windows rollback: restore a backed-up `KoQuest` folder from `%LOCALAPPDATA%\QuestieEV\Backups` into `Interface\AddOns`.
- Linux rollback: restore `KoQuest` from `${XDG_STATE_HOME:-$HOME/.local/state}/koquest/backups`.
- Uninstall: exit Emberveil and delete only `Interface/AddOns/KoQuest`. Remove KoQuest SavedVariables separately only if you deliberately want to reset settings and history.
