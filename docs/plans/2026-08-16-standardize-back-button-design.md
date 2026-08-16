# Standardized Back Control Design

## Problem

The Chroncal panel’s back control is a different object on every subview:

| View | Appearance | Location | Position | Click target |
| --- | --- | --- | --- | --- |
| Event details | Caption `ESC  Back` plus a `←` icon button | Header *and* content | Header right (text) and content left (button) | `backToAgenda()` |
| Event editor | `←` `PanelActionButton` plus a `Cancel` text button | Header *and* form footer | Header right and footer right | `cancelEditor()` |
| Settings | Settings cog that morphs into `←` | Header | Header right | `toggleSettings()` |
| Shortcuts | Dedicated `←` `PanelActionButton` | Header | Header right | `toggleHelp()` |

Mouse users cannot form one habit. Keyboard users already have one: `Esc`.

## Decision

Use **one header-right `PanelActionButton` with `←`** on every subview (details, editor, settings, help).

- Appearance: the existing `←` glyph inside `PanelActionButton`, matching Omarchy’s right-edge row-action control.
- Location: the panel header chrome, in `headerActions`. Agenda actions (settings, `?`, `+`, refresh) hide while a subview is open.
- Position: the right side of the header, as the only header action on a subview.
- Click: `cancelEditor()` while the editor is open (edit returns to details; create returns to the agenda); `backToAgenda()` otherwise.
- Tooltip: `Cancel and go back` in the editor; `Back to agenda` on the other subviews. Destinations differ, so the wording stays specific.

`Esc` remains the keyboard equivalent and is unchanged.

## Rejected alternatives

**Left-edge header back.** Conventional in apps, but it would introduce a second header layout. Omarchy documents `PanelActionButton` as a right-edge action, and Chroncal already parks settings, help, create, and refresh on the right. Unifying to that edge is the smaller, host-native change.

**Keep the details-content back and delete the header hint.** That leaves back inside the event title row, below the section label, so it is still not chrome and still absent from settings, help, and the editor.

**Remove the editor `Cancel` button.** `Cancel` is a form action paired with `Save` / `Save series` / `Create`, not navigation chrome. Save can sit below the fold on a 520-tall panel; the footer row stays the form escape. Both the header arrow and `Cancel` call `cancelEditor()`.

**One tooltip for every view.** `Back to agenda` is wrong when canceling an edit (the selected event stays). `Cancel and go back` is wrong on settings and help. Keep the two accurate tooltips.

## Scope

Change `Panel.qml` header actions and remove the duplicate details-content back control. Do not change `Esc` routing, editor save/cancel behavior, or agenda header actions.

## Verification

Existing model, agenda-adapter, and URL tests plus QML/plugin validation. Live-check details, editor, settings, and shortcuts: one `←` in the same header slot; `Esc` still matches it; editor `Cancel` still dismisses the form.
