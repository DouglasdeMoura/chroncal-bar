# Recurrence Authoring Design

## Problem

Chroncal Bar can create events, edit one-offs, and edit a whole series from a generated occurrence. The editor has no Repeat field. Recurrence authoring still lives only in the Chroncal TUI.

## Decision

Add Chroncal’s Repeat field to `EventEditor`, inline.

Presets match the TUI labels and rules:

| Label | RRULE |
| --- | --- |
| None | (empty) |
| Every day | `FREQ=DAILY` |
| Every week | `FREQ=WEEKLY` |
| Every 2 weeks | `FREQ=WEEKLY;INTERVAL=2` |
| Every month | `FREQ=MONTHLY` |
| Every year | `FREQ=YEARLY` |
| Weekdays | `FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR` |
| Custom... | authored in the same form |

A named preset (not None, not Custom) shows **Ends**: Never, After *N* times, or On a date. Custom hides that Ends row and shows its own fields.

## Custom fields

Choosing Custom expands in the event editor:

- Repeat every *N* day / week / month / year
- Weekly **On**: Su–Sa toggles. The event start weekday is on by default
- Monthly **On**: day of month, or the Nth weekday of the start date (TUI uses `(day-1)/7+1`, including a 5th)
- **Ends**: Never, After *N* times, On a date
- One-line rule summary under the custom fields
- No five-date preview

Switching from a named preset into Custom loads that preset’s current rule, including Ends. Switching away from Custom discards the extra fields and uses the new preset.

## Who can change Repeat

- Create: yes
- Edit a one-off: yes (can become a series)
- Edit a whole series (`editingSeries`, master in the editor): yes, including back to None
- Edit a stored override (`recurrence_id` present): Repeat is visible and disabled. The rule belongs to the series

RDATE extras and EXDATE lists stay in Chroncal. This feature only authors `RRULE`.

Timezone-locked events still block date, time, and duration edits. Recurrence stays editable.

## Data flow

`Model.js` owns parse, build, summary, and validation.

- Parse a stored `recurrence_rule` into a form: preset or Custom, interval, frequency, weekdays, monthly mode, ends, count, until
- Build an RFC 5545 string from the form
- `UNTIL` is the last second of the chosen local day, written as UTC `YYYYMMDDTHHMMSSZ` (Chroncal TUI issue #146)
- Empty rule means None

`eventEditorValues` includes a `recurrence` object. `EventEditor.values()` passes it through. `validateEventForm` concatenates recurrence errors. `eventMutationArgs` uses `--recurrence-rule` (not the hidden `--rrule` alias).

Create sends `--recurrence-rule` only when the built rule is non-empty. Edit sends `--recurrence-rule` only when the built rule differs from `event.recurrence_rule`, including an empty value to clear a series. Override updates never send the flag.

`Panel.qml` already submits `values()` through `eventMutationArgs`. It does not grow a second mutation path.

## UI

Repeat sits after the all-day toggle and before Calendar.

Omarchy `Dropdown` for Repeat, frequency, Ends, and monthly On. `NumberField` for interval and After *N*. Weekly On is seven bordered `Button`s. Ends-on-date reuses `DatePicker`.

Escape closes an open dropdown or date picker before canceling the editor. Ctrl+S / Ctrl+Enter still save.

Override edits show the current summary with Repeat `enabled: false`.

## Errors

Invalid Custom state (interval &lt; 1, After count &lt; 1, end date before start) stays in the editor with the existing red validation text. Chroncal stderr on save stays `externalError`. Switching Repeat to None or a named preset clears Custom-only errors.

## Documentation

README stops saying recurrence authoring remains in Chroncal. Features list Repeat presets and Custom. Timezone-sensitive time changes, alarms, availability, sync, and accounts still remain in Chroncal.

## Verification

Model tests cover preset round-trips, Custom weekly/monthly/UNTIL/COUNT, clearing a series, skip-if-unchanged, create without a flag, and fail-closed override updates.

Live QA uses a throwaway calendar:

1. Create Every week
2. Create Custom weekdays with an end date
3. Turn a one-off into a series
4. Change a generated occurrence’s series rule
5. Confirm an override cannot change Repeat
