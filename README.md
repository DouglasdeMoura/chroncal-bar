# Chroncal Bar

An [Omarchy Quattro](https://omarchy.org/) menu-bar calendar powered by [Chroncal](https://github.com/DouglasdeMoura/chroncal).

![Chroncal Bar agenda opened from the Omarchy menu bar](preview.png)

## Features

### Bar

- Shows every overlapping current event, or the next upcoming event.
- Uses relative labels near an event (`in 5m`, `12m left`) and explicit weekday labels for later events (`Mon 09:00`).
- Handles timed, all-day, overlapping, upcoming, and in-progress events.
- Uses Chroncal calendar colors in the label, agenda, and progress indicator.
- Hides itself when no visible event remains in the configured preview window.
- Hovering shows nothing. Left click opens the agenda, middle click opens the next event URL, and right click refreshes.

### Agenda panel

- Groups events under Today, Tomorrow, and later dates.
- Filters hidden calendars and supports per-calendar inclusion.
- Searches titles, descriptions, locations, calendar names, and participants.
- Shows the event date, location, notes, conferencing links, attendees, RSVP state, and who organized the event.
- Turns http(s) URLs in notes into clickable links colored with the Omarchy theme accent.
- Opens Google Meet links as the calendar owner account (`authuser`).
- Wraps long titles instead of cropping them.
- Opens maps from an open-link icon at the end of the location name.
- Shows Join on the left when the event has a link, Edit and Delete on the right, and copy/RSVP confirmations beside Join.
- Optionally shows Open in Chroncal at the end of event details (`chroncal --event`); off by default, with `g` still available.
- Copies complete event details to the clipboard with `p`.
- Creates, edits, and deletes Chroncal events without shell interpolation.
- Preserves omitted fields during edits and never reinterprets unchanged event times.
- Confirms deletion before changing Chroncal data.
- Shows an enabled edit pencil for every event with a usable identity.
- Loads and edits the whole recurring series for generated occurrences.
- Edits stored recurrence overrides as that override only.
- Creates and edits recurrence with Chroncal Repeat presets and inline Custom fields.
- Leaves stored override Repeat rules on the series; open the series editor to change them.
- Deletes this event, this and following, or all events in a recurring series from the panel confirm.
- Replies Yes, Maybe, or No from a Going control on event details when the calendar owner is an invited attendee.
- Offers Add account and New calendar from the empty agenda until a calendar exists.
- Manages calendars from the Settings CALENDARS list: create, edit, hide, default, owner email, per-account grouping, and discovery of remote collections.
- Adds CalDAV accounts (password, bearer token, Google OAuth) and imports iCal files without leaving the bar.
- Syncs an account, resets one calendar's sync state, and resolves conflicts with Keep local or Keep server.
- Included calendars only filter the bar. Hide is a Chroncal UI flag: hidden calendars keep their events but leave the agenda; Settings still lists them so they can be shown again.
- Passes account secrets as process environment for that one Chroncal command; they never appear in argv, logs, or `shell.json`.

This is menu-bar parity, not a replacement for Chroncal's full TUI. Timezone-sensitive time changes, alarms, availability, and the Chroncal service remain in Chroncal.

## Requirements

- Omarchy Quattro
- Chroncal 0.7.4 or newer on `PATH`
- Chroncal with account setup CLI (`feat/account-setup-cli` until merged and tagged) for in-plugin accounts, hide, credentials, reauth, and `sync run --account`
- A Chroncal build that includes `chroncal event rsvp` for Yes/No/Maybe replies (not in 0.7.4)
- A Chroncal build that includes `chroncal --event` to open the TUI on the selected event
- `bash`, `jq`, GNU `date`, and GNU `timeout`
- `xdg-open` for links and maps
- `wl-copy` for copy actions
- `notify-send` for helper errors

Install Chroncal with mise if needed:

```sh
mise use -g github:DouglasdeMoura/chroncal@0.7.4
```

That pin is enough for the rest of the bar. Yes/No/Maybe needs a Chroncal newer than 0.7.4, or a local build of `feat/event-rsvp-cli`. In-plugin account and calendar setup needs Chroncal with account setup CLI (`feat/account-setup-cli` until merged and tagged).

Add accounts and calendars from Settings, or from Add account and New calendar on an empty agenda. The Chroncal TUI remains available:

```sh
chroncal
```

## Install

```sh
omarchy plugin add https://github.com/DouglasdeMoura/chroncal-bar.git --enable
omarchy bar move douglasdemoura.chroncal-bar --section right --after omarchy.tray
```

The second command is optional. It places the widget beside the tray in the right-aligned bar group.

## Use

| Key | Context | Action |
| --- | --- | --- |
| `↑` / `↓`, `j` / `k` | Agenda | Move selection |
| `←` / `→`, `h` / `l` | Agenda | Previous or next day |
| `t` | Agenda | Jump to today's first event |
| `Enter` / `Space` | Agenda | Open selected event |
| `/` | Agenda | Open search |
| `c` | Agenda or details | Create event |
| `e` | Agenda or details | Edit event or recurring series |
| `x` or `Delete` | Agenda or details | Delete this event, this and following, or all events |
| `v` | Event details | Join or open event URL |
| `p` | Event details | Copy event details |
| `g` | Event details | Open this event in Chroncal |
| `y` / `n` / `m` | Event details | RSVP yes, no, or maybe |
| `s` | Agenda | Refresh |
| `C` or `,` | Agenda | Open settings |
| `?` | Agenda | Open shortcut help |
| `Ctrl+S` | Event editor | Save event or series |
| `Esc` or `q` | Any panel view | Back, cancel, or close |

Search opens with `/`. Subviews share one header back arrow. Settings, shortcut help, and Create are the agenda header actions. Refresh happens when the panel opens, on `s`, and on bar right-click. Event-detail buttons cover the rest.

## Configure

Open the agenda and press `C` or `,`, or click the settings cog in the header. Available settings:

- CALENDARS manager: accounts grouped with nested calendars; Add account, New calendar, and Import iCal; Sync on each account; Hide, default, and owner email on a calendar; inspect, rename, credentials, reauth, and remove an account.
- SYNC: last-sync time, pending push, Reset…, and Keep local / Keep server when a calendar has conflicts.
- Days ahead (1–30) and refresh interval.
- Maximum bar-title length and the relative-countdown window.
- Included calendars; all are selected automatically until you customize the selection.
- Show or hide time and title in the bar.
- Include or exclude all-day events.
- Include or exclude events without participants.
- Include or exclude events without a physical location or meeting link.
- Show or hide the Open in Chroncal button on event details (off by default).

Hide is a Chroncal calendar flag: hidden calendars keep their events but leave the agenda. Included calendars are a bar-only filter. Calendar selection has two states. Default mode selects every current calendar and automatically includes calendars added later. The first checkbox change stores an exact custom selection; selecting none hides every event. Use **Use default (all calendars)** to discard the custom selection and return to automatic default mode.

Widget settings persist on the widget entry in `~/.config/omarchy/shell.json`. They can also be changed from the command line:

```sh
omarchy bar set douglasdemoura.chroncal-bar interval 60
omarchy bar set douglasdemoura.chroncal-bar lookaheadDays 7
omarchy bar set douglasdemoura.chroncal-bar showTitle On
omarchy bar set douglasdemoura.chroncal-bar showOpenInChroncal On
omarchy bar set douglasdemoura.chroncal-bar relativeLeadMinutes 10
```

Account passwords, bearer tokens, and OAuth client secrets are never stored in `shell.json`.

Force a refresh:

```sh
omarchy-shell douglasdemoura.chroncal-bar refresh
```

## Runtime and service behavior

The plugin runs inside Omarchy's long-running Quickshell process with your user permissions. Its QML timer starts a one-shot agenda helper at the configured interval; the helper emits one normalized JSON document and exits. The plugin does not start another Quickshell process, install packages, request elevated privileges, or run a remote installer.

Chroncal remains the source of truth. The plugin calls its CLI to read calendar and event data and to perform explicitly requested create, update, delete, account, and sync actions. Helpers also read `~/.local/state/chroncal/state.json` for hidden calendar IDs.

Chroncal's optional `chroncal service run` process is separate. This plugin neither installs nor controls that service.

## Remove

```sh
omarchy plugin remove douglasdemoura.chroncal-bar
```

Removal deletes only the plugin. It does not remove Chroncal, calendar state, or any separate Chroncal service.

## Development

```sh
TZ=UTC bun tests/test-model.js
tests/test-agenda.sh
tests/test-open-url.sh
bash -n scripts/chroncal-exec scripts/chroncal-bar-agenda scripts/chroncal-next-event scripts/chroncal-open-next-event-url
omarchy plugin validate .
/usr/lib/qt6/bin/qmllint -I /usr/share/omarchy/shell \
  BarWidget.qml Panel.qml components/*.qml
```

`qmllint` exits successfully but reports unresolved `qs.Commons` and `qs.Ui` types outside the running Omarchy shell. Runtime smoke tests cover the real plugin host.

## License

[MIT](LICENSE)
