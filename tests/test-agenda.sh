#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
FIXTURES="$ROOT/tests/fixtures"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/state/chroncal"
cp "$FIXTURES/state/chroncal/state.json" "$TMP/state/chroncal/state.json"

export TZ=UTC
export CHRONCAL_BIN="$ROOT/tests/fakes/chroncal"
export CHRONCAL_FAKE_FIXTURES="$FIXTURES"
export CHRONCAL_FAKE_LOG="$TMP/chroncal.log"
export CHRONCAL_BAR_NOW="2026-08-15T12:00:00Z"
export XDG_STATE_HOME="$TMP/state"

output=$("$ROOT/scripts/chroncal-bar-agenda" --days 2)

jq -e '
  .status == "ok"
  and .range == {from:"2026-08-15", to:"2026-08-16"}
  and (.events | map(.title)) == ["Standup", "Pairing", "Personal", "Release day"]
  and .next.title == "Standup"
  and .next.calendar_color == "#ff3366"
  and .next.conference_url == "https://meet.example.test/standup"
  and .next.location == "Rua Exemplo 10, Curitiba"
  and (.next.attendees | map(.email)) == ["alice@example.test", "bob@example.test"]
  and (.next.attendees | map(.organizer)) == [false, false]
  and (.events[1].class == "PRIVATE")
  and (.events[2].recurrence_id == "2026-08-15T14:00:00Z")
  and (.events[2].calendar_color == "#888888")
  and (.events[3].all_day == true)
  and (.events[2].recurrence_rule == "FREQ=WEEKLY;BYDAY=SA")
  and (.calendars | map(select(.hidden == true).id)) == [2]
' <<<"$output" >/dev/null

grep -Fx 'event list --from 2026-08-15 --to 2026-08-16 --output json' "$TMP/chroncal.log" >/dev/null
grep -Fx 'calendar list --output json' "$TMP/chroncal.log" >/dev/null

bar_output=$("$ROOT/scripts/chroncal-next-event")
jq -e '
  .class == ["in-progress", "overlap"]
  and (.text | contains("Standup"))
  and (.text | contains("Pairing"))
  and (.tooltip | contains("Personal"))
' <<<"$bar_output" >/dev/null

# A compromised calendar color cannot break out of the pango font attribute.
mkdir -p "$TMP/fixtures-evil"
cp "$FIXTURES/events.json" "$TMP/fixtures-evil/events.json"
jq 'map(.color = "#888\"><script>alert(1)</script>")' "$FIXTURES/calendars.json" \
  > "$TMP/fixtures-evil/calendars.json"
evil_output=$(CHRONCAL_FAKE_FIXTURES="$TMP/fixtures-evil" "$ROOT/scripts/chroncal-next-event")
if grep -q '<script>' <<<"$evil_output"; then
  echo 'calendar color injected unescaped markup' >&2
  exit 1
fi
grep -q '&lt;script&gt;' <<<"$evil_output"

CHRONCAL_FAKE_FAIL=1 "$ROOT/scripts/chroncal-bar-agenda" --days 2   | jq -e '.status == "unavailable" and .events == [] and .next == null' >/dev/null

# An oversized backend response is rejected as unavailable, never buffered whole.
CHRONCAL_FAKE_HUGE=1 timeout 30 "$ROOT/scripts/chroncal-bar-agenda" --days 2 \
  | jq -e '.status == "unavailable" and .events == []' >/dev/null

# A symlinked state path is never followed, even to a readable file.
printf '{"hidden_calendars":[7]}\n' > "$TMP/evil-state.json"
rm -f "$TMP/state/chroncal/state.json"
ln -s "$TMP/evil-state.json" "$TMP/state/chroncal/state.json"
output=$("$ROOT/scripts/chroncal-bar-agenda" --days 2)
jq -e '.status == "ok" and (.calendars | map(select(.hidden == true).id)) == []' <<<"$output" >/dev/null
rm "$TMP/state/chroncal/state.json"

# A FIFO at the state path cannot block the read or inject hidden IDs.
mkfifo "$TMP/state/chroncal/state.json"
printf '{"hidden_calendars":[1]}\n' >"$TMP/state/chroncal/state.json" &
fifo_writer=$!
output=$(timeout 3 "$ROOT/scripts/chroncal-bar-agenda" --days 2)
kill "$fifo_writer" 2>/dev/null || true
wait "$fifo_writer" 2>/dev/null || true
jq -e '.status == "ok" and (.calendars | map(select(.hidden == true).id)) == []' \
  <<<"$output" >/dev/null
rm "$TMP/state/chroncal/state.json"

# An oversized state replacement is read through a bounded descriptor.
{ printf '{"hidden_calendars":[2],"pad":"'; head -c 2097152 /dev/zero | tr '\0' 'a'; } \
  > "$TMP/state/chroncal/state.json"
output=$("$ROOT/scripts/chroncal-bar-agenda" --days 2)
jq -e '.status == "ok" and (.calendars | map(select(.hidden == true).id)) == []' <<<"$output" >/dev/null

# chroncal-exec enforces the producer-side stdout ceiling and reports failure.
if CHRONCAL_BIN="$ROOT/tests/fakes/chroncal" CHRONCAL_FAKE_HUGE=1 \
    timeout 30 "$ROOT/scripts/chroncal-exec" event list --output json \
    > "$TMP/exec-out.json"; then
  echo 'chroncal-exec accepted oversized output' >&2
  exit 1
fi
exec_bytes=$(wc -c < "$TMP/exec-out.json")
(( exec_bytes > 0 && exec_bytes <= 8 * 1024 * 1024 )) || {
  echo 'chroncal-exec stdout cap violated' >&2
  exit 1
}

# Normal passthrough through chroncal-exec still succeeds.
CHRONCAL_BIN="$ROOT/tests/fakes/chroncal" "$ROOT/scripts/chroncal-exec" calendar list --output json \
  | jq -e 'length >= 0' >/dev/null
 
 printf 'agenda adapter tests: ok\n'
