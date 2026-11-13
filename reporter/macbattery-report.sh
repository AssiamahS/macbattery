#!/bin/bash
# Reads `pmset -g batt` and POSTs it to the macbattery Worker.
# Config: ~/.config/macbattery/secret (shared secret), optional ~/.config/macbattery/endpoint
set -euo pipefail

CONF="$HOME/.config/macbattery"
ENDPOINT="https://macbattery.sylvesterassiamahpm.workers.dev/battery"
[ -f "$CONF/endpoint" ] && ENDPOINT="$(tr -d '[:space:]' < "$CONF/endpoint")"
SECRET="$(tr -d '[:space:]' < "$CONF/secret")"

RAW="${PMSET_OUTPUT:-$(/usr/bin/pmset -g batt)}"  # PMSET_OUTPUT overrides for testing
SOURCE="$(printf '%s\n' "$RAW" | sed -n "s/.*drawing from '\(.*\)'.*/\1/p" | head -1)"
LINE="$(printf '%s\n' "$RAW" | grep -E '[0-9]+%;' | head -1 || true)"

if [ -z "$LINE" ]; then
  echo "no internal battery found in pmset output" >&2
  exit 1
fi

PERCENT="$(printf '%s' "$LINE" | sed -E 's/.*[[:space:]]([0-9]+)%;.*/\1/')"
STATE="$(printf '%s' "$LINE" | awk -F'; ' '{print $2}' | sed 's/[^A-Za-z ]//g')"

ON_AC=false
[ "$SOURCE" = "AC Power" ] && ON_AC=true
CHARGING=false
[ "$STATE" = "charging" ] && CHARGING=true
[ "$STATE" = "finishing charge" ] && CHARGING=true

MINUTES=null
if T="$(printf '%s' "$LINE" | grep -oE '[0-9]+:[0-9]{2} remaining' | awk '{print $1}')" && [ -n "$T" ]; then
  H="${T%%:*}"; M="${T##*:}"
  MINUTES=$((10#$H * 60 + 10#$M))
  # pmset prints 0:00 while calculating or when full; treat as unknown unless charged
  [ "$MINUTES" -eq 0 ] && [ "$STATE" != "charged" ] && MINUTES=null
fi

DEVICE="$(/usr/sbin/scutil --get ComputerName 2>/dev/null | tr -cd 'A-Za-z0-9 ._-' | cut -c1-60)"
[ -z "$DEVICE" ] && DEVICE="MacBook"
NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

BODY=$(printf '{"percent":%s,"charging":%s,"onAC":%s,"state":"%s","minutesRemaining":%s,"device":"%s","reportedAt":"%s"}' \
  "$PERCENT" "$CHARGING" "$ON_AC" "$STATE" "$MINUTES" "$DEVICE" "$NOW")

if [ "${1:-}" = "--dry-run" ]; then
  echo "$BODY"
  exit 0
fi

/usr/bin/curl -fsS --max-time 20 --retry 2 \
  -H "content-type: application/json" \
  -H "x-battery-secret: $SECRET" \
  --data "$BODY" "$ENDPOINT"
echo
