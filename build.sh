#!/usr/bin/env bash
# Build DSH Desktop (Electron) for Linux from the official DeepSeek Harness sources.
#   ./build.sh                      build the pinned upstream tag (run it with ./install.sh)
#   ./build.sh --appimage           also package a standalone AppImage into ./dist
#   DSH_TAG=dsh-v0.2.2-rc.1 ./build.sh   build another upstream tag
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
APPIMAGE=0
[ "${1:-}" = "--appimage" ] && APPIMAGE=1
DSH_TAG="${DSH_TAG:-$(cat "$HERE/UPSTREAM_TAG")}"
UPSTREAM="${DSH_UPSTREAM:-https://github.com/deepseek-ai/deepseek-harness.git}"
SRC="${DSH_DESKTOP_SRC:-${XDG_DATA_HOME:-$HOME/.local/share}/dsh-desktop-linux/src}"

say() { printf '\033[1m==> %s\033[0m\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

[ "$(uname -s)" = Linux ] || die "Linux only."
[ "$(uname -m)" = x86_64 ] || die "only x86_64 has been tested."
command -v git >/dev/null || die "git is required."
command -v cc >/dev/null || die "a C compiler (cc / gcc) is required for the native addon."
command -v node >/dev/null || die "Node.js 22.19+ is required."
node -e 'const [a,b]=process.versions.node.split(".").map(Number);process.exit(a>22||(a===22&&b>=19)?0:1)' \
  || die "Node.js 22.19+ is required (found $(node -v))."

if [ -d "$SRC/.git" ]; then
  say "Updating sources to $DSH_TAG"
  git -C "$SRC" reset -q --hard
  git -C "$SRC" fetch -q --depth 1 origin "refs/tags/$DSH_TAG:refs/tags/$DSH_TAG"
  git -C "$SRC" checkout -q "$DSH_TAG"
else
  say "Cloning $UPSTREAM ($DSH_TAG)"
  mkdir -p "$(dirname "$SRC")"
  git clone -q --depth 1 --branch "$DSH_TAG" "$UPSTREAM" "$SRC"
fi

say "Applying Linux patches"
for p in "$HERE"/patches/*.patch; do
  git -C "$SRC" apply "$p" && echo "  $(basename "$p")"
done

PNPM_VERSION="$(node -p "require('$SRC/package.json').packageManager.split('@')[1]")"
say "Installing dependencies (pnpm $PNPM_VERSION)"
cd "$SRC"
npx -y "pnpm@$PNPM_VERSION" install --frozen-lockfile

if [ "$APPIMAGE" = 1 ]; then
  say "Packaging the AppImage (15-25 minutes)"
  printf 'DSH_DESKTOP_APP_ID=%s\n' "${DSH_DESKTOP_APP_ID:-io.github.congo-digital-services.dsh-desktop}" > apps/desktop/.env.linux
  (cd apps/desktop && ../../node_modules/.bin/pnpm exec tsx scripts/package-target.ts linux-x64 --unsigned)
  mkdir -p "$HERE/dist"
  find apps/desktop/.desktop-build/targets/linux-x64 -name 'dsh-desktop-*.AppImage' -exec cp {} "$HERE/dist/" \;
  ls -1 "$HERE"/dist/*.AppImage >/dev/null 2>&1 || die "no AppImage produced."
  chmod +x "$HERE"/dist/*.AppImage
  say "Done: $(ls -1 "$HERE"/dist/*.AppImage | tail -1)"
  exit 0
fi

say "Building (a few minutes)"
node_modules/.bin/pnpm run build:artifacts

say "Done. Sources and build: $SRC"
echo "Next: ./install.sh"
