# Event Date Selector Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the event editor’s ISO text date field with a locale-labeled trigger and in-panel month grid, then publish Chroncal Bar 1.1.10.

**Architecture:** Keep `dateValue` as `YYYY-MM-DD`. Add tested calendar helpers on `Model.js`. Render a `DatePicker` that opens a Qt Quick Controls `Popup` (Omarchy Dropdown host) with a compact month grid. EventEditor gives DATE a full-width row and closes the picker on Esc before canceling the form. Release as patch 1.1.10, deploy, then synchronize recovery.

**Tech Stack:** QML, Qt 6, Omarchy `PanelActionButton` / popup tokens, Bun model tests, shell integration tests.

---

### Task 1: Date-grid model helpers

**Files:**
- Modify: `Model.js`
- Modify: `tests/test-model.js`

**Step 1: Add helpers after `dateInputValue`**

```javascript
function parseDateInput(value) {
  var match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(String(value || ""));
  if (!match) return null;
  var year = Number(match[1]);
  var month = Number(match[2]) - 1;
  var day = Number(match[3]);
  var date = new Date(year, month, day);
  if (date.getFullYear() !== year || date.getMonth() !== month || date.getDate() !== day) return null;
  return date;
}

function formatDateInput(date) {
  if (!date || isNaN(date.getTime())) return "";
  return date.getFullYear() + "-" + pad2(date.getMonth() + 1) + "-" + pad2(date.getDate());
}

function stepMonth(year, month, delta) {
  var target = new Date(Number(year), Number(month) + Number(delta), 1);
  return { year: target.getFullYear(), month: target.getMonth() };
}

function shiftDateInput(value, days) {
  var date = parseDateInput(value);
  if (!date) return "";
  date.setDate(date.getDate() + Number(days));
  return formatDateInput(date);
}

function weekdayOrder(weekStart) {
  var start = ((Number(weekStart) % 7) + 7) % 7;
  var days = [];
  for (var index = 0; index < 7; index += 1) days.push((start + index) % 7);
  return days;
}

function monthGrid(year, month, weekStart, todayKey, selectedKey) {
  var start = ((Number(weekStart) % 7) + 7) % 7;
  var leading = (new Date(year, month, 1).getDay() - start + 7) % 7;
  var cursor = new Date(year, month, 1 - leading);
  var weeks = [];
  for (var week = 0; week < 6; week += 1) {
    var days = [];
    for (var index = 0; index < 7; index += 1) {
      var key = formatDateInput(cursor);
      days.push({
        key: key,
        day: cursor.getDate(),
        inMonth: cursor.getMonth() === month && cursor.getFullYear() === year,
        today: key === String(todayKey || ""),
        selected: key === String(selectedKey || "")
      });
      cursor.setDate(cursor.getDate() + 1);
    }
    weeks.push(days);
  }
  return weeks;
}
```

`parseDateInput` must not use `new Date("YYYY-MM-DD")` (that is UTC midnight).

**Step 2: Tests**

Cover: valid/invalid ISO; `2026-08-18` stays 18 August local; `2026-02-29` rejected; Monday-start August 2026 grid starts on 2026-07-27; `stepMonth(2026, 11, 1)` is January 2027; `shiftDateInput("2026-08-31", 1)` is `2026-09-01`.

**Step 3: Validate and commit**

```bash
TZ=UTC bun tests/test-model.js
git add Model.js tests/test-model.js
git commit -m "feat(events): add calendar date-grid helpers"
```

---

### Task 2: DatePicker and editor wiring

**Files:**
- Create: `components/DatePicker.qml`
- Modify: `components/EventEditor.qml`

**Step 1: DatePicker**

Trigger: formatted `Qt.formatDate` label, Dropdown chevron, FormField chrome, `enabled` gates opening.

Popup: month label + `󰅁`/`󰅂` `PanelActionButton`s; weekday headers from `Model.weekdayOrder(weekStart)` and `Qt.locale().dayName`; 6×7 cells from `Model.monthGrid`. Today: hairline outline. Selected: filled. Keyboard highlight: hover fill. Click or Enter writes `YYYY-MM-DD` and closes.

`weekStart` defaults to `Qt.locale().firstDayOfWeek`. Esc on the popup closes it. Expose `opened`, `close()`, `commitIfOpen()`.

**Step 2: EventEditor**

DATE full width. TIME + DURATION on the next row when not all-day. Esc: picker first, then `canceled()`. Ctrl+Enter calls `commitIfOpen()` then `submit()`. Timezone lock uses `enabled: root.canEditTime`.

**Step 3: Validate and commit**

```bash
TZ=UTC bun tests/test-model.js
tests/test-agenda.sh
tests/test-open-url.sh
bash -n scripts/chroncal-exec scripts/chroncal-bar-agenda scripts/chroncal-next-event scripts/chroncal-open-next-event-url
omarchy plugin validate .
/usr/lib/qt6/bin/qmllint -I /usr/share/omarchy/shell BarWidget.qml Panel.qml components/*.qml
git diff --check
```

Standalone qmllint import warnings are baseline. Commit:

```bash
git commit -m "feat(events): pick event dates from a month grid"
```

---

### Task 3: Publish 1.1.10, deploy, recover

**Files:**
- Modify: `manifest.json` via Python version replace only
- Live: `~/.config/omarchy/plugins/douglasdemoura.chroncal-bar`
- Recovery: `../config/config/omarchy/plugins/douglasdemoura.chroncal-bar/`

Bump to 1.1.9→1.1.10, revalidate, commit `chore(release): bump Chroncal Bar to 1.1.10`, fast-forward main, tag `v1.1.10`, pull live, `omarchy-restart-shell`, live-check create/edit date picker, rsync recovery excluding `.git`/`.worktrees`, commit `feat(omarchy): add Chroncal date selector`.
