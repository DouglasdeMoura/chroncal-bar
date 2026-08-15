# Resettable Calendar Selection Design

## Goal

Show every available calendar as selected by default, distinguish an explicit empty selection from the default, preserve a user's custom selection, and provide a clear path back to automatic default behavior.

## State Model

The widget keeps the existing `includedCalendarIds` array and adds `calendarSelectionCustomized`:

- Default mode (`calendarSelectionCustomized: false`): every current calendar is selected. Calendars discovered later are selected automatically.
- Custom mode (`calendarSelectionCustomized: true`): the exact `includedCalendarIds` array is authoritative. An empty array shows no events. Calendars discovered later do not change the selection.
- Existing settings without the new flag remain default mode when `includedCalendarIds` is absent or empty. A pre-existing non-empty array is treated as custom mode.

## Interface

The Included calendars `MultiSelect` receives the effective selection through an external `Binding`, so its internal checkbox mutations cannot detach it from later resets or calendar refreshes: all calendar IDs in default mode, or the persisted IDs in custom mode. Its empty label becomes `No calendars`.

The first checkbox change enters custom mode and persists the exact selected IDs. While custom mode is active, Settings shows a `Use default (all calendars)` action. Activating it clears the stored IDs, disables custom mode, and immediately restores every current calendar.

## Filtering

`Model.filterEvents` receives both the effective IDs and whether selection is customized. Default mode does not apply a calendar filter. Custom mode always applies the filter, including when the selected array is empty.

This preserves the invariant that default mode automatically includes future calendars while custom mode remains stable.

## Verification

- Model tests cover default-all, custom subset, custom empty, existing non-empty migration, and reset-to-default selection derivation.
- Existing agenda filters continue to compose with calendar selection.
- Live Settings initially shows every calendar checked.
- Deselecting every calendar produces no events and `No calendars`.
- `Use default (all calendars)` restores all checks and events.
