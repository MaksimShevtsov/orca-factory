# CLAUDE.md

Read **`AGENTS.md`** first. It is the map for every agent working here, Claude
included, and this file does not repeat it.

Then read, in order:

1. `roles/_common.md` — the contract binding every role
2. `roles/<your-role>.md` — your mandate, and what you must not touch

If you were not given a role, you are the coordinator: read `roles/pm.md` and
`orca/README.md`.

## The two rules most often broken here

**Task status lives in Orca, never in this repo.** No status field, no status
directory. `orca orchestration task-list --ready` is the only answer to "what is
unblocked".

**Print your results.** The `/goal` evaluator and the reviewer read the
transcript, not your files. End every run with the GATE block from
`roles/_common.md` and paste it into `worker_done`.

## Checks

```sh
./evals/run.sh          # the factory's own gates; prints GATE/VERDICT
DRY_RUN=1 ./orca/dispatch.sh <role> <task_id>   # show a launch command
```
