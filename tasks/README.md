# The board

Six directories, one card per file. **The directory a card sits in is its
status** — there is no status field, so there is nothing to fall out of sync
with where the card actually is.

```
open/      filed, unclaimed
doing/     claimed, in progress   (owner set)
review/    code complete, awaiting reviewer
qa/        merged, awaiting acceptance
done/      accepted
blocked/   waiting on a decision or an answer
```

A handoff is a move:

```sh
git mv tasks/doing/bug-0007-empty-after-first-query.md tasks/review/
```

Rules live in `roles/_common.md` and bind every role. The short version: one
owner at a time, you never move a card you do not own (the PM excepted), and
nothing reaches `done/` without passing through both `review/` and `qa/`.

## Naming

`<kind>-<number>-<slug>.md` — kind is `bug`, `feat`, or `chore`. Numbers are
never reused, including by cards that were deleted.

## The card

Copy this shape. `area` on the first line and `severity` on the second, because
a board is read by scanning its left edge, and grouping by area is what turns
nine bugs into three batches of work.

```markdown
---
area: search
severity: high
owner: executor
branch: bug-0007-empty-after-first-query
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

`owner` is empty in `open/`, `review/` and `qa/` — those are queues, not
assignments. It is set on the way into `doing/` and cleared on the way out.

**Every card carries an acceptance line**, written so that someone who was not
in the conversation can check it without asking a question. A card without one
is not ready to be filed — that is the planner's job, and the PM sends it back.

## Before you file

Read the board first. If the defect is already described, **add your numbers and
your reproduction to the existing card.** A second independent observation makes
a card much stronger; a second card guarantees two people fix one bug.
