# Documentation index

`AGENTS.md` is the map for agents. This is the index of durable knowledge —
what we know, and where it lives. Read the closest relevant document; do not
load everything.

## Directories

| Path | Holds | Written by |
|---|---|---|
| `behavior/` | Given/When/Then contracts — what must keep working | `skills/behavior-capture` |
| `decisions/` | ADRs — one decision each, with the option not taken | architect |
| `lessons/` | Failures converted into guardrails | `skills/reflect` |
| `qa/evidence/` | Screenshots and captures cited by cards | qa-tester |

Investigation and verification artifacts live in `reports/`, not here — they
describe one run, while everything in `docs/` is meant to outlive it.

## What goes where

A thing that must keep being true → `behavior/`.
A choice someone will question later → `decisions/`.
A mistake that could repeat → `lessons/`.

If it is none of those, it may not need to be written down. Documentation that
duplicates the code is worse than none: it goes stale silently and then it lies.

## Rules

**One document per subject, linked from here.** A file nobody can find from this
index will not be read, and an agent told to "check the docs" will load the
wrong one.

**Update on change, not on schedule.** Behavior changed, architecture changed, a
discovery was made, an operational procedure changed, or an agent failed the
same way twice — those are the moments.

**Evidence is tracked or it does not exist.** A link to an untracked path
resolves for exactly one person. See `roles/_common.md`.
