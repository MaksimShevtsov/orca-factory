---
name: reflect
description: Use after a task where something went wrong that could go wrong again - converts a one-off failure into a durable guardrail rather than a lesson only one session remembers
---

# Reflect

## Purpose

Turn a failure into something that cannot happen the same way twice.

This is the loop that makes the next task cheaper than the last. Without it,
every session re-learns the same thing and pays full price each time — the
knowledge lives in a transcript nobody will read again.

## When

After a task where something went wrong that could go wrong again. Not after
every task — a reflection written when nothing was learned dilutes the ones
that matter.

Strong triggers:

- an agent assumed something instead of checking it
- a test passed while the behavior was broken
- the same mistake has now appeared twice
- a review or acceptance pass caught something that should have been caught earlier
- a card had to be dispatched three times

## Procedure

Answer these honestly. The value is entirely in the honesty.

1. **What was misunderstood?** State it as the wrong belief, not as the symptom.
2. **What information was missing, and where should it have been?**
3. **What caught it?** And how much later than it could have been?
4. **What would have caught it sooner?**
5. **Which durable artifact should exist now?**

| If the gap is | The artifact is |
|---|---|
| the agent did not know a fact | documentation, linked from `AGENTS.md` |
| the agent could not repeat a procedure | a skill |
| the procedure is mechanical | a script |
| the mistake is silent and repeatable | a golden case in `evals/golden/agent-failures/` |
| a boundary was crossed that should not be | a rule in `roles/_common.md` |
| the check should be automatic | a gate in `evals/run.sh` |

## The rule that makes this work

**A lesson that produces no artifact is not a lesson.** It is a note, and notes
do not change what the next agent does.

If you cannot name the artifact, you have not finished the reflection — either
dig until you find the real gap, or conclude honestly that this was a one-off
and write nothing.

## Output

`docs/lessons/<yyyy-mm-dd>-<slug>.md`:

```markdown
# Lesson

## Failure
What went wrong, concretely.

## Root cause
The wrong belief, not the symptom.

## Missing guardrail
What would have caught this, and where it should have lived.

## Durable fix
The artifact created or changed. Link it.

## Verification
How we know the guardrail actually fires.
```

That last section is the one people skip, and it is the one that matters: a
guardrail nobody proved fires is indistinguishable from no guardrail. If you
added a golden case, show it failing against the old behavior.
