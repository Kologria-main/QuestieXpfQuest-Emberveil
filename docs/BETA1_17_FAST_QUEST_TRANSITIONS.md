# beta1.17 — Fast quest transitions

The live quest state in beta1.16 was correct, but the render pipeline could still feel slow after accepting a quest. Two latency sources were identified. First, QUEST_LOG_UPDATE invalidated the minimap spatial cache before pfQuest had finished inserting the NEW quest objective nodes; a cache rebuild in that window could therefore capture the old node set. Second, the NEW path marked all available quest givers dirty, causing SearchQuests() to scan the entire quest database even though accepting a quest only needs the accepted starter removed and the new objective nodes added.

beta1.17 invalidates the minimap cache after each NEW/RELOAD/REMOVE node transaction and schedules a coalesced render about 10 ms later. That render is serviced before the map driver's normal 200 ms maintenance throttle. The normal quest-accept path no longer performs a global available-quest scan. Reward/abandon reconciliation is kept, but is delayed 650 ms so the visible map/minimap transition is rendered first.

Performance protections remain active: adaptive minimap cadence based on FPS, spatial grid filtering, current-map-only minimap cache construction, world-map throttling, and event coalescing. The new fast path adds only a timestamp check to ordinary frames and performs immediate work only when quest nodes actually change.
