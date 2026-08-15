# Event-Link Icon Correction Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the misleading shield glyph on the event-link action with the Material Design “open in new” glyph and publish the corrected plugin.

**Architecture:** This is a presentation-only correction in the existing `PanelActionButton`; URL selection and launch behavior remain unchanged. Release it as patch version 1.1.5, deploy the tagged `main` revision to the live plugin, then synchronize the recovery repository.

**Tech Stack:** QML, Qt 6, Nerd Fonts/Material Design Icons, Bun model tests, shell integration tests, Omarchy plugin validation.

---

### Task 1: Correct the Event-Link Glyph

**Files:**
- Modify: `components/EventDetails.qml:229-236`

**Step 1: Confirm the current glyph mapping**

Use the Nerd Fonts cheat sheet to confirm `U+F0483` maps to `nf-md-security` and `U+F03CC` maps to `nf-md-open_in_new`.

Expected: the existing icon is a shield; the replacement is an arrow leaving a square.

**Step 2: Apply the minimal presentation change**

Change only:

```qml
iconText: "󰒃"
```

to:

```qml
iconText: "󰏌"
```

Do not change the tooltip, enabled expression, signal, URL precedence, or keyboard shortcut.

**Step 3: Run focused validation**

Run:

```bash
TZ=UTC bun tests/test-model.js
tests/test-agenda.sh
tests/test-open-url.sh
bash -n scripts/chroncal-exec scripts/chroncal-bar-agenda scripts/chroncal-next-event scripts/chroncal-open-next-event-url
/usr/lib/qt6/bin/qmllint -I /usr/share/omarchy/shell components/EventDetails.qml
omarchy plugin validate .
git diff --check
```

Expected: all tests and validation commands exit zero. `qmllint` may report the repository’s known unresolved-import warnings because the standalone invocation lacks the live Quickshell import context; it must not report a new syntax error at the modified line.

No source-text test should be added for a static glyph choice. The observable contract is visual and is verified against the live panel in Task 3.

**Step 4: Commit the icon correction**

```bash
git add components/EventDetails.qml
git commit -m "fix(ui): correct event-link action icon"
```

### Task 2: Prepare and Publish Patch Version 1.1.5

**Files:**
- Modify: `manifest.json:5`

**Step 1: Bump the manifest version**

Change:

```json
"version": "1.1.4"
```

to:

```json
"version": "1.1.5"
```

**Step 2: Re-run release validation**

Run the complete command set from Task 1 Step 3.

Expected: all executable checks exit zero; no new QML diagnostic references the modified icon line.

**Step 3: Commit release metadata**

```bash
git add manifest.json
git commit -m "chore(release): bump Chroncal Bar to 1.1.5"
```

**Step 4: Publish main and the annotated tag**

```bash
git push origin main
git tag -a v1.1.5 -m "Chroncal Bar v1.1.5"
git push origin v1.1.5
```

Expected: `origin/main` advances to the release commit and tag `v1.1.5` is present remotely.

### Task 3: Deploy and Visually Verify the Live Plugin

**Files:**
- Update by fast-forward: `~/.config/omarchy/plugins/douglasdemoura.chroncal-bar`

**Step 1: Deploy the published revision**

```bash
cd ~/.config/omarchy/plugins/douglasdemoura.chroncal-bar
git pull --ff-only
omarchy-restart-shell
```

Expected: the live checkout reaches the `v1.1.5` commit and the shell restarts successfully.

**Step 2: Open an event’s details**

Open the Chroncal panel, select an event with a conference or event URL, and inspect the action row.

Expected: the first enabled quick action shows `󰏌`, not a shield. Its tooltip remains “Join or open event link.”

**Step 3: Exercise the action**

Click the icon or press `J` while the event-details view is active.

Expected: the existing conference URI or event URL opens through `xdg-open`; the preferred URL remains the conference URI when both fields exist.

**Step 4: Inspect the current shell log**

Search the newest Quickshell log for Chroncal `TypeError`, `ReferenceError`, assignment failures, or unavailable components.

Expected: no new Chroncal runtime errors.

### Task 4: Synchronize and Verify Recovery Configuration

**Files:**
- Modify: `../config/config/omarchy/plugins/douglasdemoura.chroncal-bar/components/EventDetails.qml`
- Modify: `../config/config/omarchy/plugins/douglasdemoura.chroncal-bar/manifest.json`
- Create: `../config/config/omarchy/plugins/douglasdemoura.chroncal-bar/docs/plans/2026-08-14-event-link-icon-design.md`
- Create: `../config/config/omarchy/plugins/douglasdemoura.chroncal-bar/docs/plans/2026-08-14-event-link-icon.md`

**Step 1: Copy the stable plugin files into recovery**

Synchronize the published plugin tree while excluding `.git` and `.worktrees`.

Expected: recovery contains the exact stable source and version 1.1.5.

**Step 2: Run recovery validation**

From the config repository, run the model, agenda-adapter, URL, shell-syntax, and `git diff --check` commands against `config/omarchy/plugins/douglasdemoura.chroncal-bar`.

Expected: every command exits zero.

**Step 3: Commit and publish recovery changes**

```bash
git add config/omarchy/plugins/douglasdemoura.chroncal-bar
git commit -m "fix(omarchy): restore corrected Chroncal link icon"
git push
```

**Step 4: Confirm final state**

Confirm the stable repository, live plugin checkout, and recovery repository are clean and synchronized. Confirm `git describe --tags --exact-match HEAD` reports `v1.1.5` in the stable and live plugin checkouts.
