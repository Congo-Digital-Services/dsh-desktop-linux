#!/usr/bin/env bash
# Install the DSH Desktop launcher, menu entry, icon and notification plugin for the current user.
#   ./install.sh                  install (after ./build.sh)
#   ./install.sh --no-notify      install without the notification plugin
#   ./install.sh --uninstall      remove everything this script installed (keeps sources and ~/.dsh)
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
SRC="${DSH_DESKTOP_SRC:-$DATA/dsh-desktop-linux/src}"
BIN="$HOME/.local/bin"
APPS="$DATA/applications"
ICON="$DATA/icons/hicolor/512x512/apps/dsh-desktop.png"
PLUGIN="$DATA/dsh-desktop-linux/plugins/dsh-notify"
DSH_HOME="${DSH_HOME:-$HOME/.dsh}"
PATCH="$DSH_HOME/cordis.patch.yml"
MARK="# dsh-desktop-linux: notifications"

say() { printf '\033[1m==> %s\033[0m\n' "$*"; }

remove_notify_patch() {
  [ -f "$PATCH" ] || return 0
  python3 - "$PATCH" "$MARK" <<'PY'
import sys
path, mark = sys.argv[1], sys.argv[2]
lines = open(path).read().split('\n')
out, skip = [], 0
for l in lines:
    if l.strip() == mark: skip = 3; continue
    if skip: skip -= 1; continue
    out.append(l)
text = '\n'.join(out).strip()
open(path, 'w').write((text or '[]') + '\n')
PY
}

if [ "${1:-}" = "--uninstall" ]; then
  say "Uninstalling"
  rm -f "$BIN/dsh-desktop" "$APPS/dsh-desktop.desktop" "$ICON"
  rm -rf "$PLUGIN"
  remove_notify_patch
  command -v update-desktop-database >/dev/null && update-desktop-database "$APPS" 2>/dev/null || true
  echo "Sources kept in $SRC (delete them by hand if you want)."
  exit 0
fi

[ -d "$SRC/apps/desktop" ] || { echo "Sources not found in $SRC: run ./build.sh first." >&2; exit 1; }

say "Launcher: $BIN/dsh-desktop"
mkdir -p "$BIN"
install -m 755 "$HERE/bin/dsh-desktop" "$BIN/dsh-desktop"

say "Icon and menu entry"
mkdir -p "$(dirname "$ICON")" "$APPS"
cp "$SRC/apps/desktop/resources/icon-windows.png" "$ICON"
cat > "$APPS/dsh-desktop.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=DSH Desktop
Comment=DeepSeek Harness desktop app (community Linux build)
Exec=$BIN/dsh-desktop
Icon=dsh-desktop
Terminal=false
Categories=Development;
EOF
command -v update-desktop-database >/dev/null && update-desktop-database "$APPS" 2>/dev/null || true
command -v gtk-update-icon-cache >/dev/null && gtk-update-icon-cache -f -t "$DATA/icons/hicolor" 2>/dev/null || true

if [ "${1:-}" != "--no-notify" ]; then
  say "Notification plugin (applies to every dsh profile in $DSH_HOME)"
  command -v notify-send >/dev/null || echo "  warning: notify-send not found (package libnotify-bin / libnotify)."
  mkdir -p "$PLUGIN" "$DSH_HOME"
  cp "$HERE"/plugins/dsh-notify/* "$PLUGIN/"
  remove_notify_patch
  [ -s "$PATCH" ] && [ "$(tr -d '[:space:]' < "$PATCH")" = "[]" ] && : > "$PATCH"
  cat >> "$PATCH" <<EOF
$MARK
- insert:
    - id: dsh-notify
      name: $PLUGIN/index.js
EOF
fi

case ":$PATH:" in *":$BIN:"*) ;; *) echo "Add $BIN to your PATH to run dsh-desktop from a terminal." ;; esac
say "Done. Open \"DSH Desktop\" from your application menu."
