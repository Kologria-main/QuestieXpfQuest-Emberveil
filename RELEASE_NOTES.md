# Questie Emberveil 2.0.0-beta1.15

This moderation-ready beta packages the complete readable addon source, an offline transactional installer, checksums, documentation, and repeatable validation.

## Highlights

- Correct complete/failed/incomplete quest state handling. Only Emberveil's
  documented quest-level completion flag can produce a completed/turn-in
  marker; finished counters alone cannot override hidden requirements.
- Completed quests are fail-closed: available quest-giver markers are enabled
  only after a character-wide server completion snapshot. Without that API,
  active objectives and turn-ins still render while uncertain starters stay hidden.
- Quest-log disappearance is never assumed to mean completion; only a last
  verified complete state is recorded locally.
- Quest-end markers appear only when the quest is officially ready to turn in.
- Indoor parent-zone continuity for buildings where zone-name APIs temporarily return blank.
- Zoom and zone transition events coalesce before minimap reprojection and never guess the indoor/outdoor direction.
- Spatial node caching, adaptive FPS throttling, and a 250 ms heavy transition cadence.
- Conservative party/raid behavior: uncertain interior pins are hidden.
- No addon telemetry, chat transmission, addon-channel broadcasting, or runtime downloads.
- Native bridge risk paths removed or blocked.

## Install

1. Download `Questie_Emberveil_v2.0.0-beta1.15.zip` and verify it against `SHA256SUMS.txt`.
2. Extract the ZIP completely.
3. Exit Emberveil.
4. Double-click `INSTALL_QUESTIE_EMBERVEIL.cmd`, or manually copy `addon\pfQuest` to `Interface\AddOns\pfQuest`.
5. Restart Emberveil.

The installer verifies all 293 addon files before staging and after installation, backs up an existing `pfQuest`, and restores it if installation fails.

## Known safeguards

- Route arrow disabled: no safe facing API.
- Party/raid interior minimap pins hidden: no trustworthy floor-aware coordinate surface.
- Available quest-giver markers hidden when the server offers no authoritative
  character-wide completed-quest snapshot.
- Native hover enumeration/shortcuts disabled on Unreal-backed UI bridge objects.

See `docs/known-issues.md` and `docs/testing.md` for the full scope.
