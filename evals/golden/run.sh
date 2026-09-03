#!/usr/bin/env bash
# Run the golden set.
#
#   ./evals/golden/run.sh [class]     # all classes, or one of behavior|regression|incidents|agent-failures
#
# Each case is a .yaml file under evals/golden/<class>/ with at least:
#
#   id:     AF-001
#   title:  one line
#   check: |
#     shell that must exit 0
#
# A case PASSES when its check exits 0. Nothing is inferred from silence: a case
# with no check is an ERROR, not a pass, because a golden set that quietly counts
# unrunnable cases as green is worse than having none.
#
# Exit 0 when every case passes, 1 otherwise.
set -uo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO"
ONLY="${1:-}"

DIR="evals/golden"
[ -n "$ONLY" ] && DIR="evals/golden/$ONLY"
[ -d "$DIR" ] || { echo "no such golden class: $ONLY" >&2; exit 2; }

mapfile -t CASES < <(find "$DIR" -name '*.yaml' -o -name '*.yml' 2>/dev/null | sort)
if [ "${#CASES[@]}" -eq 0 ]; then
  echo "GOLDEN 0/0 (no cases)"
  exit 0
fi

# Parse one field. Uses PyYAML when present; falls back to a minimal parser so a
# generated project with no third-party packages still runs its own golden set.
field() { # field <file> <key>
  python - "$1" "$2" <<'PY'
import sys
path, key = sys.argv[1], sys.argv[2]
text = open(path, encoding="utf-8", errors="replace").read()
data = None
try:
    import yaml
    data = yaml.safe_load(text)
except Exception:
    data = None
if isinstance(data, dict):
    v = data.get(key)
    if v is not None:
        sys.stdout.write(str(v))
    raise SystemExit
# Minimal fallback: `key: value`, plus `key: |` / `key: >` indented blocks.
lines, out, grabbing, indent = text.splitlines(), [], False, None
for line in lines:
    if grabbing:
        if line.strip() == "" or line[:1] in (" ", "\t"):
            if indent is None and line.strip():
                indent = len(line) - len(line.lstrip())
            out.append(line[indent:] if indent else line.strip())
            continue
        break
    if line.startswith(key + ":"):
        rest = line[len(key) + 1:].strip()
        if rest in ("|", ">", "|-", ">-"):
            grabbing = True
            continue
        out.append(rest)
        break
sys.stdout.write("\n".join(out).strip())
PY
}

pass=0; fail=0; err=0
for c in "${CASES[@]}"; do
  id="$(field "$c" id)";      [ -n "$id" ] || id="$(basename "$c" .yaml)"
  title="$(field "$c" title)"
  check="$(field "$c" check)"

  if [ -z "$check" ]; then
    printf '  ERROR %-10s %s\n' "$id" "no check: block in $c"
    err=$((err+1)); continue
  fi

  if out="$(bash -c "$check" 2>&1)"; then
    printf '  PASS  %-10s %s\n' "$id" "$title"
    pass=$((pass+1))
  else
    printf '  FAIL  %-10s %s\n' "$id" "$title"
    printf '%s\n' "$out" | sed 's/^/          /' | head -6
    fail=$((fail+1))
  fi
done

total=$((pass+fail+err))
echo "GOLDEN $pass/$total"
[ $((fail+err)) -eq 0 ] || exit 1
exit 0
