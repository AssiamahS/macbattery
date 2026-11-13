#!/bin/bash
# Installs/reloads the com.sly.macbattery launchd agent (runs the reporter every 2 min).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
DEST="$HOME/Library/LaunchAgents/com.sly.macbattery.plist"
[ -f "$HOME/.config/macbattery/secret" ] || { echo "missing ~/.config/macbattery/secret" >&2; exit 1; }
mkdir -p "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"
sed "s|__HOME__|$HOME|g" "$HERE/com.sly.macbattery.plist" > "$DEST"
plutil -lint "$DEST"
launchctl bootout "gui/$(id -u)/com.sly.macbattery" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$DEST"
launchctl print "gui/$(id -u)/com.sly.macbattery" | grep -E 'state|run interval|last exit'
