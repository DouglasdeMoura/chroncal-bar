# Resettable Calendar Selection Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make all calendars visibly selected by default, preserve explicit custom selections including none, and let users return to automatic default-all behavior.

**Architecture:** Add an explicit `calendarSelectionCustomized` state alongside the existing selected-ID array. Model helpers derive effective selected IDs from calendars plus settings, while filtering applies the selected-ID constraint only in custom mode. The Settings component emits complete state transitions and exposes a reset action.

**Tech Stack:** Qt 6 QML, Quickshell/Omarchy `MultiSelect`, JavaScript model tests with Bun, Bash adapter tests.

---

### Task 1: Define and test calendar selection state

**Files:**
- Modify: `tests/test-model.js`
- Modify: `Model.js:174-201,232-236`

**Step 1: Write failing model tests**

Add contracts proving:

- Missing selection state derives every calendar ID.
- An old non-empty `includedCalendarIds` array is inferred as customized.
- Explicit custom subset returns only that subset.
- Explicit custom empty returns an empty selection.
- `filterEvents` returns every event in default mode, a subset in custom mode, and no events for custom empty.

**Step 2: Run tests and verify RED**

Run `TZ=UTC bun tests/test-model.js`.

Expected: failure because the selection helper and explicit custom-empty filtering do not exist.

**Step 3: Implement minimal model helpers**

Add `calendarSelectionCustomized(settings)` and `selectedCalendarIds(calendars, settings)`. Update `filterEvents` so calendar filtering is unconditional only when custom mode is true; retain inference for existing non-empty selections.

**Step 4: Run tests and verify GREEN**

Run `TZ=UTC bun tests/test-model.js`.

Expected: `agenda model tests: ok`.

**Step 5: Commit**

Commit model and tests with `feat(settings): define calendar selection state`.

### Task 2: Wire effective selection through the widget and panel

**Files:**
- Modify: `BarWidget.qml:25-31`
- Modify: `Panel.qml:607-625`

**Step 1: Derive effective IDs in BarWidget**

Pass `calendarSelectionCustomized` and `Model.selectedCalendarIds(agendaData.calendars, root.settings)` into `filterOptions`.

**Step 2: Derive effective IDs in Panel**

Pass the same customization state and effective IDs to `CalendarSettings`, using the panel's current calendars and settings.

**Step 3: Run model and adapter suites**

Run:

```bash
TZ=UTC bun tests/test-model.js
tests/test-agenda.sh
tests/test-open-url.sh
```

Expected: all suites print `ok`.

### Task 3: Make default and custom selection explicit in Settings

**Files:**
- Modify: `components/CalendarSettings.qml:10-58`

**Step 1: Add customization state**

Add `property bool calendarSelectionCustomized: false`.

**Step 2: Persist exact checkbox changes**

Keep `values` bound to the effective selected IDs. On change, emit both `includedCalendarIds: values` and `calendarSelectionCustomized: true`.

**Step 3: Distinguish empty selection**

Change `noSelectionText` from `All calendars` to `No calendars`.

**Step 4: Add reset action**

When custom mode is active, show `Use default (all calendars)`. Clicking it emits `includedCalendarIds: []` and `calendarSelectionCustomized: false`; derived values then repopulate with every current calendar.

**Step 5: Validate QML**

Run:

```bash
/usr/lib/qt6/bin/qmllint -I /usr/share/omarchy/shell BarWidget.qml Panel.qml components/CalendarSettings.qml
omarchy plugin validate .
git diff --check
```

Expected: commands exit zero; standalone qmllint may retain known unresolved `qs.Commons`/`qs.Ui` warnings.

**Step 6: Commit**

Commit QML changes with `feat(settings): expose resettable calendar selection`.

### Task 4: Document, release, deploy, and verify

**Files:**
- Modify: `README.md`
- Modify: `manifest.json`
- Modify recovery copy under `/home/doug/github.com/douglasdemoura/config/config/omarchy/plugins/douglasdemoura.chroncal-bar/`

**Step 1: Document selection semantics**

State that every calendar is selected by default, custom selections remain exact, empty custom selection hides all events, and the reset action restores automatic inclusion.

**Step 2: Bump patch release**

Change manifest version from `1.1.3` to `1.1.4`.

**Step 3: Run fresh release verification**

Run all model, agenda, URL, shell-syntax, plugin-validation, and diff checks.

**Step 4: Review, merge, and publish**

Request focused review, fast-forward merge to `main`, push, and publish annotated tag `v1.1.4`.

**Step 5: Deploy and synchronize recovery**

Fast-forward the installed plugin, restart Omarchy Shell, synchronize the config recovery copy, rerun its suites, commit, and push.

**Step 6: Verify the live surface**

Confirm every calendar is checked in default mode. Deselect all and confirm `No calendars` plus no visible events. Activate `Use default (all calendars)` and confirm all checks and events return. Confirm current shell logs have no Chroncal errors.
