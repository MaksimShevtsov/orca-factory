#!/usr/bin/env bash
# Launch a role as a supervised Orca worker.
#
#   ./orca/dispatch.sh <role> <task_id> [extra worker-start args...]
#
# Reads agent/model/effort from roles/<role>.md frontmatter so the role file
# stays the single source of truth for which backend runs which seat.
set -euo pipefail

ROLE="${1:-}"; TASK="${2:-}"; shift 2 2>/dev/null || true
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FILE="$REPO/roles/$ROLE.md"

if [ -z "$ROLE" ] || [ -z "$TASK" ]; then
  echo "usage: $0 <role> <task_id> [extra worker-start args...]" >&2
  echo "roles:" >&2; ls "$REPO/roles" | sed 's/\.md$//' | grep -v '^_' | sed 's/^/  /' >&2
  exit 2
fi
[ -f "$FILE" ] || { echo "no such role: $ROLE ($FILE)" >&2; exit 2; }

fm() {
  awk -v key="$1" '
    NR==1 && $0 ~ /^---[[:space:]]*$/ { inside=1; next }
    inside && $0 ~ /^---[[:space:]]*$/ { exit }
    inside && index($0, key ":") == 1 {
      sub("^" key ":[[:space:]]*", ""); print; exit
    }
  ' "$FILE"
}
AGENT="$(fm agent)"; MODEL="$(fm model)"; EFFORT="$(fm effort)"
[ -n "$AGENT" ] || { echo "$ROLE: no agent in frontmatter" >&2; exit 2; }

# Agents Orca has configured on this host. An agent outside this set fails with
# `agent_unconfigured` — the SAME error Orca gives for a name that does not exist,
# so the runtime message alone cannot tell you which mistake you made. Verified
# 2026-09-03: `agy` is NOT configured; `opencode` is (it simply has no default args).
KNOWN_AGENTS="aider amp ante antigravity autohand claude claude-agent-teams cline codex
command-code continue copilot crush cursor devin droid gemini grok hermes kimi kiro
mistral-vibe openclaude opencode qwen-code rovo trae"
case " $(echo $KNOWN_AGENTS) " in
  *" $AGENT "*) ;;
  *) echo "warning: '$AGENT' (roles/$ROLE.md) is not in Orca's configured agent set." >&2
     echo "         worker-start will fail with agent_unconfigured. Known agents:" >&2
     echo "$KNOWN_AGENTS" | tr ' ' '
' | grep -v '^$' | sort | column -c 76 2>/dev/null        || echo "$KNOWN_AGENTS" >&2 ;;
esac

# --model/--effort are accepted only for these agents; --effort requires --model.
# Every other agent takes its model from its own config (opencode: $ORCA_OPENCODE_CONFIG_DIR).
ARGS=(orchestration worker-start --task "$TASK" --worktree current --agent "$AGENT")
case "$AGENT" in
  claude|codex|cursor)
    if [ -n "$MODEL" ]; then
      ARGS+=(--model "$MODEL")
      [ -n "$EFFORT" ] && ARGS+=(--effort "$EFFORT")
    fi
    ;;
  *)
    if [ -n "$MODEL" ]; then
      echo "note: $AGENT does not accept --model; '$MODEL' comes from its own config" >&2
    fi
    ;;
esac

echo "dispatch $ROLE -> agent=$AGENT model=${MODEL:-<agent config>} effort=${EFFORT:-n/a}" >&2

# DRY_RUN=1 prints the command instead of running it. Used by evals/run.sh.
if [ -n "${DRY_RUN:-}" ]; then
  printf 'orca'; printf ' %s' "${ARGS[@]}" "$@" --json; printf '
'
  exit 0
fi

# NB: `set -e` is on and worker-start exits 1 on a failed dispatch ("exits 0 only
# for ready"), so this MUST be guarded -- otherwise the script dies here and the
# recovery below can never run.
OUT=""; RC=0
OUT="$(orca "${ARGS[@]}" "$@" --json 2>&1)" || RC=$?

# Fresh-launch race: some agents (verified with opencode 1.18.27) start fine but
# worker-start reports `agent_prompt_stalled` at dispatch_input -- it gives up
# before the TUI accepts input. The terminal it created is left RUNNING and
# becomes idle a moment later, so the recovery is to reuse that exact terminal
# rather than spawn another. Verified: --terminal on the stalled terminal
# returns state=ready/stage=input_accepted and the worker reports worker_done.
RECOVER="$(printf '%s' "$OUT" | python -c '
import sys, json
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
r = d.get("result") or {}
if r.get("lastError") != "agent_prompt_stalled":
    sys.exit(0)
h = ""
for e in r.get("effects") or []:
    if e.get("kind") == "terminal" and e.get("action") == "created":
        h = e.get("id") or ""
if h:
    print(h, r.get("dispatchId") or "")
' 2>/dev/null)"

if [ -n "$RECOVER" ]; then
  HANDLE="${RECOVER%% *}"; PRIOR="${RECOVER##* }"
  echo "note: $AGENT stalled at prompt injection; reusing terminal $HANDLE" >&2
  orca terminal wait --terminal "$HANDLE" --for tui-idle --timeout-ms 60000 --json >/dev/null 2>&1
  RETRY=(orchestration worker-start --task "$TASK" --terminal "$HANDLE" --worktree current)
  [ -n "$PRIOR" ] && RETRY+=(--retry-of "$PRIOR")
  exec orca "${RETRY[@]}" --json
fi

printf '%s
' "$OUT"
exit $RC
