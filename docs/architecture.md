# Architecture

The runtime retains pfQuest's database, quest parser, tracker, browser, and node model. `compat/emberveil.lua` loads immediately after the upstream client compatibility layer and establishes safe wrappers before the remaining modules load. `emberveil_map.lua` loads after `map.lua` and replaces world-map/minimap update methods with Emberveil-specific rendering.

Core rules:

- **Quest truth:** `GetQuestLogTitle` is normalized to `1`, `-1`, or `nil`.
  `QuestieEV:GetQuestLogEntryState` is the single authority for active quest
  state. Only quest-level `1` is complete; finished counters never override
  money, hidden/scripted requirements, or server validation.
- **Action timing:** Automatic quest-end markers are created only for an active
  quest whose canonical state is complete. Incomplete and failed quests do not
  display a premature turn-in marker.
- **Completion-history truth:** Automatic available quest starters require a
  character-wide server snapshot. Local history alone cannot prove what was
  completed before installation, so starters stay hidden while active
  objectives and turn-ins continue to render. A quest leaving the log is
  recorded only if its previous canonical state was complete.
- **Coordinate truth:** `GetPlayerMapPosition` coordinates are stored only when the currently viewed concrete map matches the verified player parent zone.
- **Indoor continuity:** A blank interior zone API may reuse the last verified parent zone; a new-area event clears that identity.
- **Hidden-map recovery:** The raw `SetMapToCurrentZone` bridge is retained privately and called only after login, only while the world map is hidden, outside party/raid interiors, under a busy guard and cooldown.
- **Render safety:** Missing/ambiguous coordinates, scale data, instance context, or draw-layer dimensions hide pins.
- **Performance:** Minimap nodes use a five-unit spatial grid. Heavy reprojection is throttled adaptively and transition events coalesce before rendering.
- **Privacy:** Legacy pfQuest version broadcasts are not loaded; there is no addon telemetry or chat transmission.
