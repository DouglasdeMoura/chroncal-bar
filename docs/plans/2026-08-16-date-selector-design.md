# Event Date Selector Design

## Problem

The event editor’s date control is a free-text field with placeholder `YYYY-MM-DD`. Mouse users have to type an ISO string. Invalid dates only fail on save. The Chroncal CLI still wants `YYYY-MM-DD`; the editor does not.

## Decision

Replace the date `TextField` with a **Dropdown-style date picker**: a full-width trigger that shows a locale-formatted date, opening an in-panel month grid.

- **Appearance:** the trigger uses the same chrome as the other editor fields. The open grid uses Omarchy popup surface tokens, clock-style month chevrons, today outlined, the selected day filled.
- **Location:** the DATE row becomes full width. TIME and DURATION share the next row so the calendar is not squeezed into the current 42% column.
- **Popup host:** Qt Quick Controls `Popup`, the same overlay pattern as Omarchy `Dropdown`. Not `PopupWindow` / `PopupCard` — those are extra layer-shell surfaces and fight `KeyboardPanel`.
- **Value:** the picker only writes valid `YYYY-MM-DD` into `dateValue`. Chroncal mutation args stay unchanged.
- **Keyboard:** Enter/Space opens; arrows (and `h`/`j`/`k`/`l`) move the highlight; PageUp/PageDown change month; `T` jumps to today; Enter commits; Esc closes the picker before it cancels the editor.
- **Disabled:** timezone-locked edits (`canEditTime` false) show the formatted date and do not open.

No week numbers (those belong to the clock panel). No remaining ISO typing; a committed picker cannot emit an invalid date.

## Rejected alternatives

**Always-visible month grid.** The editor is already 520px tall with Save below the fold. Six week rows would push the form further down.

**Qt `MonthGrid` unstyled.** It exists in Qt Quick Controls Basic, but the default delegate is unthemed and still needs a custom cell. A small tested grid in `Model.js` matches the clock math without depending on Qt in unit tests.

**Nested `PopupCard`.** Chroncal’s agenda is already a `KeyboardPanel`. Another xdg-popup is what Omarchy avoided for keyboard-summoned panels.

**Y/M/D spinboxes.** They are not a calendar and still hide weekday context.

**Keep typing plus a calendar button.** Two sources of truth, invalid ISO strings, and more Esc/focus cases for no extra capability.

## Scope

`Model.js` date-grid helpers, a `DatePicker` component, and `EventEditor` layout plus Esc routing. Time, duration, timezone lock, and mutation args stay as they are.

## Verification

Model tests for ISO parse/format, month grids, and day/month stepping. Existing agenda and URL tests. Live create/edit: the DATE row is a formatted trigger; the grid commits a date; Esc dismisses the grid then the editor; timezone-locked edits stay read-only.
