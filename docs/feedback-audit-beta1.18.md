# beta1.18 community feedback audit

Audit date: 2026-08-25

Sources reviewed:

- the moderated KoQuest page and its 20 comments/replies;
- the Emberveil Discord `Questie x pfQuest` thread and attached diagnostics;
- the Unreal Azeroth `Questie x pfQuest engine addon ready for testing` thread;
- GitHub issue 1 and the public repository state at beta1.18.

This document records product evidence. Usernames are omitted because they are not
needed to reproduce or resolve the reported behavior.

## Confirmed beta1.18-era problems

### Available quest-giver markers disappear without a server snapshot

English and Russian users reported that unaccepted quest exclamation markers no
longer appeared. Attached beta1.15 diagnostics independently showed
`local-history-no-server-api`, local histories of 0 and 13 completions, and the
message that available quest-giver markers were hidden to avoid completed quests.
Another page attachment showed the same mode with locally recorded history.

The server runtime database supplied for beta1.19 documents no authoritative bulk
completed-quest API. KoQuest therefore uses its local completion history plus the
database eligibility filters and enables quest-giver markers by default so the
reported missing-quest problem is actually fixed. The setting remains explicitly
labeled because a quest completed before KoQuest was installed can still appear;
players who prefer a fail-closed map can disable unverified starters.

### SavedVariables migration can be associated with startup crashes

One Unreal Azeroth tester reported an immediate login crash after replacing an
older pfQuest installation. The community workaround was to delete SavedVariables.
That report did not include a crash archive, so the engine-level cause is not
proven. It does establish a migration-safety requirement.

beta1.19 repairs only the known unsafe `pfQuest_track` assignment, backs up the
entire file first, preserves unrelated settings, scopes automatic discovery to
the confirmed Emberveil account root, and exercises repair, backup, rollback, and
tamper rejection in isolated installer tests.

### Manual-copy installation is required

Users asked for an ordinary ZIP that can be extracted directly into
`Emberveil\live\Azeroth\Interface\AddOns`, and another user questioned why scripts
were necessary. beta1.19 treats manual copy as a first-class installation path.
The readable Windows and POSIX installers are optional conveniences included in
the same public-source release.

## Localization and platform requests

- Russian users reported missing or non-working support.
- Chinese users asked for client support and clearer installation instructions;
  one reported repeated download failure without enough browser/network evidence
  to identify a cause.
- Linux support was requested in Discord.
- Custom-drive auto-detection failed for at least one installation and correctly
  fell back to requesting an explicit path.

beta1.19 validates complete ruRU, zhCN, and zhTW database ID coverage, adds
localized safety-option labels, uses numeric race/class IDs where measured, strips
documented localized quest-level prefixes, documents manual custom-drive and
Wine/Proton paths, and includes an explicit-path POSIX installer. Live Russian and
Chinese client testing is still a beta follow-up rather than a proven claim.

## Additional correctness findings resolved in beta1.19

- A collapsed quest-log header can hide rows from `GetNumQuestLogEntries`; an
  incomplete snapshot must never remove quests from the tracker or cache.
- The Emberveil client can decorate localized quest titles with digit-first level
  prefixes; title normalization must remove those decorations without damaging a
  genuine title such as `[Story] ...`.
- A `database.lua` local declaration typo leaked `xmax` globally.
- Public KoQuest branding, source/package versions, submission URLs, and release
  tooling had drifted across beta1.15-beta1.18.

## Insufficient-evidence reports

- The page's Chinese download-failure report lacks the attempted URL, HTTP status,
  browser, checksum, and exact error.
- The startup-crash report lacks a crash dump and exact addon combination.
- An attached in-game image with a partially rendered/blank interface does not
  isolate KoQuest as the cause.

These reports remain documented but are not converted into fabricated root causes.
The beta1.19 bug and crash templates now request platform, locale, exact version,
diagnostics, reproduction steps, and relevant crash data.

## Release decision

The feedback does not justify weakening the completed-quest guarantee. The
beta1.19 release candidate is acceptable only if strict mode stays the default,
active objectives still render, the manual ZIP remains usable without scripts,
all installer mutations are bounded and recoverable, and the final source/package
validation and reproducible-build checks pass.
