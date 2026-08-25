# Known issues and deliberate safeguards

- **Party/raid interiors:** Minimap quest pins are hidden. The supplied API does not expose a reliable floor-aware dungeon coordinate surface, so showing outdoor UVs there would be misleading.
- **Route arrow:** Disabled because safe player-facing data is not exposed by the current Emberveil API. Map and minimap nodes still work.
- **Hover shortcuts:** High-frequency native `MouseIsOver` polling and UI child/region enumeration are disabled because Unreal-backed bridge objects are not safe to introspect like original Vanilla FrameXML objects.
- **Tooltip item hyperlinks:** The native hyperlink bridge is not called. Item details use safe `GetItemInfo` text when available.
- **Completed-quest server API:** `QueryQuestsCompleted` and
  `GetQuestsCompleted` are feature-detected. If unavailable or throttled, local
  history is enough to hide completions observed by KoQuest but cannot prove
  what the character completed before installing the addon. Database-matched
  available quest-giver markers are enabled by default so quests that can be
  picked up remain useful on both map surfaces. `/koquest` then reports
  `availability=local-best-effort`, `historyAuthoritative=false`, and
  `availableGivers=true`. The clearly labeled setting can disable those
  unverified starters; in the default mode, completed pre-install quests may
  appear because the client provides no passive way to identify them.
- **Database coverage:** pfQuest's database can differ from custom Emberveil content or altered spawn data. Unknown or custom quests may have incomplete markers until the database is updated.
- **Localized client runtime:** ruRU, zhCN, and zhTW database coverage and title normalization are tested offline. Final font rendering, native `GetLocale()` behavior, and server-specific custom quest text still require target-client smoke tests on each locale.
- **Future client changes:** This release is validated against the supplied Emberveil API documentation and Thomas's UnrealRuntimeCompat runtime database supplied on 2026-08-25. A later client can change behavior even when function names remain the same.

These are not silently guessed around. Active and completed state is fail-closed; the one database-based available-quest limitation is labeled explicitly.
