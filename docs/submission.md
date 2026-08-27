# Emberveil addon update submission

Use the published GitHub Release asset—not a branch archive—and keep the source and download on the same public repository.

## Form values

**Name**

```text
KoQuest
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
https://github.com/Kologria-main/QuestieXpfQuest-Emberveil/releases/download/v2.0.0-beta1.21/KoQuest_Emberveil_v2.0.0-beta1.21.zip
```

**Short description**

```text
Safe, localized quest and objective markers for Emberveil's world map and minimap, powered by the pfQuest database.
```

**Full description**

```text
KoQuest brings pfQuest's searchable quest database, tracker, quest-giver markers, turn-in markers, and active objective locations to the Emberveil client.

Correctness comes first. A quest is shown as ready to turn in only when the official quest-log state says it is complete. Available quest-giver markers are shown on both map surfaces using database eligibility, the active quest log, and KoQuest's recorded completion history. Emberveil currently exposes no verified character-wide completion getter, so the clearly labeled best-effort setting explains that a quest completed before KoQuest was installed can still appear and lets players disable unverified starters.

The Emberveil compatibility layer handles localized runtime quest-title prefixes, collapsed quest-log sections, numeric race/class IDs, indoor parent-zone continuity, spatial minimap caching, and bounded rendering. Accepted objectives appear on both map surfaces. Dense world maps retain the original summary icons and add a bounded set of small colored pfQuest objective circles; every circle remains hoverable/clickable and shows its exact spawn and quest tooltip. Russian, Simplified Chinese, and Traditional Chinese databases are included and coverage-checked against every base English lookup ID.

The addon and installers are fully readable in the public repository. Windows and Linux/Wine/Proton installation is supported. Both installers are offline, verify the bundled addon with SHA-256, back up the current pfQuest folder, install transactionally, and roll back on failure. The addon performs no downloads, telemetry, chat messages, or addon-channel broadcasts.

Current deliberate safeguards: party/raid interior minimap pins and the route arrow remain disabled because the supplied Emberveil API does not expose trustworthy floor/facing data.
```

**Version**

```text
2.0.0-beta1.21
```

## Files and final checks

- Icon: `assets/icon.png` (PNG, under 10 MB).
- Screenshots: use the real gallery images listed in `docs/submission-assets.md`; do not fabricate in-game evidence.
- Confirm the repository and `v2.0.0-beta1.21` release are visible while logged out.
- Confirm the download is the GitHub Release asset above and its SHA-256 matches `dist/SHA256SUMS.txt`.
- Confirm the site displays the new version and does not keep the previously frozen beta1.15 asset.
