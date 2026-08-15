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
  and (.events[1].class == "PRIVATE")
  and (.events[2].recurrence_id == "2026-08-15T14:00:00Z")
  and (.events[2].calendar_color == "#888888")
  and (.events[3].all_day == true)
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

CHRONCAL_FAKE_FAIL=1 "$ROOT/scripts/chroncal-bar-agenda" --days 2   | jq -e '.status == "unavailable" and .events == [] and .next == null' >/dev/null

printf 'agenda adapter tests: ok\n'
