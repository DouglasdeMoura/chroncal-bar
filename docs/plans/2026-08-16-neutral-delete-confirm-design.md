# Neutral Delete Confirmation Design

## Problem

The event-details trash icon uses `Color.urgent`, so it is the only red quick action. Click already opens Omarchy `ConfirmDialog`, but that overlay only covers the content pane under the header, which is easy to miss.

## Decision

- Paint the trash icon with the same `foreground` as join, map, copy, and edit.
- Keep deletion behind `ConfirmDialog`. Move the dialog to fill the whole panel, including the header, so a click cannot look like an immediate delete.
- Leave generated-occurrence deletion in Chroncal; that icon stays disabled.

Do not fork `ConfirmDialog` to restyle its Delete chip. Keyboard `D` / `X` still open the same dialog.

## Verification

A mutable event’s trash icon matches the other actions. Clicking it shows `Delete “…”?` over the panel. Cancel / Esc returns to details. Confirm still runs `event delete`.
