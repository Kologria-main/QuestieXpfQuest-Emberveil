# Emberveil addon submission

Use the current release—not a branch archive—for the download URL.

## Form values

**Name**

```text
Questie Emberveil
```

**Category**

```text
Quests
```

**Source repository**

```text
https://github.com/Kologria-main/QuestieXpfQuest-Emberveil
```

**Download**

```text
https://github.com/Kologria-main/QuestieXpfQuest-Emberveil/releases/download/v2.0.0-beta1.16/Questie_Emberveil_v2.0.0-beta1.16.zip
```

**Short description**

```text
Quest and objective markers for Emberveil's world map and minimap, powered by the pfQuest database and a crash-conscious Emberveil compatibility layer.
```

**Full description**

```text
Questie Emberveil brings pfQuest's quest database, tracker, searchable browser, verified quest-giver markers, turn-in markers, and active objective locations to the Emberveil client.

The port uses a dedicated Emberveil map engine with verified current-zone coordinates, indoor parent-zone continuity, spatial minimap caching, adaptive low-FPS throttling, and strict three-state quest handling so failed quests are never shown as complete. Available quest starters are shown only when Emberveil provides authoritative character-wide completion history; otherwise active objectives and turn-ins remain visible while uncertain starters are hidden. When the client cannot provide a trustworthy quest state, coordinate, or floor context, the addon hides that marker instead of guessing.

The addon and installer are fully readable in the public repository. The installer is offline, verifies every bundled file with SHA-256, backs up the current pfQuest folder, installs transactionally, and rolls back on failure. The addon performs no downloads, telemetry, chat messages, or addon-channel broadcasts.

Current limitation: party/raid interior minimap pins and the route arrow are disabled because the supplied Emberveil API does not expose trustworthy floor/facing data.
```

**Version**

```text
2.0.0-beta1.16
```

Upload `assets/icon.png` as the icon. Do not upload fabricated in-game screenshots; screenshots should show the real addon running in Emberveil and are optional under the announced rules.

Before submitting, confirm that the repository is public, the tag and release are visible while logged out, the asset downloads from the same repository, the checksum matches `SHA256SUMS.txt`, and the icon is PNG/JPG/WebP under 10 MB.
