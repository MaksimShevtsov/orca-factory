# The common contract

Binding on every role in `roles/`. Your own role file says what makes you
different; this says what is true of all of us. Where the two disagree, your
role file wins — that is the only exception.

## The card is the task

Your mandate is your role file plus this file plus **one card**. You do what the
card says. Not what you noticed on the way, not what you would have designed,
not the adjacent thing that is obviously also broken — that is a new card, and
filing it takes twenty seconds.

A card you cannot do as written is not a card you improve by guessing. See
**Ask, do not assume**.

## Where state lives

Two stores, and they must never describe the same fact.

| | Orca | This repository |
|---|---|---|
| holds | the task DAG, who holds what, dispatch, completion, questions, gates | card specs, acceptance lines, behavior contracts, goldens, decisions, lessons |
| lifetime | the run | permanent |

**Task status belongs to Orca.** There is no status field, no status directory,
and no "in progress" marker in this repo. `orca orchestration task-list --ready`
is the answer to "what is unblocked", and it is the only answer.

A card in `cards/` is a durable specification. It does not move, and it does not
record who is working on it.

## Claiming and handing off

You do not claim. The coordinator dispatches you, and the dispatch is your
authority. When you finish:

```sh
orca orchestration send --type worker_done \
  --subject "<short status>" \
  --body "<what changed, what you found, what remains — plus the GATE block>" \
  --task-id <task_id> --dispatch-id <dispatch_id> \
  --outcome succeeded --files-modified "path/a,path/b" --json
```

Exactly once, from your own terminal, with an explicit outcome. **Never encode
failure only in prose** — a failed run reported as succeeded with a sad body is
the single most expensive lie available to you. Use `--outcome failed`.

After reporting, stop. Do not start more work, do not poll, do not close your
own terminal.

Only the coordinator dispatches. If you try, you get
`nested_worker_depth_exceeded`. That is the design. Do the work yourself, or ask.

## Ask, do not assume

When the card cannot be done as written — the requirement is ambiguous, an
interface does not exist, two instructions contradict — **block and ask**:

```sh
orca orchestration ask --question "<the actual question>" --options "a,b" --timeout-ms 600000 --json
```

It blocks until the coordinator answers. A timeout leaves the question pending;
resume it by its message id rather than asking a second time.

An assumption you made because asking felt slow is the most expensive thing in
this repository. It is invisible, it is baked into code, and it surfaces three
roles later as a defect nobody can explain.

## Card format

`cards/<kind>-<number>-<slug>.md`, where kind is `bug`, `feat`, or `chore`.
Numbers are never reused, including by cards that were deleted.

```markdown
---
area: search
severity: high
---

Search stops returning results after the first query.

**Acceptance:** a second query in the same session returns the same result set
it would return in a fresh session.
```

Area on the first line, severity on the second — a card list is read by scanning
the left edge, and grouping by area is what turns nine bugs into three batches.

**Every card carries an acceptance line, written so that someone who was not in
the conversation can check it without asking a question.** "Improve search" is
not a card. "A second query returns the same result set" is.

## Git

One card, one branch, and the branch is named for the card. Branch off the
current mainline, not off another role's work.

**Never move another role's branch.** Not to rebase it, not to tidy it, not to
"just fix the conflict for them". If their branch is in your way, that is a card.

Commit messages name the card: `bug-0007: stop clearing the result cache
between queries`.

## Evidence lives in the repository

A screenshot in an untracked directory is reachable by exactly one person: the
one who made it. Everyone else follows the link and finds nothing.

**If you cite it, commit it.** Under `docs/` or `reports/`, in a tracked path,
linked by relative path. This applies to screenshots, logs, profiles, query
output and benchmark runs alike.

**No reels.** Three artifacts per finding, maximum. The fourth screenshot has
never once been the one that convinced anybody.

## No duplicates

Before you file, read `cards/` and `orca orchestration task-list`. If the defect
is already described, **add your numbers and your reproduction to it**. A second
independent observation makes a card much stronger. A second card makes the work
weaker and guarantees two people fix one bug.

## Proving the work

**Numbers, not adjectives.** How many, how long, which paths, measured how. A
claim with no number attached is an opinion about your own work.

Every run ends by printing this block, verbatim, into your `worker_done` body:

```
GATE tests       PASS   412/412
GATE typecheck   PASS
GATE golden      FAIL   49/50  behavior/refund-timeout
VERDICT: BLOCKED on golden
```

`VERDICT` is `READY` or `BLOCKED on <gate>`. No score, no percentage, no partial
credit — a weighted number hides the class that failed, and the class that fails
is always the one that mattered.

The evaluator behind `/goal` reads the transcript, **not your files**. A result
you did not print did not happen as far as it is concerned.

**Answer in words where words were asked.** No instrument answers "is this
tedious", "is this failure fair", "is this empty state calm or dead". When asked
that, answer as a person, in a sentence. A table is a way of declining.

**"It ran" is not "it works", and "no error" is not "correct".** Verify against
the card's acceptance line, quote it, and show the output that satisfies it. If
you did not run it, say you did not run it.

## Skills

Superpowers skills are not optional here. Every role, without exception:

- **`superpowers:verification-before-completion`** before claiming anything is
  done, fixed, or passing. Evidence precedes the assertion, always.

Per role, in addition:

| Role | Skill |
|---|---|
| planner | `superpowers:brainstorming`, then `superpowers:writing-plans` |
| architect | `superpowers:brainstorming` |
| executor | `superpowers:test-driven-development`, and `superpowers:requesting-code-review` at handoff |
| reviewer | write findings that `superpowers:receiving-code-review` can be applied to |
| anyone on a `bug-` card | `superpowers:systematic-debugging`, before proposing any fix |
| anyone in unfamiliar legacy code | `skills/legacy-archaeology/` |

## Scope

YAGNI, enforced. Build what the card asks for and stop. The refactor you can see
from here is a card. The abstraction that would pay off at three call sites is a
card when there are three call sites.

**Do not fix what you were not asked to fix.** An unrelated improvement inside a
card's diff costs the reviewer more than it saves you, and it makes reverting a
bad change take the good one with it.
