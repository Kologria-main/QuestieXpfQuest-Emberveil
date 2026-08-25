# Diagnostics

Run `/koquest` in chat (`/qev` remains a compatibility alias). It reports the addon version, database localization, player and selected map identity, coordinate freshness/source, completed-quest synchronization status, whether history is authoritative, available-quest safety mode, collapsed-log snapshot state, cleaned localized-title count, node counts, minimap policy, indoor/outdoor environment source, adaptive update cadence, FPS sample, and compatibility fallbacks.

The quest-state line has two important guarantees:

- `historyAuthoritative=true availableGivers=true`: Emberveil returned a
  character-wide completion snapshot, so automatic quest starters are filtered
  against it.
- `historyAuthoritative=false availableGivers=false`: the client did not expose
  that snapshot. Active objectives and turn-ins are still allowed, while
  uncertain starters are hidden so already-completed quests are not guessed.

Useful commands:

```text
/koquest force    Rebuild objectives, quest givers, and map nodes
/koquest sync     Retry completed-quest synchronization
/koquest map      Refresh the visible map and print diagnostics
```

For a useful bug report, include:

- Emberveil client/build version.
- KoQuest version from `/koquest`.
- Character faction, level, zone, subzone/building, and whether you are in an instance.
- Quest name and objective text exactly as shown.
- What you expected and what was displayed.
- Whether the world map was open and whether `/reload` or `/koquest force` changed the result.
- The `/koquest` lines, with any personal information removed.

For a crash, also include the last action before the crash, reproducibility, other enabled addons, and the relevant client crash log. Never publish credentials, access tokens, email addresses, or private server addresses.
