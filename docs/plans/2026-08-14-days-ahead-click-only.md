# Days-Ahead and Click-Only Bar Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Expose the existing 1–30 day agenda horizon in the panel Settings screen and suppress the top-bar Chroncal hover tooltip.

**Architecture:** Reuse the persisted `lookaheadDays` setting already declared in `manifest.json` and consumed by `BarWidget.refresh()`. `CalendarSettings` emits the value through the existing configuration signal; `Panel` persists it and asks the host widget to refresh after the new setting is installed. The bar widget uses an empty tooltip while retaining click-to-open behavior.

**Tech Stack:** Qt 6 QML, Quickshell/Omarchy `BarWidget`, JavaScript model tests, Bash agenda adapter tests.

---

### Task 1: Add the in-panel days-ahead control

**Files:**
- Modify: `components/CalendarSettings.qml:10-19,99-118`
- Modify: `Panel.qml:607-620`

**Step 1: Add the settings property**

Add `property int lookaheadDays: 7` to `CalendarSettings`.

**Step 2: Render the field**

At the top of `AGENDA FILTERS`, add a `NumberField` with label `Days ahead`, `from: 1`, `to: 30`, `stepSize: 1`, and `value: root.lookaheadDays`. Its `onModified` handler emits `{ lookaheadDays: value }` through `configurationChanged`.

**Step 3: Bind the persisted setting**

Pass `lookaheadDays: Number(root.setting("lookaheadDays", 7))` from `Panel` to `CalendarSettings`.

**Step 4: Validate QML structure**

Run:

```bash
/usr/lib/qt6/bin/qmllint -I /usr/share/omarchy/shell BarWidget.qml Panel.qml components/CalendarSettings.qml
omarchy plugin validate .
```

Expected: commands exit successfully; standalone `qmllint` may report the repository's known unresolved `qs.Commons`/`qs.Ui` import warnings.

### Task 2: Refresh immediately after horizon changes

**Files:**
- Modify: `Panel.qml:96-104`
- Modify: `BarWidget.qml:12-54,96-103`

**Step 1: Detect the horizon change before replacing settings**

In `persistSettings`, compare an incoming `lookaheadDays` with the current setting and store whether an agenda refresh is required.

**Step 2: Request refresh after persistence**

After `updateEntryInline`, use `Qt.callLater` to call `hostWidget.broadcast("refresh")` when the horizon changed so every monitor instance reloads.

**Step 3: Preserve refresh requests during an active query**

Add a `refreshPending` boolean to `BarWidget`. If `refresh()` is called while `agendaProc` is running, set the flag. After the process exits, schedule another refresh when the flag is set. This ensures a setting change cannot be dropped during the initial agenda load.

**Step 4: Run existing behavioral suites**

Run:

```bash
TZ=UTC bun tests/test-model.js
tests/test-agenda.sh
tests/test-open-url.sh
```

Expected: all three suites print `ok` and exit zero.

### Task 3: Make the bar widget click-only

**Files:**
- Modify: `BarWidget.qml:134-146`

**Step 1: Remove hover content**

Set the bar button's `tooltipText` to an empty string. Do not change `onClicked`, middle-click, wheel, or panel button tooltips.

**Step 2: Validate the complete plugin**

Run:

```bash
bash -n scripts/chroncal-exec scripts/chroncal-bar-agenda scripts/chroncal-next-event scripts/chroncal-open-next-event-url
omarchy plugin validate .
git diff --check
```

Expected: every command exits zero.

### Task 4: Document, release, deploy, and smoke-test

**Files:**
- Modify: `README.md`
- Modify: `manifest.json`
- Modify recovery copy under `/home/doug/github.com/douglasdemoura/config/config/omarchy/plugins/douglasdemoura.chroncal-bar/`

**Step 1: Update user documentation**

Document `Days ahead` under Settings and state that the top-bar widget opens only on click and has no hover tooltip.

**Step 2: Bump the patch version**

Change the plugin manifest version from `1.1.1` to `1.1.2`.

**Step 3: Commit and publish**

Commit the implementation using Conventional Commits, push `main`, and publish annotated tag `v1.1.2`.

**Step 4: Deploy the stable checkout**

Fast-forward `/home/doug/.config/omarchy/plugins/douglasdemoura.chroncal-bar` to `origin/main`. Sync the stable files and active shell configuration into the config recovery repository, validate its copied test suites, commit, and push.

**Step 5: Verify the live surface**

Reload or restart Omarchy Shell when the session is unlocked. Confirm:

1. Hovering the top-bar Chroncal widget displays no tooltip.
2. Clicking the widget opens the agenda.
3. Settings contains `Days ahead` with range 1–30.
4. Changing the value persists `lookaheadDays` in `~/.config/omarchy/shell.json` and immediately reloads the agenda using the chosen horizon.
5. Shell logs contain no new Chroncal QML errors.
