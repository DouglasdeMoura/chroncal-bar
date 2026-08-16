# Standardized Back Control Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Give every Chroncal panel subview the same header-right `←` back control, then publish the change as Chroncal Bar 1.1.9.

**Architecture:** Add a `showingSubview` flag on `Panel`. Replace the four back presentations with one `PanelActionButton` in `headerActions`. Remove the event-details content-row back button and the `ESC  Back` caption. Keep the editor footer `Cancel` button as a form action. Release as patch 1.1.9, deploy the tagged `main` revision to the live plugin, then synchronize the recovery repository.

**Tech Stack:** QML, Qt 6, Omarchy `PanelActionButton`, Bun model tests, shell integration tests, Omarchy plugin validation.

---

### Task 1: Unify the header back control

**Files:**
- Modify: `Panel.qml`
- Modify: `components/EventDetails.qml`
- Modify: `README.md`

**Step 1: Add a subview flag**

After `showingHelp`, add:

```qml
readonly property bool showingSubview: showingDetails || showingEditor || showingSettings || showingHelp
```

**Step 2: Replace the four header back presentations**

In `headerActions`, delete:

- the `ESC  Back` `Text`
- the editor-only `←` button
- the settings cog that swaps to `←`
- the help-only `←` button

Insert one back button first in the row:

```qml
PanelActionButton {
  visible: root.showingSubview
  iconText: "←"
  tooltipText: root.showingEditor ? "Cancel and go back" : "Back to agenda"
  foreground: root.contentForeground
  fontFamily: root.contentFontFamily
  onClicked: {
    if (root.showingEditor) root.cancelEditor()
    else root.backToAgenda()
  }
}
```

Show the settings, help, create, and refresh buttons only when `!root.showingSubview`. The settings button must always use icon `󰒓` and tooltip `Calendar settings`; it must never become a back arrow.

**Step 3: Remove the details-content back button**

In `components/EventDetails.qml`:

- Delete `signal backRequested()`.
- Replace the title `Row` (back button + title) with a single full-width title `Text`.
- Do not change quick actions, series copy, or edit/delete enablement.

In `Panel.qml`, remove `onBackRequested` from the `EventDetails` instance.

**Step 4: Document the shared control**

In `README.md`, keep the `Esc` row. After the shortcut table, state that subviews share one header back arrow. Do not claim a mouse search control.

Restore trailing newlines on every edited file.

**Step 5: Validate**

Skip project-wide formatters. Run:

```bash
TZ=UTC bun tests/test-model.js
tests/test-agenda.sh
tests/test-open-url.sh
bash -n scripts/chroncal-exec scripts/chroncal-bar-agenda scripts/chroncal-next-event scripts/chroncal-open-next-event-url
omarchy plugin validate .
/usr/lib/qt6/bin/qmllint -I /usr/share/omarchy/shell BarWidget.qml Panel.qml components/*.qml
git diff --check
```

Expected: tests and validation exit zero. Standalone `qmllint` may report the known unresolved-import / unqualified / `PanelActionButton` / inheritance-cycle warnings; those are baseline, not blockers. No new syntax error on the edited lines.

**Step 6: Commit**

```bash
git add Panel.qml components/EventDetails.qml README.md
git commit -m "feat(ui): unify panel back control"
```

---

### Task 2: Prepare and publish patch version 1.1.9

**Files:**
- Modify: `manifest.json`

**Step 1: Bump the manifest version**

Change `"version": "1.1.8"` to `"version": "1.1.9"`. Edit the JSON with a small Python rewrite of the `version` value only. Do not use `Write`/`StrReplace` on `manifest.json`; those tools can inject hashline prefixes.

**Step 2: Re-run release validation**

Run the complete command set from Task 1 Step 5.

**Step 3: Commit release metadata**

```bash
git add manifest.json
git commit -m "chore(release): bump Chroncal Bar to 1.1.9"
```

**Step 4: Publish main and the annotated tag**

Fast-forward `main`, then:

```bash
git push origin main
git tag -a v1.1.9 -m "Chroncal Bar v1.1.9"
git push origin v1.1.9
```

Do not move `v1.1.8` or any earlier tag. Expected: `git describe --tags --exact-match HEAD` is `v1.1.9`.

---

### Task 3: Deploy and visually verify the live plugin

**Files:**
- Update by fast-forward: `~/.config/omarchy/plugins/douglasdemoura.chroncal-bar`

**Step 1: Deploy**

```bash
cd ~/.config/omarchy/plugins/douglasdemoura.chroncal-bar
git pull --ff-only
omarchy-restart-shell
```

Expected: live checkout is `v1.1.9`.

**Step 2: Confirm one header back control**

On `eDP-1`, open the agenda and visit details, create, settings, and shortcuts. On each subview the only header action is `←` in the same right-side slot. Event details must not show `ESC  Back` or a second arrow beside the title. Settings must not show a cog while open. The editor footer still has `Cancel` beside Save/Create.

**Step 3: Confirm destinations**

- Details / settings / shortcuts `←` or `Esc` returns to the agenda.
- Create `←`, `Cancel`, or `Esc` returns to the agenda.
- Edit `←`, `Cancel`, or `Esc` returns to event details, not the agenda.

**Step 4: Inspect the current shell log**

No new Chroncal `TypeError` or `ReferenceError`.

---

### Task 4: Synchronize recovery configuration

**Files:**
- Update: `../config/config/omarchy/plugins/douglasdemoura.chroncal-bar/`

**Step 1: Copy the stable plugin tree**

Synchronize the published plugin while excluding `.git` and `.worktrees`.

Expected: 33-file SHA256 identity with stable and live; recovery `manifest.json` version is `1.1.9`.

**Step 2: Commit and publish**

```bash
git add config/omarchy/plugins/douglasdemoura.chroncal-bar
git commit -m "feat(omarchy): unify Chroncal panel back control"
git push
```
