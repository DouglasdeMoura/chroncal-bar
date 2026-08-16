# Universal Event Editing Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Keep the pencil enabled for every identified event and safely edit generated recurring occurrences as whole series inside the Chroncal Bar panel.

**Architecture:** Preserve the existing direct-mutation guard for deletion and occurrence overrides. Add explicit edit eligibility and whole-series authorization in `Model.js`; generated occurrences asynchronously load their master in `Panel.qml`, while `selectedEvent` remains the clicked occurrence and a separate `editorEvent` drives the editor. `EventDetails.qml` exposes the enabled pencil and `EventEditor.qml` clearly identifies whole-series mode.

**Tech Stack:** QML/Qt 6, Quickshell `Process` and `StdioCollector`, JavaScript model helpers, Chroncal 0.7.3 CLI, Bun model tests, shell integration tests, Omarchy plugin validation.

---

### Task 1: Define Safe Universal Edit Model Contracts

**Files:**
- Modify: `Model.js:376-433`
- Modify: `tests/test-model.js:100-125`

**Step 1: Add failing eligibility and recurrence tests**

Extend `tests/test-model.js` with contracts equivalent to:

```js
assert.equal(model.canEditEvent(null), false);
assert.equal(model.canEditEvent({}), false);
assert.equal(model.canEditEvent({ id: 42 }), true);
assert.equal(model.canEditEvent({ uid: "weekly-uid" }), true);

const generated = {
  id: 42,
  uid: "weekly-uid",
  recurrence_rule: "FREQ=WEEKLY",
  recurrence_id: "",
};
assert.equal(model.isGeneratedRecurringEvent(generated), true);
assert.equal(model.isGeneratedRecurringEvent({ ...generated, recurrence_id: "2026-08-18T14:30:00Z" }), false);
assert.equal(model.isGeneratedRecurringEvent({ id: 42 }), false);
assert.deepEqual(model.seriesMasterLookupArgs(generated), ["event", "get", "42", "--output", "json"]);
assert.deepEqual(model.seriesMasterLookupArgs({ id: 42 }), []);
```

Add merge/identity contracts:

```js
const occurrence = { ...generated, calendar_id: 3, calendar_name: "Personal", start_time: "2026-08-18T14:30:00Z" };
const master = { ...generated, start_time: "2026-05-20T14:30:00Z", calendar_name: null };
const prepared = model.seriesEditorEvent(master, occurrence);
assert.equal(prepared.start_time, "2026-05-20T14:30:00Z");
assert.equal(prepared.calendar_name, "Personal");
assert.equal(model.seriesEditorEvent({ ...master, id: 99 }, occurrence), null);
assert.equal(model.seriesEditorEvent({ ...master, uid: "other" }, occurrence), null);
```

Add mutation authorization contracts:

```js
assert.deepEqual(model.eventMutationArgs("edit", generated, createValues), []);
assert.deepEqual(
  model.eventMutationArgs("edit", master, createValues, { series: true }).slice(0, 4),
  ["event", "update", "42", "--title"]
);
assert.deepEqual(model.eventDeleteArgs(generated), []);
assert.deepEqual(model.eventDeleteArgs({}), []);
```

**Step 2: Run the model test and confirm failure**

```bash
TZ=UTC bun tests/test-model.js
```

Expected: FAIL because the new helper functions and explicit series option do not exist.

**Step 3: Implement minimal fail-closed helpers**

In `Model.js`, add:

```js
function eventReference(event) {
  if (!event) return "";
  if (event.id !== undefined && event.id !== null && String(event.id) !== "") return String(event.id);
  return String(event.uid || "");
}

function canEditEvent(event) {
  return eventReference(event) !== "";
}

function isGeneratedRecurringEvent(event) {
  if (!event) return false;
  var recurring = String(event.recurrence_rule || "") !== "" || String(event.rdates || "") !== "";
  return recurring && String(event.recurrence_id || "") === "";
}

function seriesMasterLookupArgs(event) {
  if (!isGeneratedRecurringEvent(event)) return [];
  var reference = eventReference(event);
  return reference === "" ? [] : ["event", "get", reference, "--output", "json"];
}
```

Make `canMutateEvent()` require `canEditEvent(event)` before applying its existing recurrence rule.

Implement `seriesEditorEvent(master, occurrence)` to return `null` unless both represent the same generated recurring series. When both IDs exist they must match; when both UIDs exist they must match. Return a new object based on the master and fill missing calendar display metadata (`calendar_id`, `calendar_name`, `calendar_color`, `calendar_owner_email`) from the occurrence without replacing present master values.

Extend `eventMutationArgs(mode, event, values, options)`:

```js
var seriesEdit = mode === "edit"
  && options && options.series === true
  && isGeneratedRecurringEvent(event)
  && canEditEvent(event);
if (errors.length > 0 || (mode === "edit" && !canMutateEvent(event) && !seriesEdit)) return [];
```

Keep default generated-occurrence mutation rejected. Keep the existing UID + recurrence-ID target for stored overrides.

**Step 4: Run focused tests**

```bash
TZ=UTC bun tests/test-model.js
```

Expected: `agenda model tests: ok`.

**Step 5: Commit model contracts**

```bash
git add Model.js tests/test-model.js
git commit -m "feat(events): define safe recurring series edits"
```

### Task 2: Load Recurring Masters Before Editing

**Files:**
- Modify: `Panel.qml:25-38, 42-95, 173-248, 280-291, 580-609`

**Step 1: Add independent editor and lookup state**

Add panel properties:

```qml
property var editorEvent: null
property bool editingSeries: false
property bool editLoadBusy: false
property bool editLoadRequested: false
property string editLoadEventKey: ""
property var editLoadSourceEvent: null
property string editLoadStdoutText: ""
property string editLoadStderrText: ""
```

Every navigation/reset path that clears the selected event must invalidate `editLoadRequested`, clear editor state, and prevent a late result from opening the editor. Do not terminate or reuse a running process unsafely.

**Step 2: Split direct and whole-series edit startup**

Add a small `openEditor(eventData, series)` helper that sets `editorEvent`, `editingSeries`, `editorMode = "edit"`, and schedules `eventEditor.initialize()`.

Update `startEdit()`:

- Reject missing identity, `mutationBusy`, or `editLoadBusy`.
- Directly open one-off events and stored overrides when `Model.canMutateEvent(selectedEvent)` is true.
- For `Model.isGeneratedRecurringEvent(selectedEvent)`, build `Model.seriesMasterLookupArgs(selectedEvent)`.
- Require `hostWidget.chroncalExecScript`; otherwise show `Chroncal executable is unavailable` in `actionStatus`.
- Store the source event and key, set `editLoadRequested` and `editLoadBusy`, clear collectors, set status `Loading recurring series…`, then start a dedicated process through the wrapper.

**Step 3: Implement lookup completion**

Add `finishEditLoad(exitCode)` with these invariants:

1. Clear `editLoadBusy`.
2. If the request was invalidated, discard output and return.
3. Verify the panel remains open and `Model.eventKey(selectedEvent)` equals the requested key.
4. On non-zero exit, show trimmed stderr/stdout or `Chroncal could not load the recurring series`.
5. Parse stdout as JSON inside `try/catch`.
6. Pass the parsed master and stored source occurrence to `Model.seriesEditorEvent()`.
7. Reject invalid/mismatched data with `Chroncal returned an invalid recurring series`.
8. Clear loading status and open the prepared master with `series = true`.

Keep `selectedEvent` unchanged so cancel returns to the clicked occurrence.

**Step 4: Add the dedicated process**

Near `mutationProc`, add:

```qml
Process {
  id: editLoadProc
  stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.editLoadStdoutText = text }
  stderr: StdioCollector { waitForEnd: true; onStreamFinished: root.editLoadStderrText = text }
  onExited: function(exitCode) { Qt.callLater(function() { root.finishEditLoad(exitCode) }) }
}
```

**Step 5: Route editor save/cancel through editor state**

- `submitEditor()` calls `Model.eventMutationArgs(editorMode, editorEvent, values, { series: editingSeries })`.
- `cancelEditor()` clears `editorEvent` and `editingSeries` while preserving `selectedEvent` for edit mode.
- Successful mutation clears both editor properties.
- `EventEditor.eventData` binds to `root.editorEvent`.
- `EventEditor.editingSeries` binds to `root.editingSeries`.
- `EventDetails.busy` includes both mutation and lookup busy states.

**Step 6: Run QML and existing integration checks**

```bash
TZ=UTC bun tests/test-model.js
tests/test-agenda.sh
tests/test-open-url.sh
/usr/lib/qt6/bin/qmllint -I /usr/share/omarchy/shell Panel.qml
omarchy plugin validate .
git diff --check
```

Expected: executable checks exit zero. Standalone `qmllint` may retain known unresolved Quickshell import warnings but reports no new syntax error or invalid property in changed lines.

**Step 7: Commit master loading**

```bash
git add Panel.qml
git commit -m "feat(events): load recurring masters for editing"
```

### Task 3: Expose Whole-Series Editing in Event Details

**Files:**
- Modify: `components/EventDetails.qml:24-29, 205-213, 277-294`
- Modify: `components/EventEditor.qml:12-32, 120-135`
- Modify: `README.md:18-30, 75-82`

**Step 1: Separate pencil and delete eligibility**

In `EventDetails.qml`, add read-only properties for `canEdit` and generated recurrence state while retaining `canMutate` for deletion.

Change the explanatory text to be visible for generated recurring occurrences and say:

```text
The pencil edits this entire recurring series. Delete individual occurrences in Chroncal.
```

Change the pencil contract:

```qml
tooltipText: root.generatedRecurring ? "Edit recurring series" : "Edit event"
enabled: !root.busy && root.canEdit
```

Keep delete gated by `root.canMutate`.

**Step 2: Add the editor warning**

In `EventEditor.qml`, add:

```qml
property bool editingSeries: false
```

At the top of the form, render a visible, wrapped warning when true:

```text
Editing entire recurring series
Changes apply to every occurrence.
```

Use existing panel foreground, spacing, corner radius, and subtle-surface patterns; do not introduce a new color or component abstraction. Preserve current timezone schedule restrictions and all validation.

**Step 3: Update user documentation**

Document that:

- Every identified event has an enabled pencil.
- Generated recurring occurrences load and edit the whole series.
- Stored overrides still edit only that override.
- Generated-occurrence deletion remains in Chroncal.

Keep the existing `E` shortcut wording unless a clearer `Edit event or recurring series` label is needed.

**Step 4: Run the complete pre-release suite**

```bash
TZ=UTC bun tests/test-model.js
tests/test-agenda.sh
tests/test-open-url.sh
bash -n scripts/chroncal-exec scripts/chroncal-bar-agenda scripts/chroncal-next-event scripts/chroncal-open-next-event-url
/usr/lib/qt6/bin/qmllint -I /usr/share/omarchy/shell Panel.qml components/EventDetails.qml components/EventEditor.qml
omarchy plugin validate .
git diff --check
```

Expected: all executable checks exit zero and no new QML diagnostic references changed properties or handlers.

**Step 5: Commit universal edit UI**

```bash
git add components/EventDetails.qml components/EventEditor.qml README.md
git commit -m "feat(events): expose recurring series editing"
```

### Task 4: Publish Chroncal Bar 1.1.6

**Files:**
- Modify: `manifest.json:5`

**Step 1: Bump the patch version**

Change manifest version from `1.1.5` to `1.1.6`.

**Step 2: Run fresh release validation**

Run the complete command set from Task 3 Step 4.

Expected: all executable checks exit zero; only known standalone import warnings remain.

**Step 3: Commit release metadata**

```bash
git add manifest.json
git commit -m "chore(release): bump Chroncal Bar to 1.1.6"
```

**Step 4: Review and publish**

After strict spec and code-quality review of the full branch:

```bash
git push origin main
git tag -a v1.1.6 -m "Chroncal Bar v1.1.6"
git push origin v1.1.6
```

Expected: `origin/main` and annotated tag `v1.1.6` point at the reviewed release commit.

### Task 5: Deploy, Exercise, and Synchronize Recovery

**Files:**
- Update by fast-forward: `~/.config/omarchy/plugins/douglasdemoura.chroncal-bar`
- Synchronize: `../config/config/omarchy/plugins/douglasdemoura.chroncal-bar/**`

**Step 1: Deploy the published plugin**

```bash
cd ~/.config/omarchy/plugins/douglasdemoura.chroncal-bar
git pull --ff-only
omarchy-restart-shell
```

Expected: live checkout reports exact tag `v1.1.6`.

**Step 2: Verify generated-series editing live**

Open a generated occurrence such as `Jiu-jitsu adulto` whose details currently state that it has no separate identity.

Verify:

- Pencil is enabled.
- Clicking pencil or pressing `E` shows a brief loading state and opens the editor.
- Warning reads **Editing entire recurring series** and **Changes apply to every occurrence.**
- Editor date/time are loaded from master ID 6724 (series start), not from the selected expanded occurrence.
- Cancel returns to the originally selected occurrence.
- Delete remains disabled for that generated occurrence.

Do not save a real calendar mutation solely for smoke testing. Model command tests prove the save target; live QA proves the read-only loading and UI transition.

**Step 3: Regression-check direct editing**

Open a one-off event or stored override when available. Verify pencil enters the editor without the series warning. If no such live event is available, report the unavailable fixture and rely on the passing model contracts rather than mutating calendar data.

**Step 4: Inspect runtime logs**

Search the newest Quickshell log for Chroncal `TypeError`, `ReferenceError`, assignment failures, or unavailable components.

Expected: no new Chroncal runtime errors.

**Step 5: Synchronize recovery**

Copy the stable v1.1.6 plugin tree into `config/omarchy/plugins/douglasdemoura.chroncal-bar`, excluding `.git` and `.worktrees`.

Run the model, agenda, URL, shell-syntax, and `git diff --check` validations from the config repository.

Commit and push:

```bash
git add config/omarchy/plugins/douglasdemoura.chroncal-bar
git commit -m "feat(omarchy): restore universal Chroncal editing"
git push
```

**Step 6: Confirm final state**

Confirm stable and live plugin checkouts are clean at `v1.1.6`, recovery is clean and synchronized, and the current shell log contains no new Chroncal errors.
