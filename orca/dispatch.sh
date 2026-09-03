#!/usr/bin/env bash
# Launch a role as a supervised Orca worker.
#
#   ./orca/dispatch.sh <role> <task_id> [extra worker-start args...]
#   DRY_RUN=1 ./orca/dispatch.sh <role> <task_id>    # print, do not run
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

# Agents Orca can launch itself with --agent. An agent outside this set can still
# be driven, but only through the two-step path below.
KNOWN_AGENTS="aider amp ante antigravity autohand claude claude-agent-teams cline codex
command-code continue copilot crush cursor devin droid gemini grok hermes kimi kiro
mistral-vibe openclaude opencode qwen-code rovo trae"

# Orca knowing a name is NOT proof the agent can run. Verified 2026-09-03 on this
# host: codex is configured but not installed; gemini is both, and still dies at
# an auth wall. Installation is the cheapest of those to check, so check it.
if ! command -v "$AGENT" >/dev/null 2>&1; then
  echo "error: '$AGENT' (roles/$ROLE.md) is not installed on this host." >&2
  echo "       The terminal would open a shell and the dispatch would time out." >&2
  exit 2
fi

CONFIGURED=no
case " $(echo $KNOWN_AGENTS) " in *" $AGENT "*) CONFIGURED=yes ;; esac

echo "dispatch $ROLE -> agent=$AGENT model=${MODEL:-<agent config>} effort=${EFFORT:-n/a} (orca-launchable=$CONFIGURED)" >&2

read -r -d '' PY_HANDLE <<'PY' || true
import sys, json
try: d = json.load(sys.stdin)
except Exception: sys.exit(0)
r = d.get("result") or {}
t = r.get("terminal") or r
print(t.get("handle") or r.get("handle") or "")
PY

read -r -d '' PY_WAIT <<'PY' || true
import sys, json
try: d = json.load(sys.stdin)
except Exception: sys.exit(0)
w = (d.get("result") or {}).get("wait") or {}
print(w.get("satisfied"), w.get("blockedReason") or "")
PY

read -r -d '' PY_TITLE <<'PY' || true
import sys, json
try: d = json.load(sys.stdin)
except Exception: sys.exit(0)
r = d.get("result") or {}
t = r.get("terminal") or r
print((t.get("title") or "").lower())
PY

read -r -d '' PY_STALL <<'PY' || true
import sys, json
try: d = json.load(sys.stdin)
except Exception: sys.exit(0)
r = d.get("result") or {}
if r.get("lastError") != "agent_prompt_stalled": sys.exit(0)
h = ""
for e in r.get("effects") or []:
    if e.get("kind") == "terminal" and e.get("action") == "created":
        h = e.get("id") or ""
if h: print(h, r.get("dispatchId") or "")
PY

# ---------------------------------------------------------------------------
# Two-step path: installed, but Orca cannot launch it with --agent.
#
# Verified with agy (Antigravity CLI 1.1.25, Gemini 3.8 Flash). Orca can still
# SUPERVISE any agent once a terminal is running it: worker-start --terminal
# injects the task and the agent reports worker_done normally. What Orca cannot
# do for an unknown agent is START it.
#
# One-time cost per project: the agent's own workspace-trust prompt must be
# accepted by hand. Until it is, terminal wait --for tui-idle returns
# satisfied:false with a blockedReason. Afterwards a FRESH terminal is needed,
# because the accepted prompt stays in the scrollback and keeps matching.
# ---------------------------------------------------------------------------
if [ "$CONFIGURED" = "no" ]; then
  case "$AGENT" in
    agy) LAUNCH="agy --dangerously-skip-permissions${MODEL:+ --model $MODEL}" ;;
    *)   LAUNCH="$AGENT" ;;
  esac

  if [ -n "${DRY_RUN:-}" ]; then
    echo "orca terminal create --worktree current --title worker-$ROLE --command '$LAUNCH' --json"
    echo "orca terminal wait --terminal <handle> --for tui-idle --timeout-ms 90000 --json"
    echo "orca orchestration worker-start --task $TASK --terminal <handle> --worktree current $* --json"
    exit 0
  fi

  HANDLE="$(orca terminal create --worktree current --title "worker-$ROLE" --command "$LAUNCH" --json 2>&1 | python -c "$PY_HANDLE" 2>/dev/null)"
  [ -n "$HANDLE" ] || { echo "error: could not create a terminal for $AGENT" >&2; exit 1; }
  echo "note: $AGENT is not Orca-launchable; started it in $HANDLE" >&2

  WAIT="$(orca terminal wait --terminal "$HANDLE" --for tui-idle --timeout-ms 90000 --json 2>&1 | python -c "$PY_WAIT" 2>/dev/null)"
  case "$WAIT" in
    True*) ;;
    *)
      echo "error: $AGENT never became ready ($WAIT)" >&2
      echo "       If the reason mentions trust, open $HANDLE in Orca, accept the" >&2
      echo "       workspace-trust prompt once, then re-run this dispatch." >&2
      exit 1 ;;
  esac

  exec orca orchestration worker-start --task "$TASK" --terminal "$HANDLE" --worktree current "$@" --json
fi

# ---------------------------------------------------------------------------
# Normal path: Orca launches the agent itself.
# --model/--effort are accepted only for these agents; --effort requires --model.
# Every other agent takes its model from its own config.
# ---------------------------------------------------------------------------
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

if [ -n "${DRY_RUN:-}" ]; then
  printf 'orca'; printf ' %s' "${ARGS[@]}" "$@" --json; printf '\n'
  exit 0
fi

# NB: set -e is on and worker-start exits 1 on a failed dispatch ("exits 0 only
# for ready"), so this MUST be guarded -- otherwise the script dies here and the
# recovery below can never run.
OUT=""; RC=0
OUT="$(orca "${ARGS[@]}" "$@" --json 2>&1)" || RC=$?

# Fresh-launch race: some agents (verified with opencode 1.18.27) start fine but
# worker-start reports agent_prompt_stalled at dispatch_input -- it gives up
# before the TUI accepts input, leaving the terminal running. Reuse that exact
# terminal rather than spawning another.
RECOVER="$(printf '%s' "$OUT" | python -c "$PY_STALL" 2>/dev/null)"

if [ -n "$RECOVER" ]; then
  HANDLE="${RECOVER%% *}"; PRIOR="${RECOVER##* }"

  # Only reuse a terminal whose AGENT is still alive. When an agent exits during
  # startup -- claude quits after printing the Bypass Permissions consent screen
  # if that consent was never accepted -- the terminal falls back to a bare
  # shell, and a bare shell reports tui-idle just as happily as a ready agent.
  # Injecting a task spec there types it into PowerShell. Refuse instead.
  TITLE="$(orca terminal show --terminal "$HANDLE" --json 2>/dev/null | python -c "$PY_TITLE" 2>/dev/null)"
  case "$TITLE" in
    *powershell.exe*|*pwsh.exe*|*cmd.exe*|*bash.exe*|*/bin/sh*|*/bin/bash*)
      echo "error: $AGENT exited during startup; terminal $HANDLE is a bare shell" >&2
      echo "       ($TITLE)" >&2
      echo "       Refusing to inject the task into a shell. Common cause: the agent's" >&2
      echo "       default args need a one-time interactive consent (claude:" >&2
      echo "       --dangerously-skip-permissions). Accept it once in an Orca terminal," >&2
      echo "       or change the agent's default args in Orca settings." >&2
      printf '%s\n' "$OUT"
      exit 1 ;;
  esac

  echo "note: $AGENT stalled at prompt injection; reusing terminal $HANDLE" >&2
  orca terminal wait --terminal "$HANDLE" --for tui-idle --timeout-ms 60000 --json >/dev/null 2>&1
  RETRY=(orchestration worker-start --task "$TASK" --terminal "$HANDLE" --worktree current)
  [ -n "$PRIOR" ] && RETRY+=(--retry-of "$PRIOR")
  exec orca "${RETRY[@]}" --json
fi

printf '%s\n' "$OUT"
exit $RC
