# Recurring Delete Options Design

## Problem

The event-details trash control is disabled for generated recurring occurrences. Chroncal already distinguishes three delete targets; the panel should offer them instead of sending people to the TUI.

## Chroncal CLI

Verified against Chroncal 0.7.3 on a throwaway calendar:

- One-off: `event delete <id> --yes`
- Entire series: `event delete <uid|id> --series --yes` (prefer UID so overrides still address the master)
- Stored override: `event delete <uid> --recurrence-id <RFC3339> --yes`
- Generated occurrence: `--recurrence-id` fails until an override row exists. Skipping one date is `event update <id> --exdate …`. `--exdate` replaces the full set, so existing `exdates` must be merged. JSON stores them as a comma-separated UTC list.

Bare `event delete <id>` on a recurring master deletes the whole series. Generated deletes therefore stay fail-closed unless the caller passes `{ occurrence: true }` or `{ series: true }`.

## Decision

Enable the trash control for every event with an ID or UID.

- One-off: existing `Delete “…”?` confirm, then `event delete`.
- Recurring (generated or override): full-panel choices **This occurrence** (default) and **Entire series**, plus Cancel / Esc.
- This occurrence on an override uses `--recurrence-id`.
- This occurrence on a generated date loads the master with `event get`, merges `exdates`, then `event update --exdate`.
- Entire series uses `--series` and the event UID when present.

Keep `canMutateEvent()` as the direct-edit guard. Delete eligibility is `canEditEvent()`.

## Verification

Model tests cover fail-closed generated deletes, series UID targeting, override `--recurrence-id`, and EXDATE merging. Live QA uses the throwaway calendar, not real events.
