# Changelog

All notable changes to the orca factory are documented here. The format is
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow
[Semantic Versioning](https://semver.org/). The current version lives in
`VERSION` at the repo root — one file, one source of truth.

## [Unreleased]

### Added

- `install.sh init <target> [description]` — install the factory and initialize
  the kit into a project in one command:
  `curl -fsSL ... | bash -s -- init <target> "description"`.

## [0.1.0] - 2026-09-06

Initial public state of the kit, as installed from GitHub.

### Added

- Seven roles under a common contract (`roles/`), dispatched through Orca.
- The factory's own gates (`evals/run.sh`): contract, agents, dispatch,
  cards, golden, map — printing the GATE/VERDICT block.
- The golden set (`evals/golden/`), with `agent-failures/`: mistakes agents
  actually made here, kept as running checks.
- The control plane kit (`orca/`): the dispatch loop, role-to-launch-command
  mapping, and recovery paths for agents Orca cannot launch itself.
- `bin/factory init/update/check` — install the kit into a project, keep it
  synced, run its gates; three file categories decide who may edit what.
- `install.sh` and `factory self-update` — install from GitHub via
  `curl | bash`, clone to `~/.orca-factory`, shim `factory` onto PATH.
- This changelog and the `VERSION` file; `factory version` reports both the
  version and the commit.
