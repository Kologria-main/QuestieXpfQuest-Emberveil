# beta1.15.1 SavedVariables crash fix

## Crash evidence

Both supplied laptop UE crash archives report the same fatal error from `FrameXML_LuaContext.cpp` line 58:

```text
LUA PANIC!
[string "pfQuest_config = {..."]:104:
unfinished string near '"InterfaceAddOnspfQuestimg    tracking'
```

The crash occurs while Emberveil parses saved Lua state, before addon runtime recovery can execute.

## Root cause

Older pfQuest code persisted `pfQuest_track[list] = { query, meta }`, and `meta.icon` contains a runtime path such as:

```text
Interface\AddOns\pfQuest\img\tracking\herbs
```

On Emberveil, that runtime path is unsafe to round-trip through the SavedVariables Lua serializer/parser.

## Fix

- `pfQuest_track` now persists only `{ query = ... }`.
- Runtime `addon` / `icon` metadata is rebuilt after login.
- Parseable old tracking state is migrated without retaining its runtime metadata.
- The installer repairs pre-existing `pfQuest.lua` files before the client is launched, backing up originals first.

## beta1.15.2 correction

The affected laptop proved that its persisted addon state is not reachable through the initially assumed nearby `WTF` location. The beta1.15.2 installer therefore searches Emberveil's install ancestry and standard Windows application/user-data roots, and emits a diagnostic instead of claiming that recovery was unnecessary when no file is found.
