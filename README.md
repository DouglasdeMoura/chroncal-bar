# Chroncal Bar

An [Omarchy Quattro](https://omarchy.org/) bar widget that shows the next remaining event from [Chroncal](https://github.com/DouglasdeMoura/chroncal).

![Chroncal Bar showing an upcoming event in the Omarchy bar](preview.png)

## Features

- Shows the next visible event that has not ended.
- Uses relative labels near an event (`in 5m`, `12m left`).
- Handles all-day, overlapping, upcoming, and in-progress events.
- Uses Chroncal calendar colors in the label and tooltip.
- Hides itself when no events remain today or Chroncal is unavailable.
- Left click opens Chroncal; middle click opens the event URL; right click refreshes.

## Requirements

- Omarchy Quattro
- `chroncal` on `PATH`
- `bash`, `jq`, GNU `date`, and GNU `timeout`
- `xdg-open` and `notify-send` for middle-click behavior

Install Chroncal with mise if needed:

```sh
mise use -g github:DouglasdeMoura/chroncal@0.7.0
```

Authenticate and configure calendars in the Chroncal TUI before expecting events on the bar:

```sh
chroncal
```

## Install

```sh
omarchy plugin add https://github.com/DouglasdeMoura/chroncal-bar.git --enable
omarchy bar move douglasdemoura.chroncal-bar --section right --after omarchy.tray
```

The second command is optional. It places the widget beside the tray in the right-aligned bar group.

## Configure

The default refresh interval is 60 seconds. Change it through the Omarchy bar settings, or set `interval` on the widget entry in `~/.config/omarchy/shell.json`:

```json
{
  "id": "douglasdemoura.chroncal-bar",
  "interval": 60
}
```

Force a refresh:

```sh
omarchy-shell douglasdemoura.chroncal-bar refresh
```

## Runtime and service behavior

The plugin runs inside Omarchy's long-running Quickshell process, with your user permissions. Its QML timer starts a one-shot helper every 60 seconds; the helper prints one JSON object and exits. The plugin does not start another Quickshell process, install packages, request elevated privileges, or run a remote installer.

Chroncal's optional `chroncal service run` process is separate. This plugin neither installs nor controls that service.

The helpers read:

- Chroncal event and calendar data through the `chroncal` CLI.
- `~/.local/state/chroncal/state.json` for hidden calendar IDs.

Middle click may launch `xdg-open` for the selected event URL. Left click launches Chroncal in Omarchy's floating terminal.

## Remove

```sh
omarchy plugin remove douglasdemoura.chroncal-bar
```

Removal deletes only the plugin. It does not remove Chroncal, calendar state, or any separate Chroncal service.

## Development

```sh
PLUGIN_DIR="$HOME/.config/omarchy/plugins/douglasdemoura.chroncal-bar"
QMLLINT="${QMLLINT:-/usr/lib/qt6/bin/qmllint}"

omarchy plugin validate "$PLUGIN_DIR"
"$QMLLINT" -I "$OMARCHY_PATH/shell" "$PLUGIN_DIR/BarWidget.qml"
```

## License

[MIT](LICENSE)
