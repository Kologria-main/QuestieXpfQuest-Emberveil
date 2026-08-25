# Installation

Download `KoQuest_Emberveil_v2.0.0-beta1.19.zip` from this repository's GitHub release, extract the entire ZIP to a normal folder, and exit Emberveil completely before installing.

The public name is KoQuest. The installed folder remains `pfQuest` so upgrades preserve the engine's settings, history, and compatibility with existing installs.

## Windows

Double-click `INSTALL_KOQUEST.cmd`. The legacy `INSTALL_QUESTIE_EMBERVEIL.cmd` launcher is retained for existing links and calls the same installer.

The readable PowerShell installer:

- makes no network requests;
- verifies the bundled payload against `installer/payload-manifest.sha256`;
- rejects executable content inside the addon;
- backs up an existing `pfQuest` folder;
- stages and verifies the replacement on the target volume;
- restores the previous folder if installation fails.

The installer also inspects the confirmed Emberveil SavedVariables location for the old beta1.15 unsafe serialized tracking texture. It backs up the file and removes only the top-level `pfQuest_track` assignment. Normal settings and quest history are preserved. Normal installation never scans the whole user profile; broader recovery discovery requires the explicit `-AllowBroadSavedVariablesScan` support switch.

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

The addon itself is platform-neutral Lua/XML/data. The release includes a POSIX installer that performs offline SHA-256 verification, same-volume staging, backup, installed-copy verification, and rollback.

Run it with the exact `Interface/AddOns` directory:

```sh
chmod +x ./INSTALL_KOQUEST_LINUX.sh
./INSTALL_KOQUEST_LINUX.sh "$HOME/path/to/Emberveil/live/Azeroth/Interface/AddOns"
```

Common locations depend on how the launcher was installed. For Wine, start under the prefix used for Emberveil, for example:

```text
$WINEPREFIX/drive_c/users/<user>/AppData/Local/Programs/Azeroth Launcher/Azeroth/Binaries/Win64/Games/Emberveil/live/Azeroth/Interface/AddOns
```

For Steam/Proton, locate Emberveil's compatdata prefix and use its `pfx/drive_c/.../Interface/AddOns` directory. The installer deliberately requires an explicit path instead of guessing among prefixes. It never downloads anything and never modifies Wine configuration or the game executable.

Linux backups are placed under `${XDG_STATE_HOME:-$HOME/.local/state}/koquest/backups`.

## Manual installation

Copy the release's `addon/pfQuest` folder into Emberveil's `Interface/AddOns` folder. The final layout must be:

```text
Interface/AddOns/pfQuest/pfQuest.toc
Interface/AddOns/pfQuest/compat/emberveil.lua
Interface/AddOns/pfQuest/emberveil_map.lua
```

Do not create a double-nested `pfQuest/pfQuest` folder.

## Upgrade, rollback, and uninstall

- Upgrade: exit Emberveil and run the new release installer. SavedVariables are not deleted.
- Windows rollback: copy a backed-up `pfQuest` folder from `%LOCALAPPDATA%\QuestieEV\Backups` into `Interface\AddOns`.
- Linux rollback: copy a backup from `${XDG_STATE_HOME:-$HOME/.local/state}/koquest/backups` into `Interface/AddOns`.
- Uninstall: exit Emberveil and delete only `Interface/AddOns/pfQuest`. Remove `pfQuest` SavedVariables separately only if you deliberately want to reset all settings and history.
