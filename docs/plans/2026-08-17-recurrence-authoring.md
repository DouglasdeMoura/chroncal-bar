# Recurrence Authoring Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Let Chroncal Bar create and edit RFC 5545 recurrence rules in the event editor using Chroncal’s Repeat presets and inline Custom fields.

**Architecture:** `Model.js` owns parse/build/validate/summary and mutation flags. `EventEditor.qml` renders Repeat, Ends, and Custom controls and passes a `recurrence` object through the existing `values()` → `eventMutationArgs` path. Overrides never send `--recurrence-rule`. Panel mutation wiring stays unchanged.

**Tech Stack:** Qt 6 QML, Omarchy `Dropdown` / `NumberField` / `Button` / `DatePicker`, JavaScript model tests with Bun (`TZ=UTC bun tests/test-model.js`).

**Constraints:** Work only in this worktree. Skip formatters, linters, and project-wide suites; Main validates later. Do not bump `manifest.json` or tag a release. Do not commit on `main`.

---

### Task 1: Recurrence form helpers

**Files:**
- Modify: `tests/test-model.js`
- Modify: `Model.js`

**Step 1: Write failing tests**

Append to `tests/test-model.js` (keep existing tests):

```js
const recurrenceStart = "2026-08-19"; // Wednesday
assert.deepEqual(model.repeatPresetOptions().map(option => option.label), [
  "None", "Every day", "Every week", "Every 2 weeks", "Every month", "Every year", "Weekdays", "Custom..."
]);

const emptyRecurrence = model.defaultRecurrenceForm(recurrenceStart);
assert.equal(emptyRecurrence.preset, "none");
assert.equal(emptyRecurrence.freq, "WEEKLY");
assert.equal(emptyRecurrence.interval, 1);
assert.deepEqual(emptyRecurrence.weekDays, [false, false, false, true, false, false, false]);
assert.equal(emptyRecurrence.monthlyMode, "date");
assert.equal(emptyRecurrence.ends, "never");
assert.equal(emptyRecurrence.until, "2026-11-19");
assert.equal(model.buildRecurrenceRule(emptyRecurrence, recurrenceStart), "");

assert.equal(model.parseRecurrenceRule("FREQ=DAILY", recurrenceStart).preset, "daily");
assert.equal(model.parseRecurrenceRule("FREQ=WEEKLY;INTERVAL=2", recurrenceStart).preset, "biweekly");
assert.equal(model.parseRecurrenceRule("FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR", recurrenceStart).preset, "weekdays");
assert.equal(model.parseRecurrenceRule("FREQ=DAILY;COUNT=10", recurrenceStart).preset, "daily");
assert.equal(model.parseRecurrenceRule("FREQ=DAILY;COUNT=10", recurrenceStart).ends, "after");
assert.equal(model.parseRecurrenceRule("FREQ=DAILY;COUNT=10", recurrenceStart).count, 10);
assert.equal(model.buildRecurrenceRule(model.parseRecurrenceRule("FREQ=DAILY;COUNT=10", recurrenceStart), recurrenceStart), "FREQ=DAILY;COUNT=10");

const untilForm = model.parseRecurrenceRule("FREQ=WEEKLY;UNTIL=20261116T235959Z", recurrenceStart);
assert.equal(untilForm.preset, "weekly");
assert.equal(untilForm.ends, "ondate");
assert.equal(untilForm.until, "2026-11-16");
assert.equal(model.formatRRuleUntil("2026-11-16"), "20261116T235959Z");
assert.equal(model.buildRecurrenceRule(untilForm, recurrenceStart), "FREQ=WEEKLY;UNTIL=20261116T235959Z");

const customWeekly = model.parseRecurrenceRule("FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE", recurrenceStart);
assert.equal(customWeekly.preset, "custom");
assert.equal(customWeekly.freq, "WEEKLY");
assert.equal(customWeekly.interval, 2);
assert.deepEqual(customWeekly.weekDays, [false, true, false, true, false, false, false]);
assert.equal(model.buildRecurrenceRule(customWeekly, recurrenceStart), "FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE");

const customMonthly = model.parseRecurrenceRule("FREQ=MONTHLY;BYDAY=3WE", recurrenceStart);
assert.equal(customMonthly.preset, "custom");
assert.equal(customMonthly.monthlyMode, "nth");
assert.equal(model.buildRecurrenceRule(customMonthly, recurrenceStart), "FREQ=MONTHLY;BYDAY=3WE");

assert.equal(model.buildRecurrenceRule({
  preset: "custom",
  freq: "MONTHLY",
  interval: 1,
  monthlyMode: "date",
  ends: "never",
  weekDays: model.defaultRecurrenceForm(recurrenceStart).weekDays
}, recurrenceStart), "FREQ=MONTHLY");

const seededCustom = model.applyRepeatPreset(model.parseRecurrenceRule("FREQ=WEEKLY", recurrenceStart), "custom", recurrenceStart);
assert.equal(seededCustom.preset, "custom");
assert.equal(seededCustom.freq, "WEEKLY");
assert.equal(model.buildRecurrenceRule(seededCustom, recurrenceStart), "FREQ=WEEKLY;BYDAY=WE");

assert.deepEqual(model.validateRecurrenceForm(model.defaultRecurrenceForm(recurrenceStart), recurrenceStart), []);
assert.match(model.validateRecurrenceForm({
  ...model.defaultRecurrenceForm(recurrenceStart),
  preset: "custom",
  interval: 0
}, recurrenceStart)[0], /interval/i);
assert.match(model.validateRecurrenceForm({
  ...model.parseRecurrenceRule("FREQ=DAILY", recurrenceStart),
  ends: "after",
  count: 0
}, recurrenceStart)[0], /count|times/i);
assert.match(model.validateRecurrenceForm({
  ...model.parseRecurrenceRule("FREQ=DAILY", recurrenceStart),
  ends: "ondate",
  until: "2026-08-18"
}, recurrenceStart)[0], /end date/i);

assert.match(model.recurrenceRuleSummary(model.parseRecurrenceRule("FREQ=WEEKLY;BYDAY=MO,WE", recurrenceStart), recurrenceStart), /Weekly on Mo, We/);
assert.equal(model.recurrenceRuleSummary(model.parseRecurrenceRule("FREQ=DAILY", recurrenceStart), recurrenceStart), "Every day");
```

**Step 2: Run tests and verify RED**

```bash
TZ=UTC bun tests/test-model.js
```

Expected: FAIL because the helpers do not exist.

**Step 3: Implement helpers in `Model.js`**

Add after `validateEventForm`:

```js
var WEEKDAY_RRULE = ["SU", "MO", "TU", "WE", "TH", "FR", "SA"];
var REPEAT_PRESET_RULES = {
  none: "",
  daily: "FREQ=DAILY",
  weekly: "FREQ=WEEKLY",
  biweekly: "FREQ=WEEKLY;INTERVAL=2",
  monthly: "FREQ=MONTHLY",
  yearly: "FREQ=YEARLY",
  weekdays: "FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR"
};

function repeatPresetOptions() {
  return [
    { value: "none", label: "None" },
    { value: "daily", label: "Every day" },
    { value: "weekly", label: "Every week" },
    { value: "biweekly", label: "Every 2 weeks" },
    { value: "monthly", label: "Every month" },
    { value: "yearly", label: "Every year" },
    { value: "weekdays", label: "Weekdays" },
    { value: "custom", label: "Custom..." }
  ];
}

function frequencyOptions() {
  return [
    { value: "DAILY", label: "Day" },
    { value: "WEEKLY", label: "Week" },
    { value: "MONTHLY", label: "Month" },
    { value: "YEARLY", label: "Year" }
  ];
}

function endsOptions() {
  return [
    { value: "never", label: "Never" },
    { value: "after", label: "After" },
    { value: "ondate", label: "On date" }
  ];
}

function emptyWeekDays() {
  return [false, false, false, false, false, false, false];
}

function addMonthsClamped(date, months) {
  var last = new Date(date.getFullYear(), date.getMonth() + months + 1, 0).getDate();
  return new Date(date.getFullYear(), date.getMonth() + months, Math.min(date.getDate(), last));
}

function defaultRecurrenceForm(startDateValue) {
  var date = parseDateInput(startDateValue) || new Date();
  var weekDays = emptyWeekDays();
  weekDays[date.getDay()] = true;
  return {
    preset: "none",
    interval: 1,
    freq: "WEEKLY",
    weekDays: weekDays,
    monthlyMode: "date",
    ends: "never",
    count: 1,
    until: formatDateInput(addMonthsClamped(date, 3))
  };
}

function cloneRecurrenceForm(form) {
  var source = form || defaultRecurrenceForm("");
  var next = {};
  for (var key in source) next[key] = source[key];
  next.weekDays = (source.weekDays || emptyWeekDays()).slice();
  return next;
}

function rruleParamMap(rule) {
  var map = {};
  var parts = String(rule || "").split(";");
  for (var i = 0; i < parts.length; i++) {
    var cut = parts[i].split("=");
    if (cut.length < 2) continue;
    map[String(cut[0] || "").toUpperCase().trim()] = cut.slice(1).join("=").trim();
  }
  return map;
}

function recurrenceBaseRule(rule) {
  var parts = String(rule || "").split(";");
  var kept = [];
  for (var i = 0; i < parts.length; i++) {
    var upper = parts[i].toUpperCase();
    if (upper.indexOf("COUNT=") === 0 || upper.indexOf("UNTIL=") === 0) continue;
    if (parts[i] !== "") kept.push(parts[i]);
  }
  return kept.join(";");
}

function formatRRuleUntil(value) {
  var date = parseDateInput(value);
  if (!date) return "";
  var end = new Date(date.getFullYear(), date.getMonth(), date.getDate(), 23, 59, 59, 0);
  return String(end.getUTCFullYear()) + pad2(end.getUTCMonth() + 1) + pad2(end.getUTCDate()) + "T" +
    pad2(end.getUTCHours()) + pad2(end.getUTCMinutes()) + pad2(end.getUTCSeconds()) + "Z";
}

function parseRRuleUntil(value) {
  var text = String(value || "");
  if (/^\d{8}T\d{6}Z$/.test(text)) {
    return parseDate(
      text.slice(0, 4) + "-" + text.slice(4, 6) + "-" + text.slice(6, 8) + "T" +
      text.slice(9, 11) + ":" + text.slice(11, 13) + ":" + text.slice(13, 15) + "Z"
    );
  }
  if (/^\d{8}$/.test(text)) {
    return parseDateInput(text.slice(0, 4) + "-" + text.slice(4, 6) + "-" + text.slice(6, 8));
  }
  return null;
}

function nthWeekdayOf(date) {
  return {
    nth: Math.floor((date.getDate() - 1) / 7) + 1,
    day: WEEKDAY_RRULE[date.getDay()]
  };
}

function nthWeekdayLabel(date) {
  var nth = nthWeekdayOf(date).nth;
  var ordinals = ["", "1st", "2nd", "3rd", "4th", "5th"];
  var ord = nth > 0 && nth < ordinals.length ? ordinals[nth] : "nth";
  var weekdays = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];
  return ord + " " + weekdays[date.getDay()];
}

function monthlyOnOptions(startDateValue) {
  var date = parseDateInput(startDateValue) || new Date();
  return [
    { value: "date", label: "Day " + date.getDate() },
    { value: "nth", label: nthWeekdayLabel(date) }
  ];
}

function parseRecurrenceRule(rule, startDateValue) {
  var form = defaultRecurrenceForm(startDateValue);
  var text = String(rule || "").trim();
  if (text === "") return form;
  var parts = rruleParamMap(text);
  var freq = String(parts.FREQ || "").toUpperCase();
  if (freq === "DAILY" || freq === "WEEKLY" || freq === "MONTHLY" || freq === "YEARLY") form.freq = freq;
  var interval = Number(parts.INTERVAL || "1");
  if (interval >= 1) form.interval = interval;
  if (parts.COUNT) {
    form.ends = "after";
    form.count = Number(parts.COUNT) || 1;
  } else if (parts.UNTIL) {
    form.ends = "ondate";
    var untilDate = parseRRuleUntil(parts.UNTIL);
    if (untilDate) form.until = formatDateInput(untilDate);
  }
  if (parts.BYDAY) {
    var days = String(parts.BYDAY).split(",");
    var weekDays = emptyWeekDays();
    var sawNth = false;
    for (var i = 0; i < days.length; i++) {
      var code = String(days[i] || "").toUpperCase().trim();
      var dayPart = code.replace(/^[+-]?\d+/, "");
      if (dayPart !== code) sawNth = true;
      for (var w = 0; w < 7; w++) if (WEEKDAY_RRULE[w] === dayPart) weekDays[w] = true;
    }
    form.weekDays = weekDays;
    if (form.freq === "MONTHLY" && sawNth) form.monthlyMode = "nth";
  }
  var base = recurrenceBaseRule(text);
  var presets = ["daily", "weekly", "biweekly", "monthly", "yearly", "weekdays"];
  for (var p = 0; p < presets.length; p++) {
    if (base.toUpperCase() === REPEAT_PRESET_RULES[presets[p]].toUpperCase()) {
      form.preset = presets[p];
      return form;
    }
  }
  form.preset = "custom";
  return form;
}

function appendRecurrenceEnds(rule, form) {
  if (String(form.ends || "never") === "after") {
    var count = Number(form.count || 0);
    if (count >= 1) return rule + ";COUNT=" + String(Math.floor(count));
  }
  if (String(form.ends || "never") === "ondate") {
    var until = formatRRuleUntil(form.until);
    if (until !== "") return rule + ";UNTIL=" + until;
  }
  return rule;
}

function buildRecurrenceRule(form, startDateValue) {
  var rec = form || defaultRecurrenceForm(startDateValue);
  var preset = String(rec.preset || "none");
  if (preset === "none") return "";
  if (preset !== "custom") {
    var presetRule = REPEAT_PRESET_RULES[preset] || "";
    return presetRule === "" ? "" : appendRecurrenceEnds(presetRule, rec);
  }
  var freq = String(rec.freq || "WEEKLY").toUpperCase();
  if (freq !== "DAILY" && freq !== "WEEKLY" && freq !== "MONTHLY" && freq !== "YEARLY") freq = "WEEKLY";
  var rule = "FREQ=" + freq;
  var interval = Number(rec.interval || 1);
  if (interval > 1) rule += ";INTERVAL=" + String(Math.floor(interval));
  if (freq === "WEEKLY") {
    var days = [];
    var weekDays = rec.weekDays || [];
    for (var i = 0; i < 7; i++) if (weekDays[i]) days.push(WEEKDAY_RRULE[i]);
    if (days.length > 0) rule += ";BYDAY=" + days.join(",");
  } else if (freq === "MONTHLY" && rec.monthlyMode === "nth") {
    var start = parseDateInput(startDateValue);
    if (start) {
      var nth = nthWeekdayOf(start);
      rule += ";BYDAY=" + String(nth.nth) + nth.day;
    }
  }
  return appendRecurrenceEnds(rule, rec);
}

function applyRepeatPreset(form, nextPreset, startDateValue) {
  var current = cloneRecurrenceForm(form || defaultRecurrenceForm(startDateValue));
  var preset = String(nextPreset || "none");
  if (preset === "custom" && current.preset !== "custom") {
    var parsed = parseRecurrenceRule(buildRecurrenceRule(current, startDateValue), startDateValue);
    parsed.preset = "custom";
    return parsed;
  }
  current.preset = preset;
  return current;
}

function validateRecurrenceForm(form, startDateValue) {
  var rec = form || defaultRecurrenceForm(startDateValue);
  var errors = [];
  if (String(rec.preset || "none") === "none") return errors;
  if (String(rec.preset) === "custom") {
    if (!(Number(rec.interval) >= 1)) errors.push("Repeat interval must be at least 1");
  }
  if (String(rec.ends) === "after" && !(Number(rec.count) >= 1)) errors.push("Ends after must be at least 1 time");
  if (String(rec.ends) === "ondate") {
    var until = parseDateInput(rec.until);
    var start = parseDateInput(startDateValue);
    if (!until) errors.push("End date must use YYYY-MM-DD");
    else if (start && until < start) errors.push("End date must be on or after the start date");
  }
  return errors;
}

function recurrenceRuleSummary(form, startDateValue) {
  var rec = form || defaultRecurrenceForm(startDateValue);
  var preset = String(rec.preset || "none");
  if (preset === "none") return "Does not repeat";
  if (preset !== "custom") {
    var options = repeatPresetOptions();
    for (var i = 0; i < options.length; i++) if (options[i].value === preset) return options[i].label;
  }
  var freqLabels = { DAILY: ["Daily", "day", "days"], WEEKLY: ["Weekly", "week", "weeks"], MONTHLY: ["Monthly", "month", "months"], YEARLY: ["Yearly", "year", "years"] };
  var freq = String(rec.freq || "WEEKLY").toUpperCase();
  var names = freqLabels[freq] || freqLabels.WEEKLY;
  var interval = Number(rec.interval || 1);
  var summary = interval === 1 ? names[0] : "Every " + String(Math.floor(interval)) + " " + names[2];
  if (freq === "WEEKLY") {
    var labels = [];
    var weekDays = rec.weekDays || [];
    var weekdayShort = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"];
    for (var d = 0; d < 7; d++) if (weekDays[d]) labels.push(weekdayShort[d]);
    if (labels.length > 0 && labels.length < 7) summary += " on " + labels.join(", ");
  }
  if (freq === "MONTHLY" && rec.monthlyMode === "nth") {
    var start = parseDateInput(startDateValue);
    if (start) summary += " on " + nthWeekdayLabel(start);
  }
  return summary;
}

function canEditRecurrence(event) {
  if (!event) return true;
  return String(event.recurrence_id || "") === "";
}
```

Copy arrays in `parseRecurrenceRule` / `defaultRecurrenceForm`. Do not reuse one `emptyWeekDays()` result across forms.

**Step 4: Run tests and verify GREEN**

```bash
TZ=UTC bun tests/test-model.js
```

Expected: PASS.

**Step 5: Commit**

```bash
git add Model.js tests/test-model.js
git commit -m "$(cat <<'EOF'
feat(model): parse and build Chroncal recurrence rules

Add TUI Repeat presets, Custom RRULE fields, UNTIL formatting, and
validation helpers for the event editor.
EOF
)"
```

---

### Task 2: Editor values and mutation flags

**Files:**
- Modify: `tests/test-model.js`
- Modify: `Model.js` (`eventEditorValues`, `validateEventForm`, `eventMutationArgs`)

**Step 1: Write failing tests**

```js
assert.equal(model.canEditRecurrence(null), true);
assert.equal(model.canEditRecurrence({ id: 42 }), true);
assert.equal(model.canEditRecurrence({ id: 42, recurrence_rule: "FREQ=WEEKLY" }), true);
assert.equal(model.canEditRecurrence({ uid: "weekly-uid", recurrence_id: "2026-08-18T14:30:00Z" }), false);

const created = model.eventEditorValues(null, "2026-08-19T12:00:00Z");
assert.equal(created.recurrence.preset, "none");
assert.equal(model.eventEditorValues({
  ...existingEditEvent,
  timezone: "",
  recurrence_rule: "FREQ=WEEKLY;BYDAY=WE"
}, "2026-08-19T12:00:00Z").recurrence.preset, "custom");

assert.deepEqual(model.validateEventForm({
  ...createValues,
  recurrence: model.parseRecurrenceRule("FREQ=DAILY", "2026-08-18")
}), []);
assert.match(model.validateEventForm({
  ...createValues,
  recurrence: { ...model.defaultRecurrenceForm("2026-08-18"), preset: "custom", interval: 0 }
})[0], /interval/i);

const weeklyCreate = { ...createValues, recurrence: model.parseRecurrenceRule("FREQ=WEEKLY", "2026-08-18") };
const weeklyCreateArgs = model.eventMutationArgs("create", null, weeklyCreate);
assert.ok(weeklyCreateArgs.indexOf("--recurrence-rule") >= 0);
assert.equal(weeklyCreateArgs[weeklyCreateArgs.indexOf("--recurrence-rule") + 1], "FREQ=WEEKLY");
assert.equal(model.eventMutationArgs("create", null, createValues).indexOf("--recurrence-rule"), -1);

const seriesMaster = { ...mergedSeriesMaster, timezone: "" };
const seriesRecurrenceValues = {
  ...seriesEditValues,
  date: "2026-08-18",
  time: "14:30",
  duration: "45m",
  recurrence: model.parseRecurrenceRule("FREQ=DAILY", "2026-08-18")
};
const seriesRuleArgs = model.eventMutationArgs("edit", seriesMaster, seriesRecurrenceValues, { series: true });
assert.equal(seriesRuleArgs[seriesRuleArgs.indexOf("--recurrence-rule") + 1], "FREQ=DAILY");
assert.equal(model.eventMutationArgs("edit", seriesMaster, {
  ...seriesRecurrenceValues,
  recurrence: model.parseRecurrenceRule("FREQ=WEEKLY", "2026-08-18")
}, { series: true }).indexOf("--recurrence-rule"), -1);

const cleared = model.eventMutationArgs("edit", seriesMaster, {
  ...seriesRecurrenceValues,
  recurrence: model.defaultRecurrenceForm("2026-08-18")
}, { series: true });
assert.equal(cleared[cleared.indexOf("--recurrence-rule") + 1], "");

const overrideRecurrenceValues = {
  ...createValues,
  recurrence: model.parseRecurrenceRule("FREQ=DAILY", "2026-08-18")
};
assert.equal(model.eventMutationArgs("edit", overrideEditEvent, overrideRecurrenceValues).indexOf("--recurrence-rule"), -1);

const timezoneRecurrenceEvent = { ...existingEditEvent, recurrence_rule: "" };
assert.ok(model.eventMutationArgs("edit", timezoneRecurrenceEvent, {
  ...createValues,
  recurrence: model.parseRecurrenceRule("FREQ=WEEKLY", "2026-08-18")
}).indexOf("--recurrence-rule") >= 0);
```

Keep the existing create-args assertion unchanged: create without `recurrence` still omits `--recurrence-rule`.

**Step 2: Run tests and verify RED**

```bash
TZ=UTC bun tests/test-model.js
```

Expected: FAIL because `eventEditorValues` has no `recurrence` and mutation ignores RRULE.

**Step 3: Wire helpers**

In `eventEditorValues`, add `recurrence` to both return objects:

```js
recurrence: event
  ? parseRecurrenceRule(event.recurrence_rule, dateInputValue(event.start_time, event.all_day === true))
  : defaultRecurrenceForm(dateInputValue(nextHour, false))
```

In `validateEventForm`, after the duration check:

```js
errors = errors.concat(validateRecurrenceForm(form.recurrence, form.date));
```

In `eventMutationArgs`, after optional location/description flags on edit, and before `return args`:

```js
if (canEditRecurrence(event)) {
  var nextRule = buildRecurrenceRule(form.recurrence, form.date);
  if (String(event.recurrence_rule || "") !== nextRule) args.push("--recurrence-rule", nextRule);
}
```

On create, before `args.push("--", title)`:

```js
var createRule = buildRecurrenceRule(form.recurrence, form.date);
if (createRule !== "") args.push("--recurrence-rule", createRule);
```

Do not use `pushOptionalFlag` for `--recurrence-rule`; clearing a series must send an empty value.

Timezone rejection stays only for date/time/duration changes.

**Step 4: Run tests and verify GREEN**

```bash
TZ=UTC bun tests/test-model.js
```

Expected: PASS, including the original create-args assertion.

**Step 5: Commit**

```bash
git add Model.js tests/test-model.js
git commit -m "$(cat <<'EOF'
feat(model): send recurrence-rule on create and series edit

Preserve omitted rules, allow clearing a series with an empty flag,
and never attach RRULE to override updates.
EOF
)"
```

---

### Task 3: Repeat presets and Ends in EventEditor

**Files:**
- Modify: `components/EventEditor.qml`

**Step 1: Add recurrence state to the editor**

Add properties next to `descriptionValue`:

```qml
property string repeatPreset: "none"
property int repeatInterval: 1
property string repeatFreq: "WEEKLY"
property var repeatWeekDays: [false, false, false, false, false, false, false]
property string repeatMonthlyMode: "date"
property string repeatEnds: "never"
property int repeatCount: 1
property string repeatUntil: ""
readonly property bool canEditRecurrence: editorMode !== "edit" || !eventData || String(eventData.recurrence_id || "") === ""
readonly property bool showingRepeatEnds: repeatPreset !== "none" && repeatPreset !== "custom"
readonly property bool showingCustomRepeat: repeatPreset === "custom"
```

Extend `values()`:

```qml
recurrence: {
  preset: repeatPreset,
  interval: repeatInterval,
  freq: repeatFreq,
  weekDays: repeatWeekDays,
  monthlyMode: repeatMonthlyMode,
  ends: repeatEnds,
  count: repeatCount,
  until: repeatUntil
}
```

In `initialize()`, after `descriptionValue = initial.description`:

```qml
var rec = initial.recurrence || Model.defaultRecurrenceForm(initial.date)
repeatPreset = rec.preset
repeatInterval = rec.interval
repeatFreq = rec.freq
repeatWeekDays = rec.weekDays.slice()
repeatMonthlyMode = rec.monthlyMode
repeatEnds = rec.ends
repeatCount = rec.count
repeatUntil = rec.until
```

Add helpers:

```qml
function recurrenceForm() { return values().recurrence }

function applyRepeatPreset(value) {
  var next = Model.applyRepeatPreset(recurrenceForm(), value, root.dateValue)
  repeatPreset = next.preset
  repeatInterval = next.interval
  repeatFreq = next.freq
  repeatWeekDays = next.weekDays.slice()
  repeatMonthlyMode = next.monthlyMode
  repeatEnds = next.ends
  repeatCount = next.count
  repeatUntil = next.until
}

function closePickers() {
  datePicker.close()
  endsDatePicker.close()
  repeatDropdown.close()
  freqDropdown.close()
  endsDropdown.close()
  monthlyDropdown.close()
}
```

Update Escape / Ctrl+S / Ctrl+Enter to call `closePickers()` / `endsDatePicker.commitIfOpen()` the same way as `datePicker`. `onVisibleChanged` else-branch also closes the new pickers.

**Step 2: Render Repeat + Ends after the all-day toggle**

```qml
FieldLabel { text: "REPEAT" }
Dropdown {
  id: repeatDropdown
  width: parent.width
  showLabel: false
  value: root.repeatPreset
  options: Model.repeatPresetOptions()
  enabled: !root.busy && root.canEditRecurrence
  foreground: root.foreground
  fontFamily: root.fontFamily
  onChanged: function(value) { root.applyRepeatPreset(value) }
}

Text {
  visible: !root.canEditRecurrence
  width: parent.width
  text: "Open the series editor to change Repeat. This override keeps the series rule."
  textFormat: Text.PlainText
  color: Util.alpha(root.foreground, 0.56)
  font.family: root.fontFamily
  font.pixelSize: Style.font.caption
  wrapMode: Text.WordWrap
}

Column {
  visible: root.showingRepeatEnds
  width: parent.width
  spacing: Style.space(4)
  FieldLabel { text: "ENDS" }
  Dropdown {
    id: endsDropdown
    width: parent.width
    showLabel: false
    value: root.repeatEnds
    options: Model.endsOptions()
    enabled: !root.busy && root.canEditRecurrence
    foreground: root.foreground
    fontFamily: root.fontFamily
    onChanged: function(value) { root.repeatEnds = value }
  }
  NumberField {
    visible: root.repeatEnds === "after"
    width: parent.width
    label: "Times"
    value: root.repeatCount
    from: 1
    to: 999
    stepSize: 1
    enabled: !root.busy && root.canEditRecurrence
    foreground: root.foreground
    fontFamily: root.fontFamily
    onModified: function(value) { root.repeatCount = value }
  }
  DatePicker {
    id: endsDatePicker
    visible: root.repeatEnds === "ondate"
    width: parent.width
    value: root.repeatUntil
    enabled: !root.busy && root.canEditRecurrence
    foreground: root.foreground
    fontFamily: root.fontFamily
    onChanged: function(value) { root.repeatUntil = value }
  }
}
```

Give the existing date `DatePicker` id `datePicker` (already present). The new picker must be `endsDatePicker`.

Keep Custom fields for Task 4. `freqDropdown` and `monthlyDropdown` can be declared in Task 4; until then `closePickers()` should only close pickers that exist. If you stub empty `Item { id: freqDropdown; function close() {} }` that is worse — add the Custom block in Task 4 and in this task only close `repeatDropdown`, `endsDropdown`, `endsDatePicker`, and `datePicker`.

**Step 3: Commit**

```bash
git add components/EventEditor.qml
git commit -m "$(cat <<'EOF'
feat(editor): add Repeat presets and Ends

Show Chroncal's named recurrence presets in the event editor and
attach Never / After / On date for those presets.
EOF
)"
```

Do not run formatters or qmllint.

---

### Task 4: Inline Custom Repeat fields

**Files:**
- Modify: `components/EventEditor.qml`

**Step 1: Render Custom fields when `showingCustomRepeat`**

Insert after the preset Ends column, still before Calendar:

```qml
Column {
  visible: root.showingCustomRepeat
  width: parent.width
  spacing: Style.space(8)

  FieldLabel { text: "REPEAT EVERY" }
  Row {
    width: parent.width
    spacing: Style.space(8)
    NumberField {
      width: (parent.width - Style.space(8)) * 0.4
      label: ""
      value: root.repeatInterval
      from: 1
      to: 99
      stepSize: 1
      enabled: !root.busy && root.canEditRecurrence
      foreground: root.foreground
      fontFamily: root.fontFamily
      onModified: function(value) { root.repeatInterval = value }
    }
    Dropdown {
      id: freqDropdown
      width: (parent.width - Style.space(8)) * 0.6
      showLabel: false
      value: root.repeatFreq
      options: Model.frequencyOptions()
      enabled: !root.busy && root.canEditRecurrence
      foreground: root.foreground
      fontFamily: root.fontFamily
      onChanged: function(value) { root.repeatFreq = value }
    }
  }

  Column {
    visible: root.repeatFreq === "WEEKLY"
    width: parent.width
    spacing: Style.space(4)
    FieldLabel { text: "ON" }
    Row {
      width: parent.width
      spacing: Style.space(4)
      Repeater {
        model: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
        FormButton {
          required property int index
          required property string modelData
          text: modelData
          selected: root.repeatWeekDays[index] === true
          enabled: !root.busy && root.canEditRecurrence
          onClicked: {
            var next = root.repeatWeekDays.slice()
            next[index] = !next[index]
            root.repeatWeekDays = next
          }
        }
      }
    }
  }

  Column {
    visible: root.repeatFreq === "MONTHLY"
    width: parent.width
    spacing: Style.space(4)
    FieldLabel { text: "ON" }
    Dropdown {
      id: monthlyDropdown
      width: parent.width
      showLabel: false
      value: root.repeatMonthlyMode
      options: Model.monthlyOnOptions(root.dateValue)
      enabled: !root.busy && root.canEditRecurrence
      foreground: root.foreground
      fontFamily: root.fontFamily
      onChanged: function(value) { root.repeatMonthlyMode = value }
    }
  }

  FieldLabel { text: "ENDS" }
  Dropdown {
    id: customEndsDropdown
    width: parent.width
    showLabel: false
    value: root.repeatEnds
    options: Model.endsOptions()
    enabled: !root.busy && root.canEditRecurrence
    foreground: root.foreground
    fontFamily: root.fontFamily
    onChanged: function(value) { root.repeatEnds = value }
  }
  NumberField {
    visible: root.repeatEnds === "after"
    width: parent.width
    label: "Times"
    value: root.repeatCount
    from: 1
    to: 999
    stepSize: 1
    enabled: !root.busy && root.canEditRecurrence
    foreground: root.foreground
    fontFamily: root.fontFamily
    onModified: function(value) { root.repeatCount = value }
  }
  DatePicker {
    id: customEndsDatePicker
    visible: root.repeatEnds === "ondate"
    width: parent.width
    value: root.repeatUntil
    enabled: !root.busy && root.canEditRecurrence
    foreground: root.foreground
    fontFamily: root.fontFamily
    onChanged: function(value) { root.repeatUntil = value }
  }

  Text {
    width: parent.width
    text: Model.recurrenceRuleSummary(root.recurrenceForm(), root.dateValue)
    textFormat: Text.PlainText
    color: Util.alpha(root.foreground, 0.62)
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    wrapMode: Text.WordWrap
  }
}
```

Do **not** give Custom a second `endsDatePicker` id. Reuse the Task 3 `endsDropdown` / `endsDatePicker` / After `NumberField` for Custom as well: move that Ends column so it is visible when `showingRepeatEnds || showingCustomRepeat`. Then Custom only adds Repeat every, On, and the summary.

Preferred structure after this task:

1. Repeat dropdown
2. Override note
3. Custom Repeat every / On (visible if Custom)
4. Shared Ends column visible if `repeatPreset !== "none"`
5. Summary visible if Custom

Update `closePickers()` to close `freqDropdown` and `monthlyDropdown` too.

If `FormButton` has no `selected` property, use `background: selected ? Util.alpha(root.foreground, 0.14) : ...` or Omarchy `Button` `selected:`. Prefer `Button { bordered: true; selected: ... }` if `FormButton` does not forward `selected`.

Weekly row may overflow 432px. If seven bordered buttons do not fit, shrink font/padding rather than wrapping to two rows.

**Step 2: Commit**

```bash
git add components/EventEditor.qml
git commit -m "$(cat <<'EOF'
feat(editor): author custom recurrence inline

Expand Custom Repeat with interval, weekly days, monthly on-date vs
Nth weekday, shared Ends, and a one-line rule summary.
EOF
)"
```

---

### Task 5: README

**Files:**
- Modify: `README.md`

**Step 1: Features and remaining-TUI copy**

In Features, after the series-edit bullets, add:

```md
- Creates and edits recurrence with Chroncal Repeat presets and inline Custom fields.
- Leaves stored override Repeat rules on the series; open the series editor to change them.
```

Replace:

```md
This is menu-bar parity, not a replacement for Chroncal's full TUI. Recurrence authoring, timezone-sensitive time changes, alarms, availability, sync configuration, account management, and advanced calendar operations remain in Chroncal.
```

with:

```md
This is menu-bar parity, not a replacement for Chroncal's full TUI. Timezone-sensitive time changes, alarms, availability, sync configuration, account management, and advanced calendar operations remain in Chroncal.
```

Keep a trailing newline.

**Step 2: Commit**

```bash
git add README.md
git commit -m "$(cat <<'EOF'
docs: document in-panel recurrence authoring

Chroncal Bar now authors Repeat presets and Custom rules. Timezone,
alarms, and account setup still stay in Chroncal.
EOF
)"
```

---

## Live QA (after all tasks, Main)

Throwaway calendar only. Do not use GMX or real events.

1. Create Every week; agenda shows generated occurrences
2. Create Custom weekdays with On date; rule summary matches; later days stop after UNTIL
3. Edit a one-off, set Every month, save; it becomes a series
4. Open a generated occurrence, E, change Repeat to Every day, Save series
5. Open a stored override; Repeat is disabled; save does not send `--recurrence-rule`
6. No new `TypeError` / `ReferenceError` in the journal
