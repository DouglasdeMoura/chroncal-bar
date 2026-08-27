#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
HELPER="$ROOT/scripts/chroncal-read-regular"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

[[ -x $HELPER ]]

# A regular file is copied through the helper.
printf '{"hidden_calendars":[2]}\n' >"$TMP/state.json"
"$HELPER" "$TMP/state.json" 1024 >"$TMP/out"
diff -q "$TMP/state.json" "$TMP/out" >/dev/null

# An oversized regular file is truncated at the byte cap.
{ printf '{"hidden_calendars":[2],"pad":"'; head -c 4096 /dev/zero | tr '\0' 'a'; printf '"}\n'; } \
  >"$TMP/big.json"
"$HELPER" "$TMP/big.json" 64 >"$TMP/out"
bytes=$(wc -c <"$TMP/out")
(( bytes == 64 )) || { echo "expected 64-byte cap, got $bytes" >&2; exit 1; }

# A symlink is not followed, even to a readable regular file.
printf '{"hidden_calendars":[7]}\n' >"$TMP/evil.json"
ln -s "$TMP/evil.json" "$TMP/link.json"
set +e
timeout 2 "$HELPER" "$TMP/link.json" 1024 >"$TMP/out"
status=$?
set -e
(( status != 0 )) || { echo 'symlink open succeeded' >&2; exit 1; }
if grep -q hidden_calendars "$TMP/out"; then
  echo 'symlink target was read' >&2
  exit 1
fi

# A FIFO at the path cannot block the open or inject writer JSON.
mkfifo "$TMP/fifo.json"
printf '{"hidden_calendars":[2]}\n' >"$TMP/fifo.json" &
writer=$!
for _ in $(seq 1 50); do
  kill -0 "$writer" 2>/dev/null || break
  sleep 0.02
done
set +e
timeout 2 "$HELPER" "$TMP/fifo.json" 1024 >"$TMP/out"
status=$?
set -e
kill "$writer" 2>/dev/null || true
wait "$writer" 2>/dev/null || true
(( status != 0 && status != 124 )) || {
  echo "FIFO open blocked or succeeded (status=$status)" >&2
  exit 1
}
if grep -q hidden_calendars "$TMP/out"; then
  echo 'FIFO writer content was read' >&2
  exit 1
fi

# A directory is refused.
set +e
timeout 2 "$HELPER" "$TMP" 1024 >"$TMP/out"
status=$?
set -e
(( status != 0 )) || { echo 'directory open succeeded' >&2; exit 1; }

printf 'read-regular helper tests: ok\n'
