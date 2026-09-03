# copilot factory

A kit for running a fleet of coding agents against a codebase: roles,
procedures, gates, and the Orca control plane that coordinates them.

This repo is both the source of the kit and a working instance of it — the
roles here are the ones that get installed, so a broken role breaks the factory
first and you find out here rather than in a generated project.

## Start a new project

```sh
bin/factory init ../my-service "One paragraph on what this system does."
cd ../my-service && ./evals/run.sh
```

`init` copies the kit, detects the stack (node / python / go / rust) to fill in
the test, lint and typecheck gates, and writes `.factory-version`. If the stack
is not recognized, the commands are left as explicit `TODO`s and those gates
report **SKIP** — never a false PASS. An unconfigured `tests` gate blocks the
verdict outright: a project that verified nothing reports
`BLOCKED on tests`, not `READY`. A suite that passes because it ran nothing is
worse than no suite, because it gets believed.

## Keep projects current

```sh
bin/factory update ../my-service
```

Three categories of file, and which one a file is in decides who may edit it:

| | Files | `update` |
|---|---|---|
| **Synced** | `roles/`, `skills/`, `orca/`, `cards/README.md`, `.gitattributes`, `evals/golden/run.sh` | overwrites — the factory owns these |
| **Templated** | `AGENTS.md`, `CLAUDE.md`, `evals/run.sh`, `docs/index.md` | never touches — generated once, yours after |
| **Project** | `cards/`, `docs/`, `reports/`, `evals/golden/` | never touches — your content |

`.factory-version` stores a hash per synced file, so `update` can tell a stale
file from a locally edited one. Edit a synced file in a project and update
**stops, shows the diff, and changes nothing** — because a sync that silently
discards someone's work is not an update, it is data loss with a friendly name.
Move the change into the factory, or re-run with `FORCE=1` to discard it.

## What is here

```
AGENTS.md          the map every agent reads first
roles/             WHO  — the contract plus seven roles
skills/            HOW  — the three procedures superpowers does not ship
orca/              the control plane: loop, DAG, role -> launch command
cards/             durable specs and acceptance lines
evals/run.sh       the gates; prints the GATE/VERDICT block
evals/golden/      the golden set + its runner; agent-failures/ holds
                   mistakes agents actually made here, as running checks
template/          what init renders into a new project
bin/factory        init / update / check
```

## The two ideas it rests on

**Orca owns live state; the repo owns durable state, and neither duplicates the
other.** The task DAG, ownership and completion live in Orca. Specs, behavior
contracts, decisions and lessons live in git. There is no status field in this
repo, because a second copy of the truth is wrong within the hour.

**Print your results.** The `/goal` evaluator reads the transcript — it cannot
read files or run commands. A result nobody printed did not happen. Hence the
GATE/VERDICT block, and hence no weighted score: one number hides the class that
failed, and the class that fails is always the one that mattered.
