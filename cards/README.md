# Cards

A card is a **durable specification**: what to do, and how anyone can tell it
was done. It is committed, reviewed, and permanent.

A card does not record status. It does not record who holds it. That is Orca's
job — `orca orchestration task-list --ready` answers "what is unblocked", and it
is the only place that answers it. If you find yourself wanting to write
`status:` on a card, you are duplicating live state into a file that will be
wrong within the hour.

## Naming

`<kind>-<number>-<slug>.md` — kind is `bug`, `feat`, or `chore`. Numbers are
never reused, including by cards that were deleted.

## The card

`area` on the first line, `severity` on the second: a card list is read by
scanning its left edge, and grouping by area is what turns nine bugs into three
batches of work.

```markdown
---
area: search
severity: high
---

Search stops returning results after the first query. Second and later queries
in the same session come back empty; the same queries in a fresh session return
results normally.

**Acceptance:** a second query in the same session returns the same result set
it would return in a fresh session.

## Reproduction

1. Open the app, search `invoice` — 14 results.
2. Search `invoice` again without reloading — 0 results.

Observed on 3 of 3 sessions, both seeds.

## Evidence

- `docs/qa/evidence/bug-0007-second-query-empty.png`
```

**Every card carries an acceptance line**, written so that someone who was not
in the conversation can check it without asking a question. A card without one
is not ready to dispatch — that is the planner's job, and the coordinator sends
it back.

## Dispatching a card

The card is the spec; Orca carries the pointer.

```sh
orca orchestration task-create --spec "Work cards/bug-0007-empty-after-first-query.md. \
Acceptance is the line in that file. Read roles/_common.md and roles/executor.md first." --json
```

Dependencies between cards are Orca's, not the card's:

```sh
orca orchestration task-create --spec "cards/feat-0013-....md" --deps '["task_abc123"]' --json
```

Keep dependency chains under 3–4 deep. Deeper than that and a single slow worker
stalls everything behind it, with no way to see why.

## Before you file

Read `cards/` and `orca orchestration task-list`. If the defect is already
described, **add your numbers and your reproduction to the existing card**. A
second independent observation makes a card much stronger; a second card
guarantees two people fix one bug.
