# beta1.16 live quest/map fix

## Root cause

`QuestieEV:CanRenderAvailableQuests()` required both `questStateReady` and an authoritative character-wide completed-quest snapshot. Emberveil currently falls back to `local-history-no-server-api`, so `questHistoryAuthoritative` remained false and `pfDatabase:SearchQuests()` / `QuestFilter()` suppressed all newly available quest starters.

At the same time, upstream quest and tracker loops still expected Vanilla's second return from `GetNumQuestLogEntries()`. Emberveil's official API documents the first return as the visible quest-log row count.

## Resolution

- Available quests use classic pfQuest local-history filtering whenever no bulk history API exists.
- Active quest state remains authoritative from the live quest log.
- Quest-log iteration uses the documented visible row count.
- Unique quest titles map to database IDs without any quest-log selection mutation.
- Duplicate titles use only documented quest selection/text APIs.
- Quest events force world/minimap cache invalidation without requiring map-open side effects.
- Indoor parent-zone continuity and minimap environment handling remain unchanged from the tested beta1.14+ design.
