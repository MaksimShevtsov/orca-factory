#!/usr/bin/env bash
# Install the orca factory onto this machine.
#
#   bash <(curl -fsSL https://raw.githubusercontent.com/MaksimShevtsov/orca-factory/main/install.sh)
#
# Or install the factory AND initialize a project with the kit, in one command:
#
#   curl -fsSL https://raw.githubusercontent.com/MaksimShevtsov/orca-factory/main/install.sh \
#     | bash -s -- init ../my-service "What this system does, and who depends on it."
#
# Clones the factory to ~/.orca-factory and puts a `factory` shim on PATH
# (~/.local/bin). Idempotent: re-running pulls the existing clone and rewrites
# the shim. Needs git and a POSIX shell (Git Bash on Windows).
#
# Overrides, used by the factory's own checks:
#   FACTORY_REPO  git URL to install from   (default: GitHub, above)
#   FACTORY_HOME  where the clone lives     (default: ~/.orca-factory)
#   FACTORY_BIN   where the shim goes       (default: ~/.local/bin)
set -uo pipefail

REPO="${FACTORY_REPO:-https://github.com/MaksimShevtsov/orca-factory.git}"
DEST="${FACTORY_HOME:-$HOME/.orca-factory}"
BIN_DIR="${FACTORY_BIN:-$HOME/.local/bin}"

die() { echo "error: $*" >&2; exit 1; }
say() { printf '%s\n' "$*"; }

# Optional mode: `init <target> [description...]` — after ensuring the factory,
# run `factory init` on the target. No arguments means: install the factory only.
MODE="" TARGET="" DESC=""
if [ "${1:-}" = "init" ]; then
  MODE=init
  TARGET="${2:-}"
  [ -n "$TARGET" ] || die "usage: install.sh init <target> [description...]"
  shift 2
  DESC="$*"
fi

command -v git >/dev/null 2>&1 || die "git is required"

if [ -d "$DEST/.git" ]; then
  say "update $DEST"
  git -C "$DEST" diff --quiet && git -C "$DEST" diff --cached --quiet \
    || die "local changes in $DEST; commit or revert them (an installed factory tracks upstream)"
  git -C "$DEST" pull --ff-only \
    || die "git pull failed in $DEST"
elif [ -e "$DEST" ]; then
  die "$DEST exists and is not a factory clone; remove it or set FACTORY_HOME"
else
  say "clone $REPO"
  git clone -q "$REPO" "$DEST" \
    || die "git clone failed (check the URL, or set FACTORY_REPO)"
fi

sha="$(git -C "$DEST" rev-parse --short HEAD)"
ver="$(sed -n '1p' "$DEST/VERSION" 2>/dev/null || echo unknown)"

mkdir -p "$BIN_DIR" || die "cannot create $BIN_DIR"
shim="$BIN_DIR/factory"
{
  echo '#!/usr/bin/env bash'
  echo "# Installed by the orca factory installer; re-run install.sh to regenerate."
  echo "exec \"$DEST/bin/factory\" \"\$@\""
} > "$shim" || die "cannot write $shim"
chmod +x "$shim" 2>/dev/null || say "! could not chmod +x $shim"

say ""
say "installed  $DEST  ($ver, $sha)"
say "shim       $shim"

case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *)
    say ""
    say "! $BIN_DIR is not on PATH. Add this to your shell profile:"
    say "    export PATH=\"$BIN_DIR:\$PATH\""
    ;;
esac

if [ "$MODE" = "init" ]; then
  say ""
  # exec: the init output (including its own "next" block) is the finale, and
  # its exit code — success or "already initialized" failure — becomes ours.
  exec "$DEST/bin/factory" init "$TARGET" "$DESC"
fi

say ""
say "next:"
say "  factory init ../my-service \"One paragraph on what this system does.\""
