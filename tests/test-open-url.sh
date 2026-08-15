#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
FIXTURES="$ROOT/tests/fixtures"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/bin" "$TMP/state/chroncal" "$TMP/fixtures"
ln -s "$ROOT/tests/fakes/chroncal" "$TMP/bin/chroncal"
cp "$FIXTURES/calendars.json" "$TMP/fixtures/calendars.json"
start_time=$(date -u -d "+1 hour" +%Y-%m-%dT%H:%M:%SZ)
end_time=$(date -u -d "+2 hours" +%Y-%m-%dT%H:%M:%SZ)
jq --arg start_time "$start_time" --arg end_time "$end_time" '
  map(select(.uid != "ended")
    | if .uid == "standup" then
        .start_time = $start_time
        | .end_time = $end_time
        | .conference_uri = "zoommtg://zoom.us/join?confno=123"
      else . end)
' "$FIXTURES/events.json" >"$TMP/fixtures/events.json"
cp "$FIXTURES/state/chroncal/state.json" "$TMP/state/chroncal/state.json"
cat >"$TMP/bin/xdg-open" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$1" >"$CHRONCAL_OPEN_LOG"
EOF
cat >"$TMP/bin/notify-send" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$TMP/bin/xdg-open" "$TMP/bin/notify-send"

export PATH="$TMP/bin:$PATH"
export XDG_STATE_HOME="$TMP/state"
export CHRONCAL_FAKE_FIXTURES="$TMP/fixtures"
export CHRONCAL_FAKE_LOG="$TMP/chroncal.log"
export CHRONCAL_OPEN_LOG="$TMP/open.log"

"$ROOT/scripts/chroncal-open-next-event-url"
for _ in $(seq 1 50); do
  [[ -f "$CHRONCAL_OPEN_LOG" ]] && break
  sleep 0.02
done

test "$(cat "$CHRONCAL_OPEN_LOG")" = "zoommtg://zoom.us/join?confno=123"
printf 'next event URL tests: ok\n'
