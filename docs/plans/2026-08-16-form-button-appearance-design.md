# Form Button Appearance Design

## Problem

Cancel, Create, Save, and Save series are Omarchy `Button`s with the default idle chrome: transparent fill, no border. They read as labels, not actions. The settings reset control has the same rest look.

## Decision

Use the kit’s form button: `qs.Ui.Button` with `bordered: true`. That is the same chrome as the gallery “Apply” demo and Speed Test “Run Again”.

- **Cancel:** bordered, transparent rest fill (secondary).
- **Create / Save / Save series:** bordered, plus a light rest fill so the default action is the heavier of the pair.
- **Use default (all calendars):** the same bordered chrome.
- Pass `foreground` and `fontFamily` from the panel. `focusable: true` so Tab shows the shared focus ring. Disabled/busy buttons dim.

Do not restyle `PanelActionButton` header/detail icons, and do not replace `ConfirmDialog` (it already draws bordered action chips).

## Rejected alternatives

**Qt Quick Controls Basic `Button`.** Conflicts with `qs.Ui.Button` and ignores Omarchy tokens.

**Filled accent / primary-color pills.** The kit’s selected/accent fills are for toggles and cursor state, not a one-shot submit.

**Always-visible month-grid-style custom rectangles.** Reimplements Button for no extra behavior.

## Verification

Create and edit footers show two bordered chips; Create/Save is the filled one. Settings reset is a bordered row when calendar selection is customized. Esc, Ctrl+Enter, and busy “Saving…” still work.
