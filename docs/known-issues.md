# Known issues and deliberate safeguards

- **Party/raid interiors:** Minimap quest pins are hidden. The supplied API does not expose a reliable floor-aware dungeon coordinate surface, so showing outdoor UVs there would be misleading.
- **Route arrow:** Disabled because safe player-facing data is not exposed by the current Emberveil API. Map and minimap nodes still work.
- **Hover shortcuts:** High-frequency native `MouseIsOver` polling and UI child/region enumeration are disabled because Unreal-backed bridge objects are not safe to introspect like original Vanilla FrameXML objects.
- **Tooltip item hyperlinks:** The native hyperlink bridge is not called. Item details use safe `GetItemInfo` text when available.
- **Completed-quest server API:** `QueryQuestsCompleted` and
  `GetQuestsCompleted` are feature-detected. If unavailable or throttled, local
  history is enough to render active objectives and turn-ins but cannot prove
  what the character completed before installing the addon. Automatic
  available quest-giver markers are therefore hidden rather than risking an
  already-completed quest on the world map or minimap. `/qev` reports
  `historyAuthoritative=false` and `availableGivers=false` in this mode.
- **Database coverage:** pfQuest's database can differ from custom Emberveil content or altered spawn data. Unknown or custom quests may have incomplete markers until the database is updated.
- **Future client changes:** This release is validated against the supplied Emberveil API documentation dated 2026-08-19. A later client can change behavior even when function names remain the same.

These are not silently guessed around. The addon prefers missing markers to confident-looking wrong information.
