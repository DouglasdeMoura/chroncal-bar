# In-plugin account and calendar setup

## Problem

Chroncal Bar can show, search, create, edit, RSVP, and delete events. It cannot stand up Chroncal itself. Settings only filter which already-configured calendars appear on the bar. Account sign-in, local calendar create, owner email, hide, sync, OAuth, and iCal import still require the TUI. An empty database shows **No upcoming events**, not a setup path.

The user asked for the full create-account / add-calendar flux in the plugin, feature parity with Chroncal, and Chroncal CLI work wherever the plugin cannot call a command today.

## Decision

Keep Chroncal as the source of truth. The plugin is a GUI over `chroncal-exec`. It never writes `state.json`, the keyring, or the SQLite database itself.

Mirror the TUI Calendars manager, not Apple Calendar’s iCloud-only wizard:

1. Empty agenda offers **Add account** and **New calendar**.
2. Settings gains a **CALENDARS** manager (accounts grouped, calendars nested) above the existing inclusion filter.
3. Nested subviews cover add-account, calendar edit, account inspector, discovery selection, sync status, and iCal import.
4. Widget filters (lookahead, all-day, Open in Chroncal) stay in Settings. They are display preferences, not Chroncal data.

## Chroncal CLI gaps

These block parity. Build them in Chroncal first. Do not bump `VERSION` until asked.

### 1. Machine-readable OAuth / secrets

`GoogleOAuthFlow` prints the browser banner with `fmt.Print` (stdout). `account add --output json` then emits invalid JSON. Password prompts have the same bug if env vars are missing.

- Print OAuth banners and secret prompts to **stderr**.
- JSON on stdout stays a single object.
- Plugin still passes secrets only as env: `CHRONCAL_PASSWORD`, `CHRONCAL_BEARER_TOKEN`, `GOOGLE_CLIENT_SECRET`. Never as flags.

### 2. Richer `calendar list --output json`

`jsonCalendar` omits fields the TUI inspector shows. Add:

| Field | Source |
| --- | --- |
| `account_id` | `Calendar.AccountID` (omit empty) |
| `account_name` | joined account display name |
| `remote_url` | `Calendar.RemoteURL` |
| `remote_access` | `Calendar.RemoteAccess` |
| `last_sync_at` | `Calendar.LastSyncAt` |
| `last_sync_error` | `Calendar.LastSyncError` |
| `hidden` | `config.LoadUIState().HiddenCalendars` |

`Get` uses the same shape. Existing keys stay stable.

### 3. Hide / show

Hidden calendars live in TUI `state.json`. There is no CLI. Add:

```
chroncal calendar hide <id|name>
chroncal calendar show <id|name>
```

They update `HiddenCalendars` atomically via `SaveUIState`. JSON prints the calendar with `hidden`. The bar adapter can then stop reading `state.json` once list JSON includes `hidden` (keep the current file read as a fallback until that ships).

### 4. Rotate credentials

The TUI can **Update Credentials…** (basic/bearer) and **Sign In Again…** (OAuth). The CLI cannot change a stored secret without `calendar update --remote-url` (which re-links one collection). Add:

```
chroncal account credentials <name|id>
chroncal account reauth <name|id> [--oauth-client-id ID]
```

`credentials` reads `CHRONCAL_PASSWORD` or `CHRONCAL_BEARER_TOKEN` from the environment according to `auth_type`. It does not change server URL, username, or auth type. A broken keyring entry still rotates (TUI contract). Failure leaves the previous secret.

`reauth` runs `GoogleOAuthFlow` and stores the new token triple. Empty refresh token keeps the previous refresh token.

### 5. Sync by account

`sync run --calendar NAME` exists. TUI **Sync Now** is account-scoped. Add `--account <name|id>` that runs the linked calendars in series (same as TUI). Mutually exclusive with `--calendar`.

## Plugin surfaces

Panel width stays `Style.space(430)`. Reuse Omarchy `TextField` (`password: true` for secrets), `Dropdown`, `Toggle`, `Button`, `DeleteConfirm`.

### Empty agenda

When `agendaData.status === "ok"` and `calendars.length === 0`, replace **No upcoming events** with copy plus **Add account** / **New calendar**. When calendars exist but no remaining events, keep **No upcoming events**.

### Settings → CALENDARS

Grouped list:

- Account heading: name, username, auth type, **Open**
- Calendar rows: color, name, Default/Hidden/Read-only badges, last-sync error if any
- Local calendars under **On this computer**
- Footer: **Add account**, **New calendar**, **Import iCal**

The existing **Included calendars** MultiSelect stays below this list. It is a bar filter, not Chroncal hide.

### Add account (TUI `NewAccountDialogModel`)

Fields: name, server URL, username, auth (`basic` / `bearer` / `oauth2`). Basic shows password. Bearer shows token. OAuth shows client ID + client secret and hides password. **Allow HTTP** auto-on for localhost, warning otherwise.

Submit runs `account add --output json` with env secret. Show **Signing in…** / **Waiting for Google…**. Success returns to the calendars list and refreshes the agenda. Zero usable collections is already rolled back by Chroncal; show the error.

Google convenience: placeholder server `https://apidata.googleusercontent.com/caldav` when auth is oauth2 and server is empty. Do not invent a bundled OAuth client.

### New calendar

Name (required), color, description, owner email, **Set as default** when another calendar already exists. First calendar is auto-default in Chroncal. No remote flags here; remotes belong to accounts.

### Calendar inspector

Edit name, color, description, owner email. Toggles: default (`calendar set-default`), display (`calendar show` / `hide`). Destructive: **Keep local** (`calendar update --disconnect-remote`) when `account_id` is set; **Delete** (`calendar delete --yes`, `--promote` when deleting the default). Read-only remotes cannot push metadata; still allow local name/color/email/hide.

### Account inspector (TUI Account Settings)

Identity (provider/server/username/count). Actions: Manage calendars, Sync now, Rename, Sign in again / Update credentials, Remove account (`account remove --yes`, keeps local copies).

### Manage calendars

`account calendars list --output json`, checkboxes for `importable` collections, disabled rows for unsupported/missing. Save uses `account calendars set --yes` with `--calendar` paths (or `--all` / `--none`). Deselecting the default requires `--default`. Confirm copy matches Chroncal: remote collections are not deleted; `--none` also removes the empty account.

### Sync

Account **Sync now** → `sync run --account`. Settings can show `sync status --output json` (last sync, pending push, conflicts). Conflicts: list + **Keep local** / **Keep server** (`sync resolve --pick`). Reset stays behind a confirm (`sync reset --calendar`).

### iCal import

Path field + destination calendar + `ical import --calendar`. No file picker required; paste a path. 8 MiB / 1 MiB attachment limits stay in Chroncal.

## Secrets and processes

Extend `runMutation` to accept `environment`. Put secrets only in `Process.environment`. Never argv, never `actionStatus`, never logs. Clear the QML password field after spawn. `chroncal-exec` must forward the extra env (it already execs Chroncal).

OAuth: Chroncal opens the browser (`xdg-open`) from the subprocess. The panel shows waiting copy until JSON arrives or the process fails. Esc cancels by killing the process if still running.

## Edge cases

| Case | Behavior |
| --- | --- |
| No Chroncal binary | Existing unavailable empty state; no add buttons that would fail |
| Duplicate calendar name | Chroncal error in the form |
| Last calendar delete | Chroncal refuses or requires promote; show stderr |
| Default delete | Pass `--promote` from a picker of remaining calendars |
| Read-only collection | Import allowed; sync pull-only; hide Keep-local vs delete still work |
| HTTP non-localhost | Require Allow HTTP |
| Empty password | Client validation before spawn |
| OAuth without client id/secret | Client validation |
| Keyring missing | Chroncal `--allow-plaintext` is a Chroncal config concern; plugin does not add a toggle |
| Hidden vs Included | Hide is Chroncal sidebar visibility (events leave the bar). Included is the widget MultiSelect. Both can hide an event; document the difference |
| Work calendar empty owner email | Calendar inspector can set `--email` so RSVP appears |
| Long initial sync | Keep panel open; busy + status; do not close on submit |
| `account add` sync fails after import | Chroncal already reports account created but sync failed; show that string; list still refreshes |
| Ambiguous calendar name on set | Use remote `path`, not display name |
| Plugin inclusion custom selection | New calendars from account add are absent from a customized MultiSelect until the user includes them (current default-mode vs custom-mode contract). After add, if still in default mode they appear automatically |

## Out of scope

- Alarms, SMTP, `chroncal service install`, TUI themes, `config.toml`
- Sidebar drag-reorder (`calendar` display order) unless a CLI already exists
- Moving a local calendar onto an existing account collection (TUI transfer dialog)
- Bundled Google OAuth client
- Writing secrets into `shell.json`

## Verification

Chroncal: `go test ./cmd/chroncal ./internal/calendar ./internal/config ./internal/auth ./internal/account` during tasks; `go test ./...` before any version tag.

Bar: `TZ=UTC bun tests/test-model.js`, `tests/test-agenda.sh`, `tests/test-open-url.sh`, `bash -n` on scripts. Live QA: empty DB → add local calendar → add basic Radicale/Nextcloud account → hide one calendar → set owner email → RSVP appears → Google OAuth if credentials exist → remove account keeps local copy.
