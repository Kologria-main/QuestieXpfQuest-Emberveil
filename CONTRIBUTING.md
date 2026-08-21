# Contributing

Please search existing issues before opening a new one. For client bugs, use the bug or crash template and include `/qev` output without account credentials, email addresses, or private server information.

Changes must preserve these release gates:

- Lua 5.1 syntax and the documented Emberveil API contract.
- Fail-closed quest and coordinate handling: uncertain state is hidden/incomplete, never guessed.
- No native UI child/region enumeration, tooltip hyperlink bridge calls, forced termination, native minimap mutation, dynamic code execution, telemetry, chat transmission, or addon-channel broadcasting.
- No generated or binary runtime code.
- Version synchronization across the TOC, compatibility layer, package metadata, documentation, and release filename.
- MIT attribution for pfQuest.

Before proposing a change, run `pnpm validate` and `powershell -NoProfile -File .\scripts\validate-release.ps1`. Describe the Emberveil client build and in-game scenarios you tested.
