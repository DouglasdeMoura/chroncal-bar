# TUI Shortcut Parity Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make Chroncal Bar keyboard shortcuts match Chroncal's TUI for every shared action, keep Join/Copy/Open Chroncal on unused letters, and publish 1.1.17.

**Architecture:** Add a tested previous/next-day selection helper on `Model.js`. Rewire `Panel.qml` `PanelKeyCatcher` handlers so `h/l` jump days, `e`/`x` work from the list, and letter actions follow the TUI map. Update `EventEditor` save, help, README, and tooltips. Omarchy `PanelKeyCatcher` already owns `h j k l`, arrows, Enter, Space, `x`, Tab, and Esc; do not rebind those letters.

**Tech Stack:** Qt 6 QML, Omarchy `PanelKeyCatcher` / `Shortcut`, JavaScript model tests with Bun, Bash adapter tests.

---

### Task 1: Previous/next-day selection helper

**Files:**
- Modify: `tests/test-model.js`
- Modify: `Model.js`

**Step 1: Add failing tests after the `firstEventIndexForDate` assertions**

```js
const dayEvents = [
  { id: 10, start_time: "2026-08-16T09:00:00Z" },
  { id: 11, start_time: "2026-08-16T15:00:00Z" },
  { id: 12, start_time: "2026-08-17T08:00:00Z" },
  { id: 13, start_time: "2026-08-19T10:00:00Z" }
];
assert.equal(model.eventDateKey(dayEvents[0]), "2026-08-16");
assert.equal(model.firstEventIndexForDay(dayEvents, "2026-08-17"), 2);
assert.equal(model.firstEventIndexForDay(dayEvents, "2026-08-18"), -1);
assert.equal(model.adjacentDayFirstEventIndex(dayEvents, 0, 1), 2);
assert.equal(model.adjacentDayFirstEventIndex(dayEvents, 1, 1), 2);
assert.equal(model.adjacentDayFirstEventIndex(dayEvents, 2, 1), 3);
assert.equal(model.adjacentDayFirstEventIndex(dayEvents, 3, 1), -1);
assert.equal(model.adjacentDayFirstEventIndex(dayEvents, 3, -1), 2);
assert.equal(model.adjacentDayFirstEventIndex(dayEvents, 2, -1), 0);
assert.equal(model.adjacentDayFirstEventIndex(dayEvents, 0, -1), -1);
assert.equal(model.adjacentDayFirstEventIndex([], 0, 1), -1);
```

**Step 2: Run tests and verify RED**

Run: `TZ=UTC bun tests/test-model.js`

Expected: failure because `eventDateKey` / `firstEventIndexForDay` / `adjacentDayFirstEventIndex` do not exist.

**Step 3: Add helpers after `firstEventIndexForDate`**

```javascript
function eventDateKey(event) {
  var start = parseDate(event && event.start_time);
  return start ? dateKey(start) : "";
}

function firstEventIndexForDay(events, dayKey) {
  var key = String(dayKey || "");
  if (key === "") return -1;
  for (var index = 0; index < (events || []).length; index += 1) {
    if (eventDateKey(events[index]) === key) return index;
  }
  return -1;
}

function adjacentDayFirstEventIndex(events, currentIndex, direction) {
  var list = events || [];
  if (list.length === 0 || direction === 0) return -1;
  var current = currentIndex >= 0 && currentIndex < list.length ? list[currentIndex] : null;
  var currentKey = eventDateKey(current);
  var targetKey = "";
  for (var index = 0; index < list.length; index += 1) {
    var key = eventDateKey(list[index]);
    if (key === "") continue;
    if (direction > 0) {
      if ((currentKey === "" || key > currentKey) && (targetKey === "" || key < targetKey)) targetKey = key;
    } else if (currentKey !== "" && key < currentKey && (targetKey === "" || key > targetKey)) {
      targetKey = key;
    }
  }
  return firstEventIndexForDay(list, targetKey);
}
```

**Step 4: Run tests and verify GREEN**

Run: `TZ=UTC bun tests/test-model.js`

Expected: pass.

**Step 5: Commit**

```bash
git add tests/test-model.js Model.js
git commit -m "$(cat <<'EOF'
feat(agenda): jump selection to the next day's first event

Add helpers so h/l can move to the first event of the previous or
next day that has events.
EOF
)"
```

Skip formatters, linters, and project-wide suites. Main validates later.

---

### Task 2: Rewire panel key handlers

**Files:**
- Modify: `Panel.qml`

**Step 1: Add focused-event and day-jump helpers after `moveSelection`**

```qml
  function focusedEvent() {
    if (selectedEvent) return selectedEvent
    if (showingSettings || showingHelp || showingEditor) return null
    var current = selectedEventIndex()
    if (current < 0) return null
    return visibleEvents[current]
  }

  function moveSelectionByDay(direction) {
    if (showingDetails || showingSettings || showingEditor || showingHelp || visibleEvents.length === 0) return
    var index = Model.adjacentDayFirstEventIndex(visibleEvents, selectedEventIndex(), direction)
    if (index >= 0) selectedEventKey = Model.eventKey(visibleEvents[index])
  }
```

Add `property var pendingDeleteEvent: null` near the other panel state properties.

**Step 2: Route close, edit, and delete through the focused event**

Replace `startEdit`'s first guard so it uses `focusedEvent()`:

```qml
  function startEdit() {
    var event = focusedEvent()
    if (!event || !Model.canEditEvent(event) || showingSettings || showingHelp) return
    if (mutationBusy || editLoadBusy) return
    var direct = Model.canMutateEvent(event)
    var lookupArgs = direct ? [] : Model.seriesMasterLookupArgs(event)
    if (!direct && lookupArgs.length === 0) return
```

Keep the rest of `startEdit`, substituting `event` for `selectedEvent` in lookup/open paths. Do not set `selectedEvent` when editing from the list.

Replace `requestDelete` / `confirmDelete`:

```qml
  function requestDelete() {
    var event = focusedEvent()
    if (!event || mutationBusy || editLoadBusy || !Model.canDeleteEvent(event) || showingSettings || showingHelp || showingEditor) return
    pendingDeleteEvent = event
    deleteConfirm.recurring = Model.isRecurringEvent(event)
    deleteConfirm.selectedIndex = 0
    deleteConfirm.opened = true
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function confirmDelete(scope) {
    deleteConfirm.opened = false
    var event = pendingDeleteEvent || selectedEvent
    pendingDeleteEvent = null
    if (!event) return
    var options = {}
    if (scope === "this") options.thisEvent = true
    if (scope === "following") options.following = true
    if (scope === "series") options.series = true
    var args = Model.eventDeleteArgs(event, options)
    if (args.length === 0) return
    var kind = scope === "series" ? "delete-series" : (scope === "following" ? "delete-following" : (scope === "this" ? "delete-this" : "delete"))
    runMutation(args, kind)
  }
```

Extract the current `onCloseRequested` body into `handleClose()` and also clear `pendingDeleteEvent` when dismissing the confirm.

Point `DeleteConfirm` `title` at `pendingDeleteEvent || selectedEvent`, and `onCanceled` at:

```qml
onCanceled: {
  opened = false
  root.pendingDeleteEvent = null
}
```

**Step 3: Replace PanelKeyCatcher handlers**

```qml
      onMoveRequested: function(dx, dy) {
        if (deleteConfirm.opened) {
          if (dx !== 0) deleteConfirm.cycle(dx)
          else if (dy !== 0) deleteConfirm.cycle(dy)
          return
        }
        if (root.showingDetails || root.showingSettings || root.showingEditor || root.showingHelp) return
        if (dy !== 0) root.moveSelection(dy)
        else if (dx !== 0) root.moveSelectionByDay(dx)
      }
      onCloseRequested: root.handleClose()
      onActivateRequested: {
        if (deleteConfirm.opened) deleteConfirm.activate()
        else if (!root.showingDetails && !root.showingSettings && !root.showingEditor && !root.showingHelp) root.activateSelection()
      }
      onTabRequested: function(direction) {
        if (deleteConfirm.opened) deleteConfirm.cycle(direction)
        else root.switchPanel(direction)
      }
      onDeleteRequested: root.requestDelete()
      onTextKey: function(text) {
        if (deleteConfirm.opened) {
          if (text === "q") root.handleClose()
          return
        }
        if (text === "q") root.handleClose()
        else if (text === "?") root.toggleHelp()
        else if (root.showingHelp) return
        else if (text === "s" || text === "S") root.refresh()
        else if (text === "/") root.beginSearch()
        else if (text === "," || text === "C") root.toggleSettings()
        else if (text === "c") root.startCreate()
        else if (!root.showingDetails && !root.showingSettings && !root.showingEditor && (text === "t" || text === "T")) root.selectToday()
        else if (!root.showingSettings && !root.showingEditor && (text === "e" || text === "E")) root.startEdit()
        else if (root.showingDetails && (text === "v" || text === "V")) root.joinEvent()
        else if (root.showingDetails && (text === "p" || text === "P")) root.copyEventDetails()
        else if (root.showingDetails && (text === "g" || text === "G")) root.openChroncal()
      }
```

Do **not** attach a second `Keys.onPressed` on `PanelKeyCatcher` (that can replace the component handler). Add a sibling `Shortcut` instead:

```qml
    Shortcut {
      sequence: "Delete"
      enabled: root.opened && !keyCatcher.blocked
      onActivated: root.requestDelete()
    }
```

Remove bindings for `n`, `p`/`b` (navigation), `N` (create), `r`/`R` (refresh), `d`/`D` (delete), `j`/`J` (join), and `o`/`O` (open Chroncal).

`handleClose()` must match today's close order: confirm, editor, subview, search, then panel close. When closing the confirm, set `pendingDeleteEvent = null`.

**Step 4: Confirm QML still balances**

Count `{` vs `}` in `Panel.qml`. Search for leftover `text === "N"`, `text === "n"`, `text === "r"`, `joinEvent` on `"j"`, and `copyEventDetails` on `"c"`.

**Step 5: Commit**

```bash
git add Panel.qml
git commit -m "$(cat <<'EOF'
feat(agenda): use Chroncal TUI keys in the panel

Create, edit, delete, refresh, settings, and day jumps follow the
TUI. Join, copy, and Open Chroncal move to v, p, and g.
EOF
)"
```

Skip formatters, linters, and project-wide suites.

---

### Task 3: Help, README, tooltips, and Ctrl+S

**Files:**
- Modify: `components/ShortcutHelp.qml`
- Modify: `README.md`
- Modify: `components/EventEditor.qml`
- Modify: `components/EventDetails.qml`
- Modify: `Panel.qml` (header tooltips only)

**Step 1: Replace ShortcutHelp entries**

```qml
  readonly property var entries: [
    { keys: "↑ / ↓   j / k", action: "Move selection" },
    { keys: "← / →   h / l", action: "Previous or next day" },
    { keys: "t", action: "Jump to today" },
    { keys: "Enter / Space", action: "Open selected event" },
    { keys: "/", action: "Open search" },
    { keys: "c", action: "Create event" },
    { keys: "e", action: "Edit event or recurring series" },
    { keys: "x / Delete", action: "Delete this event, this and following, or all events" },
    { keys: "v", action: "Join or open event link" },
    { keys: "p", action: "Copy event details" },
    { keys: "g", action: "Open Chroncal" },
    { keys: "s", action: "Refresh agenda" },
    { keys: "C / ,", action: "Calendar settings" },
    { keys: "?", action: "Open shortcut help" },
    { keys: "Ctrl+S", action: "Save event or series" },
    { keys: "Esc / q", action: "Back or close" }
  ]
```

**Step 2: Replace the README shortcut table**

```markdown
| Key | Context | Action |
| --- | --- | --- |
| `↑` / `↓`, `j` / `k` | Agenda | Move selection |
| `←` / `→`, `h` / `l` | Agenda | Previous or next day |
| `t` | Agenda | Jump to today's first event |
| `Enter` / `Space` | Agenda | Open selected event |
| `/` | Agenda | Open search |
| `c` | Agenda or details | Create event |
| `e` | Agenda or details | Edit event or recurring series |
| `x` or `Delete` | Agenda or details | Delete this event, this and following, or all events |
| `v` | Event details | Join or open event URL |
| `p` | Event details | Copy event details |
| `g` | Event details | Open Chroncal |
| `s` | Agenda | Refresh |
| `C` or `,` | Agenda | Open settings |
| `?` | Agenda | Open shortcut help |
| `Ctrl+S` | Event editor | Save event or series |
| `Esc` or `q` | Any panel view | Back, cancel, or close |
```

**Step 3: Update tooltips**

- Create header button: `Create event (c)`
- Refresh header button: keep `Refresh agenda` (optional `(s)`)
- Join: `Join or open event link (v)`
- Copy: `Copy event details (p)`
- Open Chroncal: `Open Chroncal (g)`
- Edit: keep current edit wording
- Delete: keep current delete wording

**Step 4: Add Ctrl+S in EventEditor**

In `Keys.onPressed`, keep Ctrl+Enter and add:

```qml
    } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_S) {
      datePicker.commitIfOpen()
      root.submit()
      event.accepted = true
```

**Step 5: Commit**

```bash
git add components/ShortcutHelp.qml README.md components/EventEditor.qml components/EventDetails.qml Panel.qml
git commit -m "$(cat <<'EOF'
docs(ui): document Chroncal TUI-matching shortcuts

Help, README, and tooltips follow the TUI keymap. The editor saves
with Ctrl+S as well as Ctrl+Enter.
EOF
)"
```

Skip formatters, linters, and project-wide suites.

---

### Task 4: Release metadata

**Files:**
- Modify: `manifest.json`

**Step 1: Bump the plugin version with Python, not Write/StrReplace**

`Write`/`StrReplace` on `manifest.json` can inject a hashline prefix. Restore with checkout if that happens.

```bash
python3 - <<'PY'
from pathlib import Path
p = Path("manifest.json")
text = p.read_text()
assert not text.startswith("[")
assert '"version": "1.1.16"' in text
p.write_text(text.replace('"version": "1.1.16"', '"version": "1.1.17"', 1))
PY
```

**Step 2: Commit**

```bash
git add manifest.json
git commit -m "chore(release): bump Chroncal Bar to 1.1.17"
```

Skip formatters, linters, and project-wide suites. Main runs `TZ=UTC bun tests/test-model.js`, adapter scripts, `bash -n`, `qmllint`, `omarchy plugin validate .`, and `git diff --check` before merge.
