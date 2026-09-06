#!/usr/bin/env bash
# The factory's own gates.
#
# Prints the GATE/VERDICT block defined in roles/_common.md. Every worker pastes
# that block into its worker_done body, and the /goal evaluator reads it from the
# transcript -- it cannot read files or run commands, so a result that is not
# printed did not happen as far as it is concerned.
#
# Exit 0 = READY, exit 1 = BLOCKED.
set -uo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO"

FAILED=""
gate() { # gate <name> <PASS|FAIL> [detail]
  printf 'GATE %-12s %-6s %s\n' "$1" "$2" "${3:-}"
  [ "$2" = "FAIL" ] && [ -z "$FAILED" ] && FAILED="$1"
  return 0
}

fm() { # fm <role> <key>
  awk -v key="$2" '
    NR==1 && /^---[[:space:]]*$/ { i=1; next }
    i && /^---[[:space:]]*$/ { exit }
    i && index($0, key ":") == 1 { sub("^" key ":[[:space:]]*", ""); print; exit }
  ' "roles/$1.md"
}

ROLES=$(ls roles/*.md | grep -v '_common' | xargs -n1 basename | sed 's/\.md$//')
N=$(echo "$ROLES" | wc -w | tr -d ' ')

# --- contract: frontmatter complete, and the common contract is referenced -----
bad=""
for r in $ROLES; do
  for k in agent model effort; do
    [ -n "$(fm "$r" "$k")" ] || bad="$bad $r:$k"
  done
  grep -q '_common\.md' "roles/$r.md" || bad="$bad $r:no-contract-ref"
done
[ -z "$bad" ] && gate contract PASS "$N/$N roles" || gate contract FAIL "$bad"

# --- agents: every role's backend is one Orca has configured -------------------
# Reuses the guard in orca/dispatch.sh so the known-agent list has exactly one home.
#
# NB: capture, do NOT pipe into `grep -q`. Under `set -o pipefail`, grep -q exits
# on first match, the upstream write takes SIGPIPE and dies 141, and pipefail
# promotes that to the pipeline's status -- so the test fails exactly when it matches.
unconf=""
for r in $ROLES; do
  warn=$(DRY_RUN=1 ./orca/dispatch.sh "$r" task_SELFTEST 2>&1 >/dev/null)
  case "$warn" in
    *"not in Orca's configured agent set"*) unconf="$unconf$r " ;;
    *"is not installed on this host"*)      unconf="$unconf$r " ;;
  esac
done
# "configured+installed" is deliberately NOT "launchable". This gate cannot prove
# an agent will accept a dispatch -- claude can exit at a consent screen and
# gemini at an auth wall while both are configured and installed. Only a real
# dispatch proves that, and this gate does not perform one.
[ -z "$unconf" ] && gate agents PASS "$N/$N configured+installed" || gate agents FAIL "cannot launch: $unconf"

# --- dispatch: a launch command can be built for every role --------------------
broke=""
for r in $ROLES; do
  DRY_RUN=1 ./orca/dispatch.sh "$r" task_SELFTEST >/dev/null 2>&1 || broke="$broke$r "
done
[ -z "$broke" ] && gate dispatch PASS "$N/$N build" || gate dispatch FAIL "$broke"

# --- cards: every card carries an acceptance line ------------------------------
cards=$(ls cards/*.md 2>/dev/null | grep -v 'README' || true)
if [ -z "$cards" ]; then
  gate cards PASS "0 cards"
else
  noacc=""; n=0
  for c in $cards; do
    n=$((n+1))
    grep -qi '^\*\*Acceptance:\*\*' "$c" || noacc="$noacc$(basename "$c") "
  done
  [ -z "$noacc" ] && gate cards PASS "$n/$n with acceptance" || gate cards FAIL "no acceptance: $noacc"
fi

# --- golden set ----------------------------------------------------------------
# Cases live in evals/golden/<class>/*.yaml. agent-failures is the class that pays
# for itself: each case is a mistake an agent actually made here, turned into a
# check that fails if the guardrail is ever removed.
if [ -x evals/golden/run.sh ]; then
  gout="$(./evals/golden/run.sh 2>&1)"; grc=$?
  gsum="$(printf '%s' "$gout" | tail -1)"
  if [ $grc -eq 0 ]; then
    case "$gsum" in
      *"0/0"*) gate golden SKIP "no cases yet" ;;
      *)       gate golden PASS "${gsum#GOLDEN }" ;;
    esac
  else
    gate golden FAIL "${gsum#GOLDEN }"
    printf '%s
' "$gout" | grep -E '^  (FAIL|ERROR)' | sed 's/^/               /'
  fi
else
  gate golden SKIP "no runner at evals/golden/run.sh"
fi

# --- map: the entry points exist -----------------------------------------------
missing=""
for f in AGENTS.md CLAUDE.md roles/_common.md orca/README.md orca/pipeline.yaml cards/README.md VERSION CHANGELOG.md; do
  [ -f "$f" ] || missing="$missing$f "
done
[ -z "$missing" ] && gate map PASS "8/8 present" || gate map FAIL "missing: $missing"

if [ -n "$FAILED" ]; then echo "VERDICT: BLOCKED on $FAILED"; exit 1; fi
echo "VERDICT: READY"
