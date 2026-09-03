---
name: legacy-archaeology
description: Use when working in an unfamiliar or legacy subsystem, before changing anything - reconstructs actual behavior and implicit contracts without modifying code
---

# Legacy Archaeology

## Purpose

Reconstruct what a subsystem **actually does** before anyone changes it.

A specification says what a system should do. A legacy system is defined by what
it does — and the gap between those two is where the business rules are hiding.
Someone depends on the behavior nobody wrote down.

## Non-goals

Do not refactor. Do not rename. Do not tidy style. Do not improve architecture.
Do not fix what you find.

**Change nothing.** The output of this skill is a document, not a diff. Every
finding leaves as a card.

The pull to fix something small while you are already in the file is exactly
what makes archaeology unreliable: a diff mixed into an investigation means
nobody can tell which observations predate your edit.

## Procedure

### 1. Surface map

Find the ways in: entry points, public APIs, commands, scheduled jobs, event
handlers, database access, external integrations.

### 2. Behavior

Find what constrains it: existing tests, logs, metrics, retries, timeouts,
feature flags, error handling, and the edge cases nobody documented.

Read the tests first. A test is the only documentation that fails when it
becomes untrue.

### 3. Trace

Follow one real path end to end:

```
request -> validation -> business logic -> persistence -> integration -> observable result
```

Name what happens at each hop when the hop *fails*, not only when it succeeds.

### 4. Contracts

Separate three things, and never let them blur:

- **Explicit contracts** — written down, tested, intended.
- **Implicit contracts** — not written down, but depended on. These are the
  dangerous ones and the reason this skill exists.
- **Suspicious behavior** — looks accidental. May still be load-bearing.

### 5. Separate fact from hypothesis

Every statement in your output is one or the other, and labelled. "The retry has
no idempotency key" is a fact you can point at. "This is why refunds double" is
a hypothesis until reproduced.

**Confidence is part of the finding.** Say what you could not check.

## Output

`reports/investigations/<slug>.md`, tracked and committed:

- Scope — what you looked at, and what you did not
- Entry points
- Execution flow
- Data flow
- Dependencies and external systems
- Existing tests, and what they actually assert
- Observed behavior
- Explicit contracts / implicit contracts / suspicious behavior
- Unknowns
- Hypotheses, each with how it could be confirmed
- Recommended next steps

Where the behavior matters to someone, promote it: `docs/behavior/<domain>.md`
via `skills/behavior-capture`.

Report with `worker_done`, `--outcome succeeded`, and say plainly what remains
unknown. An investigation that reports no unknowns has usually stopped looking.
