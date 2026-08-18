# In-plugin account and calendar setup Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Let Chroncal Bar create accounts and calendars, manage hide/default/email, sync, and import iCal, matching Chroncal’s Calendars manager. Fill Chroncal CLI gaps first.

**Architecture:** Chroncal CLI remains the source of truth. Enrich calendar JSON, add hide/show and credential/reauth/account-scoped sync, send OAuth banners to stderr. The bar adds nested Settings subviews and an empty-state setup path. Secrets travel only as process environment.

**Tech Stack:** Go Chroncal CLI tests, Qt 6 QML, Omarchy form widgets, Bun `tests/test-model.js`, bash agenda adapter tests.

**Constraints:** Chroncal work stays in `/home/doug/github.com/douglasdemoura/tcal/.worktrees/account-setup-cli` on `feat/account-setup-cli`. Bar work stays in `/home/doug/github.com/douglasdemoura/chroncal-bar/.worktrees/account-setup` on `feat/account-setup`. Skip formatters, linters, and project-wide suites; Main validates later. Do not bump `VERSION` or `manifest.json`. Do not commit on `master`/`main`. Implementers must not tag or live-deploy.

---

### Task 1: OAuth and secret prompts on stderr

**Repo:** Chroncal (`feat/account-setup-cli`)

**Files:**
- Modify: `internal/auth/google.go`
- Modify: `cmd/chroncal/calendar_remote.go`
- Test: `internal/auth/google_flow_test.go` (or new `google_banner_test.go`)
- Test: `cmd/chroncal/account_cli_test.go` if an OAuth/json test exists; otherwise add a unit test around `flowBanner` destination

**Step 1: Write the failing test**

Assert `GoogleOAuthFlow` / `flowBanner` is written to stderr, not stdout. If the banner helper is unexported, test through a seam or export a `bannerWriter io.Writer` defaulting to `os.Stderr`.

Also assert `readBasicPassword` with `CHRONCAL_PASSWORD` set does not write to stdout.

**Step 2: Run test to verify it fails**

Run: `go test ./internal/auth ./cmd/chroncal -count=1 -timeout 120s -run 'TestGoogleOAuth|TestReadBasicPassword|TestAccountAdd'`

Expected: FAIL because banner still uses `fmt.Print`.

**Step 3: Minimal implementation**

In `GoogleOAuthFlow`, `fmt.Fprint(os.Stderr, flowBanner(...))`. Password/token/secret prompts already print to stdout via `fmt.Print("Password: ")` — send those to stderr too.

**Step 4: Run tests**

Run: `go test ./internal/auth ./cmd/chroncal -count=1 -timeout 180s`

Expected: PASS

**Step 5: Commit**

```bash
git commit -m "fix(cli): keep OAuth banners off JSON stdout"
```

---

### Task 2: Enrich calendar list JSON

**Repo:** Chroncal

**Files:**
- Modify: `cmd/chroncal/output.go` (`jsonCalendar`, `toJSONCalendar`)
- Modify: `cmd/chroncal/calendar.go` if List/Get need account names / hidden
- Test: `cmd/chroncal/calendar_cli_test.go`

**Step 1: Write the failing test**

Create a local calendar, set owner email, assert JSON includes `id`, `name`, `color`, `owner_email`, `is_default`, `hidden` (false), and omits `account_id` when local.

Create/link an account calendar in the existing account CLI test helper if one exists; assert `account_id`, `account_name`, `remote_url`, `remote_access`, `last_sync_at` keys exist.

**Step 2: Run test — expect FAIL** (`account_id` missing)

**Step 3: Implementation**

Extend `jsonCalendar`. `toJSONCalendar` maps `AccountID` with `omitempty`, `RemoteURL`, `RemoteAccess`, `LastSyncAt`, `LastSyncError`. Resolve `account_name` from `a.Accounts` in list/get commands (pass account name into `toJSONCalendar` or a richer helper). Set `hidden` from `config.LoadUIState().HiddenCalendars`.

Do not include ctag/sync token.

**Step 4: `go test ./cmd/chroncal -count=1 -timeout 180s` PASS**

**Step 5: Commit** `feat(calendar): include account and hidden in JSON`

---

### Task 3: `calendar hide` and `calendar show`

**Repo:** Chroncal

**Files:**
- Modify: `cmd/chroncal/calendar.go`
- Test: `cmd/chroncal/calendar_cli_test.go`
- Maybe: `internal/config/state.go` if a helper is cleaner

**Step 1: Failing tests**

```
chroncal calendar hide <id> --output json
```

JSON `hidden` is true. State file `hidden_calendars` contains the id. `calendar show` removes it. Unknown id is `invalid_input`. Hide is idempotent.

**Step 2: FAIL** (`unknown command hide`)

**Step 3: Implementation**

Subcommands `hide` and `show` resolving `id|name` like `update`. Load UI state, add/remove id, `SaveUIState`. Print `toJSONCalendar` with hidden set.

**Step 4: Tests PASS**

**Step 5: Commit** `feat(calendar): hide and show from the CLI`

---

### Task 4: `account credentials`

**Repo:** Chroncal

**Files:**
- Modify: `cmd/chroncal/account.go`
- Test: `cmd/chroncal/account_cli_test.go`
- Reuse TUI rotation contract: broken keyring still rotates

**Step 1: Failing test**

Add a basic account with `CHRONCAL_PASSWORD=old`. Run `account credentials <id>` with `CHRONCAL_PASSWORD=new`. A later sync or credential load sees the new password. OAuth account must refuse this command. Missing env on non-TTY fails without writing. `--output json` prints the account without secrets.

**Step 2: FAIL** (`unknown command credentials`)

**Step 3: Implementation**

`chroncal account credentials <name|id>`. Switch on `auth_type`: basic → `CHRONCAL_PASSWORD`, bearer → `CHRONCAL_BEARER_TOKEN`. Store via existing `Accounts.StoreCredential`. Do not change server/username/auth type.

**Step 4: Tests PASS**

**Step 5: Commit** `feat(account): rotate basic and bearer credentials`

---

### Task 5: `account reauth`

**Repo:** Chroncal

**Files:**
- Modify: `cmd/chroncal/account.go`
- Test: `cmd/chroncal/account_cli_test.go` with OAuth seams (`auth.GoogleOAuthFlow` var if needed)

**Step 1: Failing test**

Stub `GoogleOAuthFlow` to return tokens. `account reauth <id> --output json` stores access/refresh. Empty refresh token keeps previous refresh. Basic account refuses reauth.

**Step 2: FAIL**

**Step 3: Implementation**

`chroncal account reauth <name|id> [--oauth-client-id]`. Optional `GOOGLE_CLIENT_SECRET` overrides stored secret. Banner already on stderr from Task 1.

**Step 4: Tests PASS**

**Step 5: Commit** `feat(account): reauth OAuth accounts from the CLI`

---

### Task 6: `sync run --account`

**Repo:** Chroncal

**Files:**
- Modify: `cmd/chroncal/sync.go`
- Test: `cmd/chroncal/sync_cli_test.go`

**Step 1: Failing test**

`--account` and `--calendar` together fail. `--account` of a known account runs (or attempts) only that account’s calendars. JSON shape unchanged.

**Step 2: FAIL**

**Step 3: Implementation**

Flag `--account`. Resolve like other account commands. Iterate `ListByAccount`. Mutual exclusion with `--calendar`.

**Step 4: Tests PASS**

**Step 5: Commit** `feat(sync): run CalDAV sync for one account`

Also update Chroncal `README.md` CalDAV / Calendars / Sync sections for hide, credentials, reauth, `--account`, and JSON fields. Commit `docs: document account setup CLI for the bar` if the README change is large; otherwise fold into this commit.

---

### Task 7: Bar model — setup command args

**Repo:** Chroncal Bar

**Files:**
- Modify: `tests/test-model.js`
- Modify: `Model.js`

**Step 1: Failing tests** (append to `test-model.js`)

```js
assert.deepEqual(model.accountAddArgs({
  name: "Work",
  server: "https://cal.example.com/dav/",
  username: "alice",
  auth: "basic"
}), ["account", "add", "--server", "https://cal.example.com/dav/", "--username", "alice", "--auth", "basic", "--output", "json", "--", "Work"]);

assert.deepEqual(model.accountAddEnv({ auth: "basic", password: "secret" }), { CHRONCAL_PASSWORD: "secret" });
assert.deepEqual(model.accountAddEnv({ auth: "bearer", token: "tok" }), { CHRONCAL_BEARER_TOKEN: "tok" });
assert.deepEqual(model.accountAddEnv({ auth: "oauth2", clientSecret: "goc" }), { GOOGLE_CLIENT_SECRET: "goc" });

assert.ok(model.validateAccountForm({ name: "Work", server: "https://cal.example.com/dav/", username: "alice", auth: "basic", password: "x" }).length === 0);
assert.ok(model.validateAccountForm({ name: "", server: "", username: "", auth: "basic", password: "" }).length > 0);
assert.ok(model.validateAccountForm({ name: "G", server: "http://example.com", username: "a", auth: "basic", password: "x", allowInsecure: false }).some(e => /http|insecure/i.test(e)));
assert.ok(model.validateAccountForm({ name: "G", server: "", username: "you@x.com", auth: "oauth2", clientId: "id.apps.googleusercontent.com", clientSecret: "s" }).length === 0);
assert.equal(model.defaultAccountServer("oauth2"), "https://apidata.googleusercontent.com/caldav");

assert.deepEqual(model.calendarCreateArgs({ title: "Personal", color: "#3B82F6", email: "me@x.com" }), ["calendar", "create", "--color", "#3B82F6", "--email", "me@x.com", "--output", "json", "--", "Personal"]);
assert.deepEqual(model.calendarHideArgs({ id: 4 }), ["calendar", "hide", "4", "--output", "json"]);
assert.deepEqual(model.calendarShowArgs({ id: 4 }), ["calendar", "show", "4", "--output", "json"]);
assert.deepEqual(model.accountRemoveArgs({ id: 3 }), ["account", "remove", "3", "--yes", "--output", "json"]);
assert.deepEqual(model.syncRunAccountArgs({ id: 3 }), ["sync", "run", "--account", "3", "--output", "json"]);
assert.deepEqual(model.icalImportArgs({ path: "/tmp/a.ics", calendar: "Work" }), ["ical", "import", "/tmp/a.ics", "--calendar", "Work", "--output", "json"]);
```

`--` before names that can start with `-`. Include `--allow-insecure` only when true. `account calendars set` args take selected paths and optional default.

**Step 2:** `TZ=UTC bun tests/test-model.js` → `TypeError: model.accountAddArgs is not a function`

**Step 3:** Implement the helpers next to `eventMutationArgs`. Do not spawn processes.

**Step 4:** Tests PASS

**Step 5: Commit** `feat(model): build account and calendar setup args`

---

### Task 8: Agenda adapter uses calendar JSON hidden

**Repo:** Chroncal Bar

**Files:**
- Modify: `scripts/chroncal-bar-agenda`
- Modify: `tests/test-agenda.sh`
- Modify: `tests/fixtures` if calendar JSON needs `hidden`

**Step 1:** Fixture calendar with `"hidden": true` is omitted from events and marked hidden in `calendars[]` even when `state.json` is empty. Keep `state.json` union so old Chroncal still works: hidden if JSON says so **or** state file lists the id.

**Step 2:** FAIL

**Step 3:** jq: `hidden: ((.hidden == true) or (($hidden_calendar_ids | index($calendar.id)) != null))`. Filter events with the same predicate.

Pass through `account_id`, `account_name`, `remote_url`, `remote_access`, `last_sync_at`, `last_sync_error`, `is_default`, `owner_email` on each calendar object (empty-string defaults).

**Step 4:** `tests/test-agenda.sh` PASS

**Step 5: Commit** `feat(agenda): pass account metadata and hidden`

---

### Task 9: Empty-state setup actions

**Repo:** Chroncal Bar

**Files:**
- Modify: `Panel.qml`
- Modify: `README.md`
- Maybe: `components/ShortcutHelp.qml` only if a new key is added (do not add a key; buttons are enough)

**Step 1:** No isolated test. Implementation: when `status === "ok" && calendars.length === 0`, show setup copy and two bordered buttons (Add account / New calendar) that open the editors from Task 10/11. When calendars exist and groups are empty, keep **No upcoming events**. Unavailable stays unchanged.

**Step 2:** Manual/live later. Implement now.

**Step 3–5:** Commit `feat(agenda): offer setup when no calendars exist`

If the editors do not exist yet, wire signals/`showingSetup` placeholders so Task 10 fills them. Prefer implementing Task 9 after Task 10 if that avoids a dead button. **If so, skip this commit and fold the empty state into Task 12.**

Preferred order: build editors first (Tasks 10–11), then empty state + settings list (Task 12).

---

### Task 10: Local calendar create / edit / delete / hide / default / email

**Repo:** Chroncal Bar

**Files:**
- Create: `components/CalendarEditor.qml`
- Modify: `Panel.qml`
- Modify: `README.md`

**Step 1:** Editor form: name, color (text hex), description, email, default toggle (create only when other calendars exist; edit uses **Set as default** button). Hide toggle on edit. Delete / Keep local on edit.

Panel: `runMutation` already exists. Add `runSetupMutation(args, kind, env)` identical but env-capable (env null for calendar create). On success: `refresh()`, `actionStatus`, stay in settings/calendars list (do not jump to agenda). Delete uses `DeleteConfirm`. Default delete asks which calendar to `--promote`.

**Step 2:** Live QA later. `bash -n` not applicable to QML.

**Step 3:** Follow EventEditor patterns: `Binding` if using Dropdown/NumberField that self-assign. `TextField` for name/email/color.

**Step 4:** `TZ=UTC bun tests/test-model.js && tests/test-agenda.sh`

**Step 5: Commit** `feat(settings): create and edit local calendars`

---

### Task 11: Add account form and inspector

**Repo:** Chroncal Bar

**Files:**
- Create: `components/AccountEditor.qml`
- Create: `components/AccountDetails.qml`
- Modify: `Panel.qml`

**Add account:** TUI fields. Auth dropdown rebuilds secret vs OAuth client fields. Submit uses `accountAddArgs` + `accountAddEnv`. Busy: “Signing in…” / “Waiting for Google authorization…”. Kill process on Esc/back.

**Inspector:** rename (`account update --name`), sync now, update credentials / reauth, remove (`--yes`), manage calendars (Task 12).

Credentials form: password/token only. `account credentials` / `account reauth` with env.

**Step 5: Commit** `feat(settings): add and manage CalDAV accounts`

---

### Task 12: Settings calendar list, discovery set, empty state, iCal import

**Repo:** Chroncal Bar

**Files:**
- Modify: `components/CalendarSettings.qml`
- Create: `components/AccountCalendars.qml` (discovery checkboxes)
- Create: `components/IcalImport.qml` or a small form in settings
- Modify: `Panel.qml`
- Modify: `components/ShortcutHelp.qml` only if needed
- Modify: `README.md` — remove “account management remains in Chroncal”; document hide vs included

**CALENDARS** section at the top of settings: grouped list from `agendaData.calendars` + `account list` if needed. If account list is a separate fetch, add `scripts/chroncal-bar-accounts` **or** extend `chroncal-bar-agenda` to include `"accounts": [...]` from `account list --output json`. Prefer extending the agenda adapter so one refresh hydrates both (timeout still 10s; account list is cheap).

Discovery: `account calendars list --output json` via a Process; MultiSelect-like checkboxes; save `account calendars set --yes`.

Empty state buttons from Task 9.

iCal: path + calendar dropdown + import.

**Step 5: Commit** `feat(settings): manage calendars, discovery, and iCal`

---

### Task 13: Sync status and conflicts in settings

**Repo:** Chroncal Bar

**Files:**
- Modify: `components/CalendarSettings.qml` or `components/SyncStatus.qml`
- Modify: `Panel.qml`
- Modify: `Model.js` + tests for `syncResolveArgs`

Show last error on calendar rows from agenda JSON. A **Sync** button on the account heading. Conflicts: if `sync conflicts --output json` is non-empty, list with Keep local / Keep server.

**Step 5: Commit** `feat(settings): sync accounts and resolve conflicts`

---

### Task 14: README + shortcut help copy

**Repo:** Chroncal Bar

Update Features, Configure, and the sentence that says account management remains in Chroncal. Document:

- Empty-state setup
- Settings CALENDARS manager
- Hide vs Included
- Secrets never stored in `shell.json`
- Chroncal 0.7.8+ (do not invent a version; say “Chroncal with account setup CLI” / local master until tagged)

**Commit** `docs: document in-plugin account and calendar setup`

---

## Cross-cutting Panel rules

- One mutation Process at a time (`mutationBusy`).
- Setup kinds: `account-add`, `account-update`, `account-remove`, `account-credentials`, `account-reauth`, `calendar-create`, `calendar-update`, `calendar-delete`, `calendar-hide`, `calendar-show`, `calendar-default`, `calendars-set`, `sync-run`, `sync-resolve`, `sync-reset`, `ical-import`.
- Success: `actionStatus` short phrase, `refresh()`, keep the calendars manager open except empty-state create which may stay on the new calendar’s editor only if that matches EventEditor (prefer return to list).
- Failure: show Chroncal stderr in the open form (`externalError`), restore focus.
- `runMutation` must accept optional env. Forward through `chroncal-exec` (env is inherited if Process.environment is set on the parent — verify Quickshell Process `environment` property; if missing, wrap in `env KEY=val chroncal-exec ...` **without** putting the secret in `command` if possible). Prefer `Process { environment: [ "CHRONCAL_PASSWORD=..." ] }`. Never log `command` that includes secrets.

## Done when

- Chroncal CLI tasks 1–6 are on `feat/account-setup-cli` with tests.
- Bar tasks 7–14 are on `feat/account-setup` with model/agenda tests.
- Main fast-forwards only when the user asks to merge. No tags.
