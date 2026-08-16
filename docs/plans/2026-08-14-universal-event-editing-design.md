# Universal Event Editing Design

## Problem

The event-details pencil is enabled only when `Model.canMutateEvent()` returns true: one-off events and stored recurrence overrides. It is disabled for generated occurrences of a recurring master because all expanded dates share the master row’s numeric ID and have no `recurrence_id`.

Passing a generated occurrence directly to the editor is unsafe. Its displayed date and time belong to that occurrence, not to the master. An update by the shared numeric ID could therefore move or rewrite the whole series while appearing to edit one date.

Chroncal’s `--recurrence-id` update path cannot solve this for generated occurrences: it targets an already stored override and returns an error when no override row exists.

## Decision

Enable the pencil for every event with a usable numeric ID or UID.

- One-off events open the existing editor immediately.
- Stored recurrence overrides open the existing editor immediately and continue targeting `UID + --recurrence-id`.
- Generated recurring occurrences load their master with `chroncal event get <id|uid> --output json`, then open the existing editor in explicit whole-series mode.

Whole-series mode displays a visible **Editing entire recurring series** warning. The editor receives the master’s actual start/end values, so schedule edits are based on the series definition rather than the clicked generated occurrence. Saving targets the master ID and updates every occurrence.

The delete action is unchanged. Generated-occurrence deletion has separate instance/series semantics and remains unavailable in this panel.

## State and Data Flow

`Panel.qml` owns edit-loading state separately from mutation state:

- `editorEvent`: event supplied to `EventEditor`; independent from `selectedEvent`, which remains the occurrence shown by Event Details.
- `editingSeries`: true only after a generated occurrence’s master was loaded successfully.
- `editLoadBusy`, stdout, stderr, and requested event key: lifecycle and stale-result protection for the master lookup process.

`startEdit()` behaves as follows:

1. Reject a missing event or an event without an ID/UID.
2. For a directly mutable event, set `editorEvent = selectedEvent`, clear series mode, and open the editor.
3. For a generated recurring occurrence, remember its stable event key, mark loading, and run `chroncal event get` through the existing `chroncal-exec` wrapper.
4. On success, discard the result if the panel closed or selection changed. Otherwise parse the master JSON, preserve calendar display metadata from the occurrence when Chroncal’s `event get` result omits it, set `editorEvent`, enable series mode, and open the editor.
5. On failure or invalid JSON, remain in Event Details and show the returned error.

Canceling the editor clears `editorEvent` and series mode, returning to the originally selected occurrence. Saving uses `editorEvent`, not `selectedEvent`.

## Model Contracts

Add explicit model predicates rather than weakening the existing mutation guard:

- `canEditEvent(event)`: true when an event has a usable ID or UID.
- `isGeneratedRecurringEvent(event)`: true for an RRULE/RDATE master occurrence with no `recurrence_id`.

`canMutateEvent()` remains the direct-mutation and delete guard.

`eventMutationArgs()` accepts an explicit whole-series option. It may update a generated recurring event only when that option is true and the event has a valid master target. The same event without explicit series authorization still returns no command. This keeps accidental master updates fail-closed.

## UI

`EventDetails.qml` separates edit eligibility from delete eligibility:

- Pencil enabled when not busy and `canEditEvent(eventData)`.
- Pencil tooltip is **Edit recurring series** for generated occurrences and **Edit event** otherwise.
- Delete retains the existing `canMutateEvent()` gate.
- The current explanation changes from directing all generated occurrences to Chroncal to explaining that the pencil edits the entire series while deletion remains available in Chroncal.

`EventEditor.qml` receives `editingSeries` and renders the warning above the form. Existing fields, validation, timezone safety, save handling, and keyboard behavior remain unchanged.

## Error Handling

- Missing identity: pencil disabled.
- Missing Chroncal executable: master load does not start; details show an actionable error.
- Non-zero `event get`: details show stderr/stdout and remain open.
- Invalid or identity-mismatched JSON: reject the result and remain on details.
- Selection changed, panel closed, or request superseded: discard the stale result without opening the editor.
- Save failure: existing mutation error handling keeps the editor open.

## Verification

Model tests cover edit eligibility, generated recurrence detection, default rejection of generated occurrences, explicit series authorization, and master targeting.

QML-facing behavior is covered by focused process/state tests or extracted pure helpers where practical, plus existing agenda and URL suites. Live verification must show:

1. A generated recurring occurrence has an enabled pencil.
2. Clicking it opens the editor with **Editing entire recurring series**.
3. The editor shows the master’s actual schedule rather than the selected expanded occurrence’s schedule.
4. Cancel returns to the selected occurrence.
5. One-off and stored-override edit paths remain unchanged.
6. No new Chroncal QML runtime errors appear.
