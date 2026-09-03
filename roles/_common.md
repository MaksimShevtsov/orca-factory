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
**Blocked beats guessing**.

## The board

```
tasks/
  open/      filed, unclaimed
  doing/     claimed, in progress   (owner set)
  review/    code complete, awaiting reviewer
  qa/        merged, awaiting acceptance
  done/      accepted
  blocked/   waiting on a decision or an answer
```

**The directory is the status.** There is no status field to fall out of sync
with reality, and `ls tasks/doing/` answers "who is holding what" without
parsing anything. Four different CLIs share this board through the filesystem;
it works because a rename is atomic and a convention is not.

## Claiming and handing off

Claim: move the card into `doing/` and set `owner` to your role name, in one
commit. If it is already in `doing/` with someone else's name on it, it is not
yours — even if you are certain you could finish it faster.

Hand off: move the card to the next directory and clear `owner`. **The move is
the handoff.** There is no separate notification, no message to anyone; the next
role reads the board.

**One owner at a time. You never move a card you do not own.** The single
exception is the PM, who may return any card to `open/` and must say why on the
card when it does.

## Card format

Filename: `<kind>-<number>-<slug>.md`, where kind is `bug`, `feat`, or `chore`.
Numbers are never reused, including by cards that were deleted.

```markdown
---
area: search
severity: high
owner: executor
branch: bug-0007-empty-after-first-query
---

Search stops returning results after the first query.

**Acceptance:** a second query in the same session returns the same
result set it would return in a fresh session.
```

Area on the first frontmatter line, severity on the second — a board is read by
scanning the left edge, and grouping by area is what turns nine bugs into three
batches.

**Every card carries an acceptance line, and it is written so that someone who
was not in the conversation can check it without asking a question.** "Improve
search" is not a card. "A second query returns the same result set" is.

## Git

One card, one branch, and the branch name is recorded on the card. Branch off
the current mainline, not off another role's work.

**Never move another role's branch.** Not to rebase it, not to tidy it, not to
"just fix the conflict for them". If their branch is in your way, that is a
card.

Commit messages name the card: `bug-0007: stop clearing the result cache
between queries`.

## Evidence lives in the repository

A screenshot in an untracked directory is reachable by exactly one person: the
one who made it. Everyone else follows the link and finds nothing.

**If you cite it, commit it.** Under `docs/`, in a tracked path, linked from the
card by relative path. This applies to screenshots, logs, profiles, query
output, and benchmark runs alike.

**No reels.** Three artifacts per finding, maximum. The fourth screenshot has
never once been the one that convinced anybody.

## No duplicates

Before you file, read `tasks/`. If the defect is already described, **add your
numbers and your reproduction to the existing card**. A second independent
observation makes a card much stronger. A second card makes the board weaker,
and guarantees two people fix one bug.

## Blocked beats guessing

When the card cannot be done as written — the requirement is ambiguous, the
interface does not exist yet, two instructions contradict — move it to
`blocked/`, write **the actual question** on it, and name who should answer
(usually `advisor` or `pm`).

An assumption you made because asking felt slow is the most expensive thing in
this repository. It is invisible, it is baked into code, and it surfaces three
roles later as a defect nobody can explain.

## Proving the work

**Numbers, not adjectives.** How many, how long, which paths, measured how. A
claim without a number attached is an opinion about your own work.

**Answer in words where words were asked.** No instrument answers "is this
tedious", "is this failure fair", "is this empty state calm or dead". When you
are asked that, answer it as a person, in a sentence. A table is a way of
declining to answer.

**"It ran" is not "it works", and "no error" is not "correct".** Verify against
the card's acceptance line, quote that line, and show the output that satisfies
it. If you did not run it, say you did not run it.

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
| reviewer | `superpowers:receiving-code-review` is what your counterpart runs — write findings it can be applied to |
| anyone on a `bug-` card | `superpowers:systematic-debugging`, before proposing any fix |

## Scope

YAGNI, enforced. Build what the card asks for and stop. The refactor you can see
from here is a card. The abstraction that would pay off at three call sites is a
card when there are three call sites.

**Do not fix what you were not asked to fix.** An unrelated improvement inside a
card's diff costs the reviewer more than it saves you, and it makes the revert
of a bad change take the good one with it.
