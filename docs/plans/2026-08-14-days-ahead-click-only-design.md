# Days-Ahead and Click-Only Bar Design

## Goal

Let users choose how many days the Chroncal agenda loads from the panel's Settings screen, and keep the top-bar widget silent on hover.

## Behavior

- Add a `Days ahead` numeric field at the top of `AGENDA FILTERS`.
- Persist the value through the existing `lookaheadDays` plugin setting.
- Accept integers from 1 through 30, step 1, default 7.
- Refresh the agenda query immediately after the value changes so the panel and bar preview use the new horizon.
- Set the top-bar widget tooltip to empty. Clicking the widget continues to open the agenda panel.
- Preserve tooltips for controls inside the panel.

## Data Flow

`CalendarSettings` emits `{ lookaheadDays: value }`. `Panel.persistSettings` writes the updated entry through Omarchy's existing `updateEntryInline` path, then schedules `hostWidget.broadcast("refresh")` after the updated settings reach `BarWidget`, refreshing every monitor instance. `BarWidget.refresh` already passes `lookaheadDays` to `chroncal-bar-agenda --days`.

## Boundaries and Errors

The existing adapter remains authoritative and rejects values outside 1–31; the UI and manifest constrain user input to 1–30. Refresh failures continue to use the existing unavailable state. No new process, storage format, or fallback is introduced.

## Verification

- Model or component behavior test covers the persisted `lookaheadDays` value and refresh trigger.
- Existing model and adapter suites remain green.
- Plugin validation and QML lint remain green.
- Live smoke test confirms hover shows no tooltip, click opens the panel, and changing `Days ahead` changes the adapter query/result horizon.
