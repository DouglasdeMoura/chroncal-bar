# Notion Calendar Menu-Bar Parity Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use `executing-plans` to implement this plan task-by-task.

**Goal:** Turn Chroncal Bar into a Notion Calendar-inspired menu-bar widget with a keyboard-first agenda panel, event details and quick actions, menu-bar filters, search, and basic event CRUD while keeping Chroncal as the source of truth and advanced editor.

**Architecture:** `BarWidget.qml` owns refresh state and hosts a nested `Panel.qml`. A tested shell adapter normalizes Chroncal event/calendar JSON once per refresh; the panel hydrates only its selected event. QML components render and mutate through argument arrays so event content never becomes shell source.

**Tech Stack:** Omarchy Quattro/Quickshell QML, Qt Quick, Bash, jq, Chroncal CLI, shell fixture tests, Qt 6 `qmllint`.

---

## Invariants

- The plugin remains one `bar-widget`; `Panel.qml` is loaded by `BarWidget.qml`.
- No daemon, second Quickshell process, privilege escalation, remote installer, or implicit configuration overwrite.
- Chroncal owns calendars/events. Plugin preferences live under `$XDG_STATE_HOME/chroncal-bar` and change only after an explicit user action.
- All mutation arguments cross a process argument array, never interpolated shell source.
- The default settings preserve current bar behavior.
- Each task ends in a verified, independently useful commit.

### Task 1: Normalized agenda adapter

**Files:**
- Create: `scripts/chroncal-exec`
- Create: `scripts/chroncal-bar-agenda`
- Create: `tests/fakes/chroncal`
- Create: `tests/fixtures/events.json`
- Create: `tests/fixtures/calendars.json`
- Create: `tests/fixtures/state/chroncal/state.json`
- Create: `tests/test-agenda.sh`
- Modify: `scripts/chroncal-next-event`

**Steps:**
1. Write fixture tests for date-window arguments, hidden calendars, recurring instances, all-day events, overlaps, cancelled/ended filtering, calendar colors, and unavailable Chroncal.
2. Run `tests/test-agenda.sh`; verify it fails because `chroncal-bar-agenda` does not exist.
3. Add `chroncal-exec`, resolving `chroncal` directly or through mise while preserving argument boundaries.
4. Add `chroncal-bar-agenda`, supporting injectable `CHRONCAL_BIN`, `CHRONCAL_BAR_NOW`, `XDG_STATE_HOME`, and look-ahead days.
5. Emit one normalized object: `{generated_at, status, calendars, events, next}`.
6. Reimplement the current one-line presentation using the normalized adapter without changing default visible behavior.
7. Run fixture tests, script syntax checks, and the installed Chroncal smoke test.
8. Commit: `refactor: add tested Chroncal agenda adapter`.

### Task 2: Read-only agenda panel

**Files:**
- Create: `Panel.qml`
- Create: `Model.js`
- Create: `components/EventRow.qml`
- Modify: `BarWidget.qml`
- Modify: `manifest.json`
- Create: `tests/test-model.js`

**Steps:**
1. Write failing model contract tests for grouping by local day, selection clamping, relative-day labels, time ranges, and current-event progress.
2. Implement the pure formatting/grouping model used by both bar and panel.
3. Add clock-style panel lifecycle forwarding to `BarWidget.qml`: `opened`, `open`, `close`, `toggle`, `closeForPopoutSwitch`, and panel injection.
4. Load agenda JSON once in `BarWidget.qml`; pass it to the nested panel.
5. Build an anchored `KeyboardPanel` with header, refresh/loading/error/empty states, scrollable day groups, and color-coded event rows.
6. Make left click toggle the panel; retain middle-click join/open and right-click refresh.
7. Run model tests, plugin validation, Qt 6 lint, helper tests, and actual shell load.
8. Commit: `feat: add multi-day agenda panel`.

### Task 3: Event details and quick actions

**Files:**
- Create: `scripts/chroncal-bar-detail`
- Create: `scripts/chroncal-bar-copy`
- Create: `components/EventDetail.qml`
- Create: `tests/test-detail.sh`
- Modify: `Panel.qml`
- Modify: `Model.js`
- Modify: `README.md`

**Steps:**
1. Write failing fixtures for hydrated location, description, conference URI, generic URL, attendees, RSVP state, recurrence, privacy, and free/busy state.
2. Implement selected-event hydration through `chroncal event get` plus calendar metadata.
3. Render detail state only for the selected row; never N+1 fetch the agenda.
4. Add direct argument-array actions: join/open URL, map location, email participants, copy details, and open Chroncal TUI.
5. Define deterministic URL precedence: conference URI, event URL, URL in location, URL in description.
6. Add action-disabled and missing-data states.
7. Run fixture tests and actual event-detail smoke tests.
8. Commit: `feat: add event details and quick actions`.

### Task 4: Menu-bar settings and filters

**Files:**
- Create: `scripts/chroncal-bar-preferences`
- Create: `components/CalendarSettings.qml`
- Create: `tests/test-preferences.sh`
- Modify: `manifest.json`
- Modify: `BarWidget.qml`
- Modify: `Panel.qml`
- Modify: `scripts/chroncal-bar-agenda`

**Steps:**
1. Write failing tests for atomic default preferences, explicit per-calendar exclusion, malformed-state recovery, and no writes during reads.
2. Add manifest settings for interval, look-ahead days, preview lead, title/time visibility, all-day inclusion, and max title length.
3. Implement plugin preferences under `$XDG_STATE_HOME/chroncal-bar/preferences.json`.
4. Add per-calendar include/exclude controls to the panel.
5. Apply fixed and per-calendar filters consistently to both bar selection and agenda rows.
6. Keep defaults behavior-compatible with version 1.0.0.
7. Run settings tests, adapter tests, validation, lint, and reload persistence smoke test.
8. Commit: `feat: add menu-bar filters and calendar preferences`.

### Task 5: Keyboard navigation and search

**Files:**
- Create: `components/ShortcutHelp.qml`
- Modify: `Panel.qml`
- Modify: `Model.js`
- Modify: `tests/test-model.js`

**Steps:**
1. Add failing tests for case-insensitive search, stable selection after filtering, next/previous event, and today navigation.
2. Add local agenda search without another Chroncal process.
3. Implement `j/k`, arrows, `n/b`, `t`, `/`, `Enter`, `e`, `c`, `r`, `?`, and `Esc` through `PanelKeyCatcher`.
4. Add discoverable shortcut help and visible selection/focus states.
5. Ensure mouse and keyboard selection share one state machine.
6. Run model tests, actual keyboard panel smoke test, validation, and lint.
7. Commit: `feat: add agenda search and keyboard workflow`.

### Task 6: Basic event CRUD

**Files:**
- Create: `components/EventForm.qml`
- Create: `tests/test-command.sh`
- Modify: `Panel.qml`
- Modify: `Model.js`
- Modify: `scripts/chroncal-exec`

**Steps:**
1. Write failing fake-CLI tests proving exact argument arrays for create, update, and delete.
2. Build a basic form for title, calendar, date, time/all-day, duration/end time, location, URL, privacy, and busy/free.
3. Call `chroncal event add` and `chroncal event update` through direct arguments.
4. Confirm deletion through `ConfirmDialog`, then call `chroncal event delete --yes`.
5. Refresh agenda only after successful mutation; preserve form state and show actionable errors on failure.
6. Route advanced recurrence, attendee, alarm, and RSVP editing to the Chroncal TUI rather than approximating unsupported CLI behavior.
7. Run fixture tests plus CRUD against a temporary local QA calendar, then remove that calendar.
8. Commit: `feat: add basic event creation and editing`.

### Task 7: Polish, documentation, and release

**Files:**
- Modify: `README.md`
- Modify: `manifest.json`
- Modify: `preview.png` only if the final UI materially changes
- Modify: tests as required by discovered edge cases

**Steps:**
1. Test empty, unavailable, all-day, overlapping, in-progress, declined/cancelled, hidden-calendar, long-title, timezone, and mutation-error states.
2. Exercise actual clicks, keyboard flow, resize, shell restart, disable/re-enable, removal/reinstall, and multiple refreshes.
3. Inspect fresh shell logs for plugin errors.
4. Update documentation, dependencies, settings, shortcuts, privacy boundaries, and advanced-editor limitations.
5. Bump manifest version to `1.1.0`.
6. Run all tests, `omarchy plugin validate`, script syntax checks, Qt 6 lint, and actual-surface screenshot verification.
7. Request code review and address blocking findings.
8. Commit: `docs: release Notion-inspired agenda experience`.
9. Fast-forward stable `main`, push all commits, pull the installed plugin, and sync the config backup without nested `.git` data.
