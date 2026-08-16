# TUI Delete Choices Design

## Problem

The recurring-delete confirm used This occurrence / Entire series / Cancel. Chroncal's TUI uses This event / This and following / All events.

## Decision

Match Chroncal's TUI labels and scopes.

- One-off: Delete / Cancel, then `event delete <id> --yes`.
- Recurring: **This event**, **This and following**, **All events**, **Cancel**. Default is This event.
- This event: `event delete <uid> --recurrence-id <stamp> --yes` (Chroncal 0.7.4 DeleteInstance).
- This and following: `event delete <uid> --following <stamp> --yes` (DeleteFromInstance).
- All events: `event delete <uid> --series --yes`.
- Stamp is `recurrence_id` when present, otherwise `start_time`.

Requires Chroncal 0.7.4. Generated occurrence deletes no longer merge EXDATEs in the plugin.

## Verification

Model tests cover the three scoped argument arrays and fail-closed missing stamps. Live QA uses a throwaway calendar.
