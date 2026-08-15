# Event-Link Icon Design

## Problem

The event-details action labeled “Join or open event link” uses `U+F0483`. In the installed Nerd Fonts mapping, that codepoint is `nf-md-security`, so the button renders as a shield and does not communicate its action.

## Decision

Replace the glyph with Material Design `open_in_new`, `󰏌` (`U+F03CC`). It matches the plugin’s existing Material Design icon family and correctly describes both supported destinations: conference links and ordinary event URLs.

A video-camera glyph would overstate meeting semantics for ordinary URLs. A chain-link glyph describes the data but not the external-open action.

## Scope

Change only the `iconText` of the event-link `PanelActionButton` in `components/EventDetails.qml`.

Keep unchanged:

- Tooltip text: “Join or open event link”
- `J` keyboard shortcut
- Conference-link-before-event-URL precedence
- Disabled state when no URL exists
- Click handling and URL launching

## Verification

Run the existing model, agenda-adapter, and URL integration tests; validate shell syntax, QML, and the plugin manifest; then deploy and visually verify the event-details action in the live Omarchy panel.
