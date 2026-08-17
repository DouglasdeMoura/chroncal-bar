# TUI Shortcut Parity Design

## Problem

Chroncal Bar uses a different keymap from Chroncal's TUI. Shared actions such as create, edit, delete, save, and refresh sit on different letters, so muscle memory does not transfer.

## Decision

Use Chroncal TUI keys for every shared action. Keep Join, Copy, and Open Chroncal on letters the TUI does not use in agenda or event view. Do not add TUI-only features the bar does not already have (duplicate, undo, RSVP, empty days, month/week/day views, trash, sidebar).

Omarchy `PanelKeyCatcher` already owns `h j k l`, arrows, Enter, Space, `x`, Tab, and Esc. The bar must not rebind those letters to other actions.

## Shared actions

| Action | TUI | Bar now | Bar after |
| --- | --- | --- | --- |
| Move | `↑↓` `j/k` | `↑↓` `j/k`, plus `n` `p/b` | `↑↓` `j/k` only |
| Previous / next day | `h/l` `←→` | unused (except delete-confirm cycling) | first event of the previous / next day that has events |
| Today | `t` | `t` | `t` |
| Open | `Enter` / `Space` | `Enter` / `Space` | unchanged |
| Search | `/` | `/` | `/` |
| Create | `c` | `Shift+N` | `c` (agenda or details) |
| Edit | `e` | `E` in details only | `e` from the list or details |
| Delete | `x` / `Delete` | `D` / `X` in details only | `x` / `Delete` from the list or details |
| Refresh | `s` (sync) | `R` | `s` |
| Settings / calendars | `C` | `,` | `C`, keep `,` as an extra |
| Help | `?` | `?` | `?` |
| Save | `Ctrl+S` | `Ctrl+Enter` | `Ctrl+S`, keep `Ctrl+Enter` as an extra |
| Back / close | `Esc` / `q` | `Esc` | `Esc` / `q` |

Day jumps no-op when there is no earlier or later day with events. `e` and `x` from the list act on the highlighted row without opening details first. Delete still opens the existing confirm. `q` matches Esc, including canceling the delete confirm; it does not type into the editor because the key catcher is blocked there.

## Bar-only actions

These letters stay free of TUI agenda/event-view bindings (`y`/`n`/`m` reserved for a later RSVP).

| Action | Now | After | Where |
| --- | --- | --- | --- |
| Join or open event link | `J` | `v` | Details |
| Copy event details | `C` | `p` | Details |
| Open Chroncal | `O` | `g` | Details |

## Removed bar keys

`n`, `p`, `b`, `Shift+N`, `R`, and `D` no longer move, create, refresh, or delete. `D` in the TUI opens recently deleted, which the bar does not have.

## Help and copy

`ShortcutHelp`, the README shortcut table, and header/detail tooltips that mention keys must list the new map. Do not document TUI-only features.

## Verification

Model tests cover previous/next-day first-event lookup. Live QA: `c` creates, `e`/`x` work from the list, `h`/`l` jump days, `s` refreshes, `v`/`p`/`g` run details actions, `Ctrl+S` saves, `q` backs out. Old keys (`n`, `Shift+N`, `R`, `J`, `D`) do nothing or take their new meaning.
