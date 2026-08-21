# Installation

## Recommended offline installer

1. Download `Questie_Emberveil_v2.0.0-beta1.15.zip` from this repository's GitHub release.
2. Extract the entire ZIP to a normal folder. Do not run the installer from inside the ZIP preview.
3. Exit Emberveil completely.
4. Double-click `INSTALL_QUESTIE_EMBERVEIL.cmd`.
5. Restart Emberveil and enable `pfQuest` in the AddOns list if it is not already enabled.

The installer contains readable PowerShell source and makes no network requests. It verifies the bundled payload against `installer/payload-manifest.sha256`, rejects executable files inside the addon, backs up an existing `pfQuest`, installs through a same-volume staging directory, verifies the installed copy, and restores the previous folder if anything fails.

Backups and logs are stored outside the game folder:

```text
%LOCALAPPDATA%\QuestieEV\Backups
%LOCALAPPDATA%\QuestieEV\Logs
```

If auto-detection fails, drag the Emberveil `AddOns` folder onto `INSTALL_QUESTIE_EMBERVEIL.cmd`, or run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\installer\Install-Questie-Emberveil.ps1 -InstallHint "D:\Path\To\Emberveil\live\Azeroth\Interface\AddOns"
```

## Manual installation

Copy the release's `addon\pfQuest` folder into Emberveil's `Interface\AddOns` folder. The final layout must be:

```text
Interface\AddOns\pfQuest\pfQuest.toc
Interface\AddOns\pfQuest\compat\emberveil.lua
Interface\AddOns\pfQuest\emberveil_map.lua
```

Do not create a double-nested `pfQuest\pfQuest` folder.

## Upgrade

Exit Emberveil and run the new release's installer. It replaces only `Interface\AddOns\pfQuest`; character settings and saved quest history under the game's `WTF` directory are not deleted.

## Rollback

Exit the client, remove the current `Interface\AddOns\pfQuest`, then copy a backed-up `pfQuest` folder from `%LOCALAPPDATA%\QuestieEV\Backups` back into `Interface\AddOns`.

## Uninstall

Exit Emberveil and delete `Interface\AddOns\pfQuest`. This does not delete saved variables. Remove the related `pfQuest` saved-variable files from the game's `WTF` folder only if you also want to reset all settings/history.
