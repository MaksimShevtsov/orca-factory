---
name: behavior-capture
description: Use when observed system behavior needs to become an explicit contract - turns what a system actually does into Given/When/Then scenarios that changes must not break
---

# Behavior Capture

## Purpose

Turn observed behavior into an explicit contract, so the next change cannot
break it by accident.

The point is not Gherkin. The point is separating **how the system is built**
from **what it must keep doing**. An architecture document describes the first.
Only a behavioral contract protects the second.

## When

- Behavior anyone outside the code depends on
- Behavior discovered during `skills/legacy-archaeology` that was never written down
- Behavior a production incident proved was load-bearing
- Behavior a card is about to change — capture the old contract *first*, so the
  change is visible as a change rather than as a correction

## Format

```
Given  <existing state>
When   <action occurs>
Then   <observable result>
```

Add `And` only where it earns its line.

## Rules

**Describe observable behavior.** Not method names, private classes, or internal
variables — unless those are themselves the contract, which is rare and worth
saying out loud when true.

**Write what it does, not what it should do.** If the behavior is wrong, capture
it accurately and file a card. A contract quietly "corrected" while being
written is how the actual behavior gets deleted without anyone deciding to.

**Include the failure paths.** The happy path is rarely the contract anybody
depends on. Timeouts, retries, partial success and duplicate requests are where
the real agreement lives.

## Example

```gherkin
Scenario: provider timeout after accepting the refund

Given an order is refundable
And the provider may accept a refund without returning a response

When the provider request times out

Then the refund remains pending
And the retry reuses the same idempotency key
And a second refund is not created
And the retry attempt is recorded
```

Note what that scenario protects: not "refunds work", but "a timeout is not a
failure". That distinction is the entire contract, and no architecture diagram
carries it.

## Output

Important scenarios go to `docs/behavior/<domain>.md`, tracked.

Critical scenarios are mirrored into `evals/golden/behavior/` so they are
checked mechanically rather than remembered. A contract nobody executes is a
document; a contract in the golden set is a guardrail.

When capture came from an incident, record which one. The link from a scenario
back to the outage that produced it is what stops someone deleting it in two
years as "an odd test".
