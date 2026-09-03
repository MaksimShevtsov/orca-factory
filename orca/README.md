# The control plane

Orca coordinates the fleet. This directory holds the loop that drives it and the
mapping from a role name to a launch command.

Read `roles/pm.md` for what the coordinator owes the fleet; this file is the
mechanics.

## The shape

One coordinator, many workers, and the depth limit is not negotiable:

```
        coordinator  (roles/pm.md — the only terminal that dispatches)
             |
   +---------+---------+---------+---------+
   |         |         |         |         |
planner  architect  executor  reviewer  qa-tester      advisor (on ask)
```

A dispatched worker cannot dispatch. `Settings -> Orchestration -> Nested worker
depth` can raise it to 2, and creating a new Run does **not** reset it — depth
counts from the terminal issuing the command. Leave it at 1: a fleet where any
worker can spawn workers has no single place to look when it stalls.

## The loop

```sh
# 1. Bind a Run once.
orca orchestration run-create --objective "<what this run is for>" --json

# 2. Create every task up front, with dependencies. Cards hold the spec.
orca orchestration task-create --spec "Work cards/feat-0012.md. Read roles/_common.md and roles/architect.md." --json
orca orchestration task-create --spec "Work cards/feat-0012.md. Read roles/_common.md and roles/executor.md." --deps '["<architect_task>"]' --json

# 3. Start every ready worker BEFORE waiting on any of them.
orca orchestration task-list --ready --json
./orca/dispatch.sh architect <task_id>
./orca/dispatch.sh executor  <task_id>

# 4. Wait. Process the whole delivery, then acknowledge.
orca orchestration check --wait --types worker_done,escalation,question --timeout-ms 900000 --json
#   question    -> orca orchestration reply --id <msg_id> --body "<answer>" --json
#   worker_done -> orca orchestration worker-release --dispatch <id> --json
orca orchestration check --ack <delivery_id> --wait --types worker_done,escalation,question --timeout-ms 900000 --json
```

Step 3 before step 4 is the whole point of a DAG. Start the wave, then wait
once — dispatching and waiting one worker at a time turns a parallel fleet into
a slow queue.

## Rules that cost us something to learn

**`check --wait --json` prints keepalives to stderr.** Piping merged streams into
a parser fails with `Extra data: line 2`. Pipe stdout only — never `2>&1 |`.

**A timeout is a checkpoint, not a failure.** Coding tasks run 15–60 minutes.
Heartbeats and terminal activity mean alive, not done. Do not stop, close, or
retry a worker because it has gone quiet.

**Account for every settled worker before waiting again.** Either hand its exact
terminal to a follow-up dispatch with `worker-start --terminal <handle>`, or
`worker-release`. Released workers stay readable via `worker-read`.

**A valid `worker_done` settles the task by itself.** Do not follow it with
`task-update --status completed`; manual status is for recovery only.

## Gates

A gate is a decision that is not a worker's to make — approving an interface,
approving a merge, changing a public contract.

```sh
orca orchestration gate-create --task <id> --question "Approve the interface?" --options '["approve","revise"]' --json
orca orchestration gate-resolve --id <gate_id> --resolution approve --json
```

Use `gate-create` only for coordinator-owned DAG decisions. A worker's blocking
question is `ask`, answered with `reply` — the two are not interchangeable.

## Recovery

A lost response naming no dispatch is read-only to diagnose:

```sh
orca orchestration request-show --request <request_id> --json
```

`completed` means the mutation already took effect; `pending` means it may still
be running. Replay with `--retry-request <request_id>` so the retry reuses the
same operation identity instead of creating a duplicate. `absent` is not proof
that nothing happened — inspect the affected state before retrying.

For a dispatch that proves `failed` or `stopped`, a replacement is explicit
about placement, because retry inherits nothing:

```sh
orca orchestration worker-start --task <task> --retry-of <dispatch_id> --worktree current --agent <agent> --json
```

## Backends

`orca/dispatch.sh` reads the frontmatter of `roles/<role>.md` and builds the
launch command. Two constraints from the runtime, both verified here:

- **`--model` and `--effort` apply to Claude, Codex and Cursor only.** Every
  other agent takes its model from its own configuration — for opencode, from
  `ORCA_OPENCODE_CONFIG_DIR`, which Orca sets per session.
- **`--effort` requires `--model`, and neither combines with `--terminal`.**

An agent Orca has not configured fails with `agent_unconfigured` — the same
error you get for a name that does not exist, so the message alone will not tell
you which of the two happened. Check the role's `agent:` against the configured
set before assuming Orca is broken.

`dispatch.sh` carries a hardcoded list of the configured agents and warns before
Orca gets the chance to, because that error is otherwise unactionable.

## The fresh-launch race

Verified against opencode 1.18.27, and worth knowing before you conclude an
agent is unsupported:

`worker-start --agent opencode` reports `agent_prompt_stalled` at
`dispatch_input`. The agent is **not** broken — its TUI comes up perfectly, and
`terminal wait --for tui-idle` on the very same terminal returns
`satisfied: true` a moment later. worker-start simply gives up on prompt
injection before the TUI is ready to take input.

The terminal it created is left running. So the recovery is to reuse the exact
terminal that just "failed" rather than spawn another:

```sh
orca terminal wait --terminal <handle> --for tui-idle --timeout-ms 60000 --json
orca orchestration worker-start --task <task_id> --terminal <handle>   --worktree current --retry-of <failed_dispatch_id> --json
```

That returns `state: ready`, `stage: input_accepted`, and the worker reports
`worker_done` normally. **`dispatch.sh` does this automatically** — it detects
`agent_prompt_stalled`, pulls the created terminal out of the failed receipt's
`effects`, waits for idle, and retries against it.

Two traps in implementing that, both of which cost a debugging cycle here:

- **`worker-start` exits 1 on a failed dispatch** ("exits 0 only for ready"), so
  under `set -e` the script dies before any recovery code runs. Guard the call.
- **A reused terminal is retained, not released.** `worker-release` deliberately
  never closes a pre-existing terminal, so a recovered worker leaves its terminal
  open. That is correct behavior, not a leak — but it means the sidebar
  accumulates one terminal per recovered agent until you close them.
