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
cp "$FIXTURES/state/chroncal/state.json" "$TMP/state/chroncal/state.json"
cat >"$TMP/bin/xdg-open" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$1" >>"$CHRONCAL_OPEN_LOG"
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
: >"$CHRONCAL_OPEN_LOG"

# A web link is opened.
jq --arg start_time "$start_time" --arg end_time "$end_time" '
  map(select(.uid == "standup")
    | .start_time = $start_time
    | .end_time = $end_time
    | .conference_uri = "https://meet.example.test/standup")
' "$FIXTURES/events.json" >"$TMP/fixtures/events.json"

"$ROOT/scripts/chroncal-open-next-event-url"
for _ in $(seq 1 50); do
  grep -qx 'https://meet.example.test/standup' "$CHRONCAL_OPEN_LOG" && break
  sleep 0.02
done
grep -qx 'https://meet.example.test/standup' "$CHRONCAL_OPEN_LOG"

# A non-web scheme is refused and never reaches xdg-open.
jq --arg start_time "$start_time" --arg end_time "$end_time" '
  map(select(.uid == "standup")
    | .start_time = $start_time
    | .end_time = $end_time
    | .conference_uri = "zoommtg://zoom.us/join?confno=123")
' "$FIXTURES/events.json" >"$TMP/fixtures/events.json"

"$ROOT/scripts/chroncal-open-next-event-url"
sleep 0.5
if grep -q 'zoommtg://' "$CHRONCAL_OPEN_LOG"; then
  echo 'non-web URL was opened' >&2
  exit 1
fi

jq --arg start_time "$start_time" --arg end_time "$end_time" '
  map(select(.uid == "standup")
    | .start_time = $start_time
    | .end_time = $end_time
    | .conference_uri = "https://meet.example.test/standup")
' "$FIXTURES/events.json" >"$TMP/fixtures/events.json"
: >"$CHRONCAL_OPEN_LOG"

# A symlinked state path is never followed, even to a readable file.
printf '{"hidden_calendars":[1]}\n' >"$TMP/evil-state.json"
rm -f "$TMP/state/chroncal/state.json"
ln -s "$TMP/evil-state.json" "$TMP/state/chroncal/state.json"
"$ROOT/scripts/chroncal-open-next-event-url"
for _ in $(seq 1 50); do
  grep -qx 'https://meet.example.test/standup' "$CHRONCAL_OPEN_LOG" && break
  sleep 0.02
done
grep -qx 'https://meet.example.test/standup' "$CHRONCAL_OPEN_LOG"
rm "$TMP/state/chroncal/state.json"
: >"$CHRONCAL_OPEN_LOG"

# A FIFO at the state path cannot block the read or hide the next event.
mkfifo "$TMP/state/chroncal/state.json"
printf '{"hidden_calendars":[1]}\n' >"$TMP/state/chroncal/state.json" &
fifo_writer=$!
timeout 3 "$ROOT/scripts/chroncal-open-next-event-url"
kill "$fifo_writer" 2>/dev/null || true
wait "$fifo_writer" 2>/dev/null || true
for _ in $(seq 1 50); do
  grep -qx 'https://meet.example.test/standup' "$CHRONCAL_OPEN_LOG" && break
  sleep 0.02
done
grep -qx 'https://meet.example.test/standup' "$CHRONCAL_OPEN_LOG"
rm "$TMP/state/chroncal/state.json"
: >"$CHRONCAL_OPEN_LOG"

# An oversized state replacement is read through a bounded descriptor.
{ printf '{"hidden_calendars":[1],"pad":"'; head -c 2097152 /dev/zero | tr '\0' 'a'; } \
  >"$TMP/state/chroncal/state.json"
"$ROOT/scripts/chroncal-open-next-event-url"
for _ in $(seq 1 50); do
  grep -qx 'https://meet.example.test/standup' "$CHRONCAL_OPEN_LOG" && break
  sleep 0.02
done
grep -qx 'https://meet.example.test/standup' "$CHRONCAL_OPEN_LOG"

printf 'next event URL tests: ok\n'
