pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model
import "components"

Panel {
  id: root
  moduleName: "douglasdemoura.chroncal-bar"
  ipcTarget: "douglasdemoura.chroncal-bar"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root
  readonly property var agendaData: hostWidget ? hostWidget.filteredAgenda : ({ status: "loading", events: [] })
  onAgendaDataChanged: root.hydrateSelectedEvent()
  property string searchQuery: ""
  property bool searching: false
  readonly property var visibleEvents: Model.searchEvents(agendaData.events || [], searchQuery)
  readonly property var groups: Model.groupEvents(visibleEvents, agendaData.generated_at || new Date().toISOString())
  readonly property var calendars: hostWidget ? (hostWidget.agendaData.calendars || []) : []
  property string selectedEventKey: ""
  property var selectedEvent: null
  property string editorMode: ""
  readonly property bool showingEditor: editorMode !== ""
  readonly property bool showingDetails: selectedEvent !== null && !showingEditor
  readonly property var accounts: hostWidget ? ((hostWidget.agendaData || {}).accounts || []) : []
  property string calendarEditorMode: ""
  property var calendarEditorTarget: null
  readonly property bool showingCalendarEditor: calendarEditorMode !== ""
  property bool showingAccountEditor: false
  property var accountDetailsTarget: null
  readonly property bool showingAccountDetails: accountDetailsTarget !== null
  property bool showingAccountCalendars: false
  property var accountCalendarsAccount: null
  property var discoveryRows: []
  property bool discoveryBusy: false
  property bool discoveryCancelPending: false
  property string discoveryError: ""
  property string discoveryStdoutText: ""
  property string discoveryStderrText: ""
  property var syncStatusRows: []
  property var syncIssueRows: []
  property bool syncStatusBusy: false
  property bool syncIssuesBusy: false
  readonly property bool syncStateBusy: syncStatusBusy || syncIssuesBusy
  property string syncStateError: ""
  property bool syncStatusLoadOk: false
  property bool syncIssuesLoadOk: false
  property string syncStatusStdoutText: ""
  property string syncStatusStderrText: ""
  property string syncIssuesStdoutText: ""
  property string syncIssuesStderrText: ""
  property var pendingSyncResetCalendar: null
  property bool syncFetchQueued: false
  property bool showingIcalImport: false
  property bool showingSettings: false
  property bool showingHelp: false
  readonly property bool showingSubview: showingDetails || showingEditor || showingCalendarEditor
    || showingAccountEditor || showingAccountDetails || showingAccountCalendars || showingIcalImport
    || showingSettings || showingHelp
  property bool mutationBusy: false
  property string mutationKind: ""
  property string mutationError: ""
  property string mutationStdoutText: ""
  property string mutationStderrText: ""
  property string actionStatus: ""
  property var editorEvent: null
  property bool editingSeries: false
  property bool editLoadBusy: false
  property bool editLoadRequested: false
  property string editLoadEventKey: ""
  property var editLoadSourceEvent: null
  property string editLoadStdoutText: ""
  property string editLoadStderrText: ""
  property var pendingDeleteEvent: null
  property var pendingDeleteCalendarValues: null
  property var pendingDeleteAccount: null
  property string pendingDefaultName: ""
  property bool mutationCanceled: false
  property string lastAccountAddAuth: "basic"
  property bool rsvpRefreshPending: false
  property string rsvpExpectedStatus: ""

  readonly property color contentForeground: bar ? bar.foreground : Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property string settingsErrorText: {
    if (showingCalendarEditor || showingAccountEditor || showingAccountDetails
      || showingAccountCalendars || showingIcalImport)
      return syncStateError
    return syncStateError !== "" ? syncStateError : mutationError
  }
  readonly property string accountBusyLabel: {
    if (mutationKind === "account-add")
      return lastAccountAddAuth === "oauth2" ? "Waiting for Google authorization…" : "Signing in…"
    if (mutationKind === "account-credentials") return "Updating credentials…"
    if (mutationKind === "account-reauth") return "Waiting for Google authorization…"
    if (mutationKind === "sync-run") return "Syncing…"
    if (mutationKind === "account-update") return "Renaming…"
    if (mutationKind === "account-remove") return "Removing…"
    if (mutationKind === "account-get") return "Loading…"
    return "Working…"
  }

  function open() {
    if (hostWidget && hostWidget.refresh) hostWidget.refresh()
    root.controller.show()
  }

  function close() {
    root.rsvpRefreshPending = false
    root.rsvpExpectedStatus = ""
    root.selectedEvent = null
    root.selectedEventKey = ""
    root.resetSearch()
    root.editorMode = ""
    root.closeCalendarEditorState()
    root.closeAccountSetupState()
    root.showingSettings = false
    root.showingHelp = false
    root.resetEditState()
    root.pendingDeleteEvent = null
    root.hideDeleteConfirm()
    root.controller.hide()
  }

  function closeCalendarEditorState() {
    calendarEditorMode = ""
    calendarEditorTarget = null
    pendingDeleteCalendarValues = null
  }

  function closeAccountSetupState() {
    showingAccountEditor = false
    accountDetailsTarget = null
    pendingDeleteAccount = null
    if (discoveryBusy) {
      // Keep discoveryBusy until finishDiscoveryLoad so a stale exit cannot
      // clobber a session reopened before the killed process reported.
      discoveryCancelPending = true
      discoveryProc.running = false
    }
    showingAccountCalendars = false
    accountCalendarsAccount = null
    discoveryRows = []
    discoveryError = ""
    showingIcalImport = false
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function showEvent(eventData) {
    selectedEventKey = Model.eventKey(eventData)
    selectedEvent = eventData
    editorMode = ""
    closeCalendarEditorState()
    closeAccountSetupState()
    showingSettings = false
    showingHelp = false
    actionStatus = ""
    resetEditState()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function backToAgenda() {
    rsvpRefreshPending = false
    rsvpExpectedStatus = ""
    selectedEvent = null
    editorMode = ""
    closeCalendarEditorState()
    closeAccountSetupState()
    showingSettings = false
    showingHelp = false
    actionStatus = ""
    resetEditState()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function toggleSettings() {
    selectedEvent = null
    editorMode = ""
    closeCalendarEditorState()
    closeAccountSetupState()
    showingHelp = false
    showingSettings = showingSettings ? false : true
    resetEditState()
    if (showingSettings) fetchSyncState()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function persistSettings(values) {
    var refreshAgenda = "lookaheadDays" in values
      && Number(values.lookaheadDays) !== Number(root.setting("lookaheadDays", 7))
    var entry = { id: root.moduleName }
    for (var existing in root.settings) if (existing !== "id") entry[existing] = root.settings[existing]
    for (var key in values) entry[key] = values[key]
    root.settings = entry
    if (root.hostWidget && "settings" in root.hostWidget) root.hostWidget.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
    if (refreshAgenda && root.hostWidget && typeof root.hostWidget.broadcast === "function")
      Qt.callLater(function() { root.hostWidget.broadcast("refresh") })
  }

  function selectedEventIndex() {
    for (var index = 0; index < visibleEvents.length; index += 1)
      if (Model.eventKey(visibleEvents[index]) === selectedEventKey) return index
    return -1
  }

  function syncSelectionToSearch() {
    if (visibleEvents.length === 0) {
      selectedEventKey = ""
      return
    }
    if (selectedEventIndex() < 0) selectedEventKey = Model.eventKey(visibleEvents[0])
  }

  function moveSelection(step) {
    if (showingDetails || showingSettings || showingEditor || showingCalendarEditor || showingHelp || showingAccountEditor || showingAccountDetails || showingAccountCalendars || showingIcalImport || visibleEvents.length === 0) return
    var current = selectedEventIndex()
    var next = current < 0 ? (step > 0 ? 0 : visibleEvents.length - 1) : Model.clampSelection(current + step, visibleEvents.length)
    selectedEventKey = Model.eventKey(visibleEvents[next])
  }

  function focusedEvent() {
    if (selectedEvent) return selectedEvent
    if (showingSettings || showingHelp || showingEditor || showingCalendarEditor || showingAccountEditor || showingAccountDetails || showingAccountCalendars || showingIcalImport) return null
    var current = selectedEventIndex()
    if (current < 0) return null
    return visibleEvents[current]
  }

  function moveSelectionByDay(direction) {
    if (showingDetails || showingSettings || showingEditor || showingCalendarEditor || showingHelp || showingAccountEditor || showingAccountDetails || showingAccountCalendars || showingIcalImport || visibleEvents.length === 0) return
    var index = Model.adjacentDayFirstEventIndex(visibleEvents, selectedEventIndex(), direction)
    if (index >= 0) selectedEventKey = Model.eventKey(visibleEvents[index])
  }

  function hideDeleteConfirm() {
    deleteConfirm.opened = false
    pendingDeleteEvent = null
    pendingDeleteCalendarValues = null
    pendingDeleteAccount = null
    pendingSyncResetCalendar = null
    deleteConfirm.actionLabel = ""
  }

  function dismissCalendarDeleteConfirm() {
    hideDeleteConfirm()
    if (showingCalendarEditor) Qt.callLater(function() { calendarEditor.forceActiveFocus() })
    else if (showingAccountEditor) Qt.callLater(function() { accountEditor.forceActiveFocus() })
    else if (showingAccountCalendars) Qt.callLater(function() { accountCalendars.forceActiveFocus() })
    else if (showingIcalImport) Qt.callLater(function() { icalImport.forceActiveFocus() })
    else if (showingAccountDetails) Qt.callLater(function() { accountDetails.forceActiveFocus() })
    else Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function handleClose() {
    if (deleteConfirm.opened) {
      dismissCalendarDeleteConfirm()
    } else if (showingAccountCalendars) {
      if (mutationBusy) cancelSetupMutation()
      else closeAccountCalendars()
    } else if (showingAccountEditor || showingAccountDetails) {
      // Esc/back during a sign-in or sync kills the process first; the
      // form stays open until onExited lands (finishMutation sees
      // mutationCanceled and keeps everything quiet).
      if (mutationBusy) cancelSetupMutation()
      else if (showingAccountEditor) closeAccountEditor()
      else closeAccountDetails()
    } else if (showingCalendarEditor) {
      closeCalendarEditor()
    } else if (showingIcalImport) {
      if (mutationBusy) cancelSetupMutation()
      else closeIcalImport()
    } else if (showingEditor) {
      cancelEditor()
    } else if (showingDetails || showingSettings || showingHelp) {
      backToAgenda()
    } else if (searching) {
      endSearch()
    } else {
      close()
    }
  }

  function activateSelection() {
    if (showingDetails || showingSettings || showingEditor || showingCalendarEditor || showingHelp || showingAccountEditor || showingAccountDetails || showingAccountCalendars || showingIcalImport || visibleEvents.length === 0) return
    var current = selectedEventIndex()
    showEvent(visibleEvents[current < 0 ? 0 : current])
  }

  function beginSearch() {
    if (showingDetails || showingSettings || showingEditor || showingCalendarEditor || showingHelp || showingAccountEditor || showingAccountDetails || showingAccountCalendars || showingIcalImport || agendaData.status !== "ok") return
    searching = true
    Qt.callLater(function() { searchField.forceActiveFocus() })
  }

  function resetSearch() {
    searching = false
    searchQuery = ""
    searchField.text = ""
  }

  function endSearch() {
    resetSearch()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function ensureAgendaItemVisible(item) {
    if (!item || !agendaFlick.visible) return
    var point = item.mapToItem(groupsColumn, 0, 0)
    if (point.y < agendaFlick.contentY) agendaFlick.contentY = point.y
    else if (point.y + item.height > agendaFlick.contentY + agendaFlick.height)
      agendaFlick.contentY = Math.min(agendaFlick.contentHeight - agendaFlick.height, point.y + item.height - agendaFlick.height)
  }

  function showFirstEvent() {
    activateSelection()
  }

  function selectToday() {
    var index = Model.firstEventIndexForDate(visibleEvents, agendaData.generated_at || new Date().toISOString())
    if (index >= 0) selectedEventKey = Model.eventKey(visibleEvents[index])
  }

  function toggleHelp() {
    selectedEvent = null
    editorMode = ""
    closeCalendarEditorState()
    closeAccountSetupState()
    showingSettings = false
    showingHelp = showingHelp ? false : true
    resetEditState()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  onVisibleEventsChanged: syncSelectionToSearch()

  function refresh() {
    if (hostWidget && hostWidget.refresh) hostWidget.refresh()
  }

  function startCreate() {
    selectedEvent = null
    closeCalendarEditorState()
    closeAccountSetupState()
    showingSettings = false
    showingHelp = false
    mutationError = ""
    resetEditState()
    editorMode = "create"
  }

  function resetEditState() {
    editLoadRequested = false
    editorEvent = null
    editingSeries = false
  }

  function openEditor(eventData, series) {
    editorEvent = eventData
    editingSeries = series === true
    editorMode = "edit"
    mutationError = ""
    actionStatus = ""
    Qt.callLater(function() { eventEditor.initialize() })
  }

  function startEdit() {
    var event = focusedEvent()
    if (!event || !Model.canEditEvent(event) || showingSettings || showingHelp) return
    if (mutationBusy || editLoadBusy) return
    var direct = Model.canMutateEvent(event)
    var lookupArgs = direct ? [] : Model.seriesMasterLookupArgs(event)
    if (!direct && lookupArgs.length === 0) return
    showingSettings = false
    showingHelp = false
    if (direct) {
      openEditor(event, false)
      return
    }
    if (!hostWidget || !hostWidget.chroncalExecScript) {
      actionStatus = "Chroncal executable is unavailable"
      actionStatusTimer.restart()
      return
    }
    editLoadSourceEvent = event
    editLoadEventKey = Model.eventKey(event)
    editLoadRequested = true
    editLoadBusy = true
    editLoadStdoutText = ""
    editLoadStderrText = ""
    actionStatusTimer.stop()
    actionStatus = "Loading recurring series…"
    editLoadProc.command = [hostWidget.chroncalExecScript].concat(lookupArgs)
    editLoadProc.running = true
  }

  function finishEditLoad(exitCode) {
    editLoadBusy = false
    var requested = editLoadRequested
    var source = editLoadSourceEvent
    var requestedKey = editLoadEventKey
    editLoadRequested = false
    if (!requested || !root.opened || !source) return
    if (Model.eventKey(source) !== requestedKey) return
    if (selectedEvent && Model.eventKey(selectedEvent) !== requestedKey) return
    if (exitCode !== 0) {
      var failure = String(editLoadStderrText).trim()
      if (failure === "") failure = String(editLoadStdoutText).trim()
      if (failure === "") failure = "Chroncal could not load the recurring series"
      actionStatus = failure
      actionStatusTimer.restart()
      return
    }
    var parsed = null
    try {
      parsed = JSON.parse(String(editLoadStdoutText))
    } catch (error) {
      parsed = null
    }
    var prepared = Model.seriesEditorEvent(parsed, source)
    if (prepared === null) {
      actionStatus = "Chroncal returned an invalid recurring series"
      actionStatusTimer.restart()
      return
    }
    actionStatus = ""
    openEditor(prepared, true)
  }

  function openCalendarCreate() {
    if (mutationBusy) return
    selectedEvent = null
    editorMode = ""
    closeAccountSetupState()
    showingHelp = false
    mutationError = ""
    calendarEditorTarget = null
    calendarEditorMode = "create"
    showingSettings = true
    Qt.callLater(function() { calendarEditor.initialize() })
  }

  function openCalendarEdit(calendar) {
    if (mutationBusy || !calendar) return
    selectedEvent = null
    editorMode = ""
    closeAccountSetupState()
    showingHelp = false
    mutationError = ""
    actionStatus = ""
    calendarEditorTarget = calendar
    calendarEditorMode = "edit"
    showingSettings = true
    Qt.callLater(function() { calendarEditor.initialize() })
  }

  function closeCalendarEditor() {
    closeCalendarEditorState()
    hideDeleteConfirm()
    mutationError = ""
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function submitCalendarEditor(values) {
    if (mutationBusy) return
    var form = values || {}
    var target = calendarEditorTarget || {}
    if (form.action === "create") {
      pendingDefaultName = form.setDefault === true ? String(form.name || "") : ""
      runMutation(Model.calendarCreateArgs({
        title: form.name,
        color: form.color,
        description: form.description,
        email: form.email
      }), "calendar-create")
      return
    }
    if (form.action === "update") {
      runMutation(Model.calendarUpdateArgs({
        id: target.id,
        name: form.name,
        color: form.color,
        description: form.description,
        email: form.email
      }), "calendar-update")
      return
    }
    if (form.action === "hide") {
      runMutation(Model.calendarHideArgs({ id: target.id }), "calendar-hide")
      return
    }
    if (form.action === "show") {
      runMutation(Model.calendarShowArgs({ id: target.id }), "calendar-show")
      return
    }
    if (form.action === "default") {
      runMutation(Model.calendarSetDefaultArgs({ id: target.id }), "calendar-default")
      return
    }
    if (form.action === "disconnect") {
      runMutation(Model.calendarUpdateArgs({ id: target.id, disconnectRemote: true }), "calendar-disconnect")
      return
    }
    if (form.action === "delete") requestCalendarDelete(form)
  }

  function requestCalendarDelete(values) {
    if (mutationBusy) return
    pendingDeleteCalendarValues = values
    deleteConfirm.recurring = false
    deleteConfirm.actionLabel = ""
    deleteConfirm.selectedIndex = 0
    deleteConfirm.opened = true
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function confirmCalendarDelete() {
    deleteConfirm.opened = false
    if (mutationBusy) {
      pendingDeleteCalendarValues = null
      return
    }
    var values = pendingDeleteCalendarValues || {}
    pendingDeleteCalendarValues = null
    var target = calendarEditorTarget || {}
    var args = Model.calendarDeleteArgs({ id: target.id, promote: values.promote })
    if (String(args[2] || "") === "") return
    runMutation(args, "calendar-delete")
  }

  function openAccountCreate() {
    if (mutationBusy) return
    selectedEvent = null
    editorMode = ""
    closeCalendarEditorState()
    closeAccountSetupState()
    showingHelp = false
    mutationError = ""
    actionStatus = ""
    showingAccountEditor = true
    showingSettings = true
    Qt.callLater(function() { accountEditor.initialize() })
  }

  function closeAccountEditor() {
    showingAccountEditor = false
    hideDeleteConfirm()
    mutationError = ""
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function openAccountDetails(account) {
    if (mutationBusy || !account) return
    selectedEvent = null
    editorMode = ""
    closeCalendarEditorState()
    closeAccountSetupState()
    showingHelp = false
    mutationError = ""
    actionStatus = ""
    accountDetailsTarget = account
    showingSettings = true
    Qt.callLater(function() { accountDetails.initialize() })
    // Calendars carry no auth_type/username; hydrate from `account get`
    // (its JSON contains no secrets).
    if (String(account.auth_type || "") === "")
      runMutation(Model.accountGetArgs({ id: account.id }), "account-get")
  }

  function closeAccountDetails() {
    accountDetailsTarget = null
    hideDeleteConfirm()
    mutationError = ""
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function submitAccountEditor(values) {
    if (mutationBusy) return
    var form = values || {}
    if (String(form.name || "").trim() === "") return
    lastAccountAddAuth = String(form.auth || "basic")
    // The secret travels as process environment only (Model.accountAddEnv);
    // argv (accountAddArgs) never sees it.
    runMutation(Model.accountAddArgs(form), "account-add", Model.accountAddEnv(form))
  }

  function submitAccountDetails(values) {
    if (mutationBusy) return
    var form = values || {}
    var id = String(form.id || (accountDetailsTarget || {}).id || "")
    if (id === "") return
    if (form.action === "rename") {
      if (String(form.name || "").trim() === "") return
      runMutation(Model.accountUpdateArgs({ id: id, name: form.name }), "account-update")
      return
    }
    if (form.action === "sync") {
      runMutation(Model.syncRunAccountArgs({ id: id }), "sync-run")
      return
    }
    if (form.action === "credentials") {
      runMutation(Model.accountCredentialsArgs({ id: id }), "account-credentials", Model.accountCredentialsEnv(form))
      return
    }
    if (form.action === "reauth") {
      // No secret provided means Chroncal reuses the stored one.
      var env = String(form.clientSecret || "") !== ""
        ? Model.accountAddEnv({ auth: "oauth2", clientSecret: form.clientSecret })
        : ({})
      runMutation(Model.accountReauthArgs({ id: id, clientId: form.clientId }), "account-reauth", env)
      return
    }
    if (form.action === "remove") requestAccountDelete(form)
  }

  function requestAccountDelete(values) {
    if (mutationBusy) return
    var target = accountDetailsTarget || values || null
    if (!target) return
    pendingDeleteAccount = target
    deleteConfirm.recurring = false
    deleteConfirm.actionLabel = ""
    deleteConfirm.selectedIndex = 0
    deleteConfirm.opened = true
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function confirmAccountRemove() {
    deleteConfirm.opened = false
    if (mutationBusy) {
      pendingDeleteAccount = null
      return
    }
    var account = pendingDeleteAccount || {}
    pendingDeleteAccount = null
    var args = Model.accountRemoveArgs(account)
    if (String(args[2] || "") === "") return
    runMutation(args, "account-remove")
  }

  function openAccountCalendars(account) {
    if (mutationBusy || discoveryBusy || !account) return
    selectedEvent = null
    editorMode = ""
    closeCalendarEditorState()
    showingHelp = false
    mutationError = ""
    discoveryError = ""
    discoveryRows = []
    accountCalendarsAccount = account
    showingAccountCalendars = true
    if (!hostWidget || !hostWidget.chroncalExecScript) {
      discoveryError = "Chroncal executable is unavailable"
      return
    }
    discoveryBusy = true
    discoveryStdoutText = ""
    discoveryStderrText = ""
    discoveryProc.command = [hostWidget.chroncalExecScript].concat(Model.accountCalendarsListArgs(account))
    discoveryProc.running = true
  }

  function finishDiscoveryLoad(exitCode) {
    if (discoveryCancelPending) {
      // The view was closed and this load was killed; ignore the exit.
      discoveryCancelPending = false
      discoveryBusy = false
      return
    }
    discoveryBusy = false
    if (!showingAccountCalendars || accountCalendarsAccount === null) return
    if (exitCode !== 0) {
      var failure = String(discoveryStderrText || discoveryStdoutText || "").trim()
      discoveryError = failure !== "" ? failure : "Chroncal could not load the account calendars"
      return
    }
    var parsed = null
    try {
      parsed = JSON.parse(String(discoveryStdoutText))
    } catch (error) {
      parsed = null
    }
    if (!parsed || typeof parsed !== "object") {
      discoveryError = "Chroncal could not load the account calendars"
      return
    }
    discoveryError = ""
    discoveryRows = parsed.calendars || []
    if (parsed.account && typeof parsed.account === "object" && parsed.account.id !== undefined) {
      var merged = {}
      var current = accountCalendarsAccount
      for (var key in current) merged[key] = current[key]
      merged.id = parsed.account.id
      merged.display_name = String(parsed.account.display_name || parsed.account.name || current.display_name || "Account")
      merged.name = merged.display_name
      merged.server_url = String(parsed.account.server_url || current.server_url || "")
      merged.auth_type = String(parsed.account.auth_type || current.auth_type || "")
      merged.username = String(parsed.account.username || current.username || "")
      accountCalendarsAccount = merged
    }
  }

  function closeAccountCalendars() {
    if (discoveryBusy) {
      // Quickshell Process: SIGTERM. Busy stays until finishDiscoveryLoad.
      discoveryCancelPending = true
      discoveryProc.running = false
    }
    showingAccountCalendars = false
    accountCalendarsAccount = null
    discoveryRows = []
    discoveryError = ""
    Qt.callLater(function() { accountDetails.forceActiveFocus() })
  }

  function submitAccountCalendars(values) {
    if (mutationBusy || discoveryBusy) return
    var form = values || {}
    var args = Model.accountCalendarsSetArgs({
      id: (accountCalendarsAccount || {}).id,
      paths: form.none === true ? [] : form.paths,
      none: form.none === true,
      defaultRef: form.defaultRef
    })
    if (args.length === 0) {
      discoveryError = "Select the calendars to keep, or none to remove the account"
      return
    }
    runMutation(args, "account-calendars-set")
  }

  function openIcalImport() {
    if (mutationBusy) return
    selectedEvent = null
    editorMode = ""
    closeCalendarEditorState()
    closeAccountSetupState()
    showingHelp = false
    mutationError = ""
    actionStatus = ""
    showingIcalImport = true
    showingSettings = true
    Qt.callLater(function() { icalImport.initialize() })
  }

  function closeIcalImport() {
    showingIcalImport = false
    hideDeleteConfirm()
    mutationError = ""
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function submitIcalImport(values) {
    if (mutationBusy) return
    var form = values || {}
    var args = Model.icalImportArgs({ path: form.path, calendar: form.calendar })
    if (String(args[2] || "") === "") {
      mutationError = "Path is required"
      return
    }
    runMutation(args, "ical-import")
  }

  function cancelSetupMutation() {
    if (!mutationBusy) return
    mutationCanceled = true
    mutationProc.running = false  // Quickshell Process: SIGTERM
  }

  function refocusSetupSurface() {
    if (showingAccountCalendars) Qt.callLater(function() { accountCalendars.forceActiveFocus() })
    else if (showingIcalImport) Qt.callLater(function() { icalImport.forceActiveFocus() })
    else if (showingAccountEditor) Qt.callLater(function() { accountEditor.forceActiveFocus() })
    else if (showingAccountDetails) Qt.callLater(function() { accountDetails.forceActiveFocus() })
    else if (showingCalendarEditor) Qt.callLater(function() { calendarEditor.forceActiveFocus() })
    else Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function cancelEditor() {
    var wasEditing = editorMode === "edit"
    editorMode = ""
    mutationError = ""
    editorEvent = null
    editingSeries = false
    if (!wasEditing) selectedEvent = null
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function submitEditor(values) {
    var args = Model.eventMutationArgs(editorMode, editorEvent, values, { series: editingSeries })
    if (args.length === 0) {
      mutationError = "Check the event fields"
      return
    }
    runMutation(args, editorMode)
  }

  function requestDelete() {
    var event = focusedEvent()
    if (!event || mutationBusy || editLoadBusy || !Model.canDeleteEvent(event) || showingSettings || showingHelp || showingEditor) return
    pendingDeleteEvent = event
    deleteConfirm.recurring = Model.isRecurringEvent(event)
    deleteConfirm.actionLabel = ""
    deleteConfirm.selectedIndex = 0
    deleteConfirm.opened = true
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function confirmDelete(scope) {
    deleteConfirm.opened = false
    var event = pendingDeleteEvent || selectedEvent
    pendingDeleteEvent = null
    if (!event) return
    var options = {}
    if (scope === "this") options.thisEvent = true
    if (scope === "following") options.following = true
    if (scope === "series") options.series = true
    var args = Model.eventDeleteArgs(event, options)
    if (args.length === 0) return
    var kind = scope === "series" ? "delete-series" : (scope === "following" ? "delete-following" : (scope === "this" ? "delete-this" : "delete"))
    runMutation(args, kind)
  }

  function runMutation(args, kind, env) {
    if (mutationBusy || !hostWidget || !hostWidget.chroncalExecScript) return
    mutationBusy = true
    mutationKind = kind
    mutationError = ""
    mutationStdoutText = ""
    mutationStderrText = ""
    // Quickshell.Io.Process exposes `environment` (a JS object merged over the
    // parent environment; string values add a variable, null removes one).
    // Secrets must travel here only, never in argv. A missing env resets any
    // leftover variable from a previous account mutation.
    if (env && typeof env === "object") mutationProc.environment = env
    else mutationProc.environment = ({})
    mutationProc.command = [hostWidget.chroncalExecScript].concat(args)
    mutationProc.running = true
  }

  function hydrateSelectedEvent() {
    if (!rsvpRefreshPending || !showingDetails || !selectedEventKey) return
    var index = selectedEventIndex()
    if (index < 0) return
    var next = visibleEvents[index]
    if (rsvpExpectedStatus !== "" && Model.userRsvpStatus(next) !== rsvpExpectedStatus) return
    rsvpRefreshPending = false
    rsvpExpectedStatus = ""
    selectedEvent = next
  }

  function rsvpEvent(status) {
    if (mutationBusy || editLoadBusy || !showingDetails) return
    var event = selectedEvent
    var args = Model.eventRsvpArgs(event, status)
    if (args.length === 0) return
    var normalized = Model.normalizeRsvpStatus(status)
    selectedEvent = Model.applyUserRsvp(event, normalized)
    runMutation(args, "rsvp-" + normalized)
  }

  function isSetupKind(kind) {
    var name = String(kind || "")
    return name.indexOf("calendar-") === 0 || name.indexOf("account-") === 0
      || name.indexOf("sync-") === 0 || name.indexOf("ical-") === 0
  }

  function setupActionStatus(kind) {
    if (kind === "calendar-create") return "Calendar created"
    if (kind === "calendar-update") return "Calendar updated"
    if (kind === "calendar-hide") return "Calendar hidden"
    if (kind === "calendar-show") return "Calendar visible"
    if (kind === "calendar-default") return "Default calendar set"
    if (kind === "calendar-disconnect") return "Kept local copy"
    if (kind === "calendar-delete") return "Calendar deleted"
    if (kind === "account-add") return "Account added"
    if (kind === "account-update") return "Account renamed"
    if (kind === "account-credentials") return "Credentials updated"
    if (kind === "account-reauth") return "Signed in again"
    if (kind === "sync-run") return "Account synced"
    if (kind === "sync-resolve") return "Conflict resolved"
    if (kind === "sync-reset") return "Sync state reset"
    if (kind === "account-calendars-set") return "Calendars updated"
    if (kind === "ical-import") return "Events imported"
    if (kind === "account-remove") return "Account removed"
    return "Done"
  }

  function parseMutationJson() {
    try {
      var parsed = JSON.parse(String(mutationStdoutText))
      if (parsed && typeof parsed === "object") return parsed
    } catch (error) {}
    return null
  }

  // `account get` JSON has no secrets; fold it into the inspector target.
  function hydrateAccountDetails() {
    var parsed = parseMutationJson()
    if (!parsed || parsed.id === undefined) return
    var merged = {}
    var current = accountDetailsTarget || {}
    for (var key in current) merged[key] = current[key]
    merged.id = parsed.id
    merged.display_name = String(parsed.display_name || parsed.name || current.display_name || "Account")
    merged.name = merged.display_name
    merged.server_url = String(parsed.server_url || current.server_url || "")
    merged.auth_type = String(parsed.auth_type || "")
    merged.username = String(parsed.username || "")
    accountDetailsTarget = merged
  }

  function mergeAccountRename() {
    var parsed = parseMutationJson()
    if (!parsed || (parsed.name === undefined && parsed.display_name === undefined)) return
    var merged = {}
    var current = accountDetailsTarget || {}
    for (var key in current) merged[key] = current[key]
    merged.display_name = String(parsed.display_name || parsed.name || current.display_name || "Account")
    merged.name = merged.display_name
    accountDetailsTarget = merged
  }

  function finishSetupMutation(exitCode, completed) {
    if (completed === "account-get") {
      if (exitCode !== 0) {
        mutationError = String(mutationStderrText || mutationStdoutText || "Chroncal could not load the account").trim()
        actionStatus = mutationError
        actionStatusTimer.restart()
      } else {
        hydrateAccountDetails()
      }
      if (showingAccountDetails) Qt.callLater(function() { accountDetails.forceActiveFocus() })
      return
    }
    if (completed === "account-add") {
      if (exitCode !== 0) {
        // Zero usable collections rolls the account back, but Chroncal
        // may also exit non-zero after creating it when the initial
        // sync fails; refresh either way so the list matches reality.
        var addFailure = String(mutationStderrText || mutationStdoutText || "Chroncal could not add the account").trim()
        mutationError = addFailure
        actionStatus = addFailure
        actionStatusTimer.restart()
        refresh()
        if (showingAccountEditor) Qt.callLater(function() { accountEditor.forceActiveFocus() })
        return
      }
      actionStatus = setupActionStatus(completed)
      actionStatusTimer.restart()
      closeAccountEditor()
      refresh()
      fetchSyncState()
      Qt.callLater(function() { keyCatcher.forceActiveFocus() })
      return
    }
    if (completed === "account-update" || completed === "account-credentials"
        || completed === "account-reauth" || completed === "sync-run") {
      if (exitCode !== 0) {
        mutationError = String(mutationStderrText || mutationStdoutText || "Chroncal could not complete the action").trim()
        actionStatus = mutationError
        actionStatusTimer.restart()
        if (completed === "sync-run") {
          refresh()
          fetchSyncState()
        }
      } else {
        actionStatus = setupActionStatus(completed)
        actionStatusTimer.restart()
        if (completed === "account-update") {
          mergeAccountRename()
          // Close the rename form and re-seed its value so a second Save
          // cannot silently revert to the pre-rename name.
          accountDetails.closeSubforms()
          accountDetails.nameValue = String((accountDetailsTarget || {}).display_name || "")
        }
        if (completed === "account-credentials" || completed === "account-reauth") accountDetails.closeSubforms()
        refresh()
        if (completed === "sync-run") fetchSyncState()
      }
      if (showingAccountDetails) Qt.callLater(function() { accountDetails.forceActiveFocus() })
      return
    }
    if (completed === "sync-resolve" || completed === "sync-reset") {
      if (exitCode !== 0) {
        mutationError = String(mutationStderrText || mutationStdoutText || "Chroncal could not complete the action").trim()
        actionStatus = mutationError
        actionStatusTimer.restart()
        Qt.callLater(function() { keyCatcher.forceActiveFocus() })
        return
      }
      actionStatus = setupActionStatus(completed)
      actionStatusTimer.restart()
      refresh()
      fetchSyncState()
      Qt.callLater(function() { keyCatcher.forceActiveFocus() })
      return
    }
    if (completed === "account-remove") {
      if (exitCode !== 0) {
        mutationError = String(mutationStderrText || mutationStdoutText || "Chroncal could not remove the account").trim()
        actionStatus = mutationError
        actionStatusTimer.restart()
        if (showingAccountDetails) Qt.callLater(function() { accountDetails.forceActiveFocus() })
        return
      }
      actionStatus = setupActionStatus(completed)
      actionStatusTimer.restart()
      closeAccountDetails()
      refresh()
      Qt.callLater(function() { keyCatcher.forceActiveFocus() })
      return
    }
    if (completed === "account-calendars-set") {
      if (exitCode !== 0) {
        mutationError = String(mutationStderrText || mutationStdoutText || "Chroncal could not update the account calendars").trim()
        actionStatus = mutationError
        actionStatusTimer.restart()
        if (showingAccountCalendars) Qt.callLater(function() { accountCalendars.forceActiveFocus() })
        return
      }
      actionStatus = setupActionStatus(completed)
      actionStatusTimer.restart()
      var setParsed = parseMutationJson()
      var accountRemoved = setParsed !== null && setParsed.account_removed === true
      closeAccountCalendars()
      if (accountRemoved) closeAccountDetails()
      else Qt.callLater(function() { accountDetails.forceActiveFocus() })
      refresh()
      fetchSyncState()
      return
    }
    if (completed === "ical-import") {
      if (exitCode !== 0) {
        mutationError = String(mutationStderrText || mutationStdoutText || "Chroncal could not import the file").trim()
        actionStatus = mutationError
        actionStatusTimer.restart()
        if (showingIcalImport) Qt.callLater(function() { icalImport.forceActiveFocus() })
        return
      }
      actionStatus = setupActionStatus(completed)
      actionStatusTimer.restart()
      closeIcalImport()
      refresh()
      Qt.callLater(function() { keyCatcher.forceActiveFocus() })
      return
    }
    if (exitCode !== 0) {
      mutationError = String(mutationStderrText || mutationStdoutText
        || (String(completed).indexOf("calendar-") === 0 ? "Chroncal could not save the calendar" : "Chroncal could not complete the action")).trim()
      actionStatus = mutationError
      actionStatusTimer.restart()
      if (showingCalendarEditor) Qt.callLater(function() { calendarEditor.forceActiveFocus() })
      return
    }
    if (completed === "calendar-create" && pendingDefaultName !== "") {
      // The create and set-default are separate processes. Chain the default
      // step with the id Chroncal reported; without a parsable id, keep the
      // new calendar non-default and say it was created.
      pendingDefaultName = ""
      var createdId = ""
      try {
        var created = JSON.parse(String(mutationStdoutText))
        if (created && typeof created === "object" && created.id !== undefined) createdId = String(created.id)
      } catch (error) {
        createdId = ""
      }
      if (createdId !== "") {
        actionStatus = "Calendar created"
        actionStatusTimer.restart()
        closeCalendarEditor()
        refresh()
        runMutation(Model.calendarSetDefaultArgs({ id: createdId }), "calendar-default")
        return
      }
    }
    actionStatus = setupActionStatus(completed)
    actionStatusTimer.restart()
    closeCalendarEditor()
    refresh()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  Process {
    id: discoveryProc
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.discoveryStdoutText = text }
    stderr: StdioCollector { waitForEnd: true; onStreamFinished: root.discoveryStderrText = text }
    onExited: function(exitCode) { Qt.callLater(function() { root.finishDiscoveryLoad(exitCode) }) }
  }


  function maybeRunQueuedSyncFetch() {
    if (syncStatusBusy || syncIssuesBusy) return
    if (!syncFetchQueued) return
    if (!root.opened || !showingSettings) {
      syncFetchQueued = false
      return
    }
    fetchSyncState()
  }

  function fetchSyncState() {
    if (!hostWidget || !hostWidget.chroncalExecScript) return
    if (syncStatusBusy || syncIssuesBusy) {
      // A resolve/sync can finish while the previous status read is still
      // in flight; run again as soon as that read exits.
      syncFetchQueued = true
      return
    }
    syncFetchQueued = false
    syncStatusBusy = true
    syncIssuesBusy = true
    syncStatusLoadOk = false
    syncIssuesLoadOk = false
    syncStatusStdoutText = ""
    syncStatusStderrText = ""
    syncIssuesStdoutText = ""
    syncIssuesStderrText = ""
    syncStatusProc.command = [hostWidget.chroncalExecScript].concat(Model.syncStatusArgs())
    syncStatusProc.running = true
    syncIssuesProc.command = [hostWidget.chroncalExecScript].concat(Model.syncConflictsArgs())
    syncIssuesProc.running = true
  }

  function settleSyncStateError() {
    if (syncStatusBusy || syncIssuesBusy) return
    if (syncStatusLoadOk && syncIssuesLoadOk) syncStateError = ""
  }

  function finishSyncStatusLoad(exitCode) {
    syncStatusBusy = false
    if (!root.opened || !showingSettings) {
      syncFetchQueued = false
      return
    }
    syncStatusLoadOk = false
    if (exitCode !== 0) {
      var statusFailure = String(syncStatusStderrText || syncStatusStdoutText || "").trim()
      syncStateError = statusFailure !== "" ? statusFailure : "Sync status unavailable"
    } else {
      var statusParsed = null
      try {
        statusParsed = JSON.parse(String(syncStatusStdoutText))
      } catch (error) {
        statusParsed = null
      }
      if (Array.isArray(statusParsed)) {
        syncStatusRows = statusParsed
        syncStatusLoadOk = true
      } else {
        syncStateError = "Sync status unavailable"
      }
    }
    settleSyncStateError()
    maybeRunQueuedSyncFetch()
  }

  function finishSyncIssuesLoad(exitCode) {
    syncIssuesBusy = false
    if (!root.opened || !showingSettings) {
      syncFetchQueued = false
      return
    }
    syncIssuesLoadOk = false
    if (exitCode !== 0) {
      var issuesFailure = String(syncIssuesStderrText || syncIssuesStdoutText || "").trim()
      syncStateError = issuesFailure !== "" ? issuesFailure : "Sync status unavailable"
    } else {
      var issuesParsed = null
      try {
        issuesParsed = JSON.parse(String(syncIssuesStdoutText))
      } catch (error) {
        issuesParsed = null
      }
      if (Array.isArray(issuesParsed)) {
        syncIssueRows = issuesParsed
        syncIssuesLoadOk = true
      } else {
        syncStateError = "Sync status unavailable"
      }
    }
    settleSyncStateError()
    maybeRunQueuedSyncFetch()
  }

  function requestSyncReset(row) {
    if (mutationBusy || !row) return
    pendingSyncResetCalendar = row
    deleteConfirm.recurring = false
    deleteConfirm.actionLabel = "Reset"
    deleteConfirm.selectedIndex = 0
    deleteConfirm.opened = true
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function confirmSyncReset() {
    deleteConfirm.opened = false
    deleteConfirm.actionLabel = ""
    if (mutationBusy) {
      pendingSyncResetCalendar = null
      return
    }
    var row = pendingSyncResetCalendar || {}
    pendingSyncResetCalendar = null
    var args = Model.syncResetArgs({ id: row.calendar_id })
    if (args.length === 0) return
    runMutation(args, "sync-reset")
  }

  Process {
    id: syncStatusProc
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.syncStatusStdoutText = text }
    stderr: StdioCollector { waitForEnd: true; onStreamFinished: root.syncStatusStderrText = text }
    onExited: function(exitCode) { Qt.callLater(function() { root.finishSyncStatusLoad(exitCode) }) }
  }

  Process {
    id: syncIssuesProc
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.syncIssuesStdoutText = text }
    stderr: StdioCollector { waitForEnd: true; onStreamFinished: root.syncIssuesStderrText = text }
    onExited: function(exitCode) { Qt.callLater(function() { root.finishSyncIssuesLoad(exitCode) }) }
  }

  function finishMutation(exitCode) {
    var completed = mutationKind
    mutationBusy = false
    if (mutationCanceled) {
      // Esc killed an in-flight sign-in/sync (SIGTERM). Not a failure:
      // keep whatever form is open and stay quiet.
      mutationCanceled = false
      mutationKind = ""
      mutationError = ""
      actionStatus = "Canceled"
      actionStatusTimer.restart()
      refocusSetupSurface()
      return
    }
    if (isSetupKind(completed)) {
      finishSetupMutation(exitCode, completed)
      return
    }
    if (exitCode !== 0) {
      mutationError = String(mutationStderrText || mutationStdoutText || "Chroncal could not save the event").trim()
      actionStatus = mutationError
      actionStatusTimer.restart()
      if (String(completed).indexOf("rsvp-") === 0) {
        var index = selectedEventIndex()
        if (index >= 0) selectedEvent = visibleEvents[index]
        rsvpExpectedStatus = Model.userRsvpStatus(selectedEvent)
        rsvpRefreshPending = true
        refresh()
        Qt.callLater(function() { keyCatcher.forceActiveFocus() })
      }
      return
    }
    if (String(completed).indexOf("rsvp-") === 0) {
      actionStatus = completed === "rsvp-ACCEPTED" ? "Accepted" : (completed === "rsvp-DECLINED" ? "Declined" : (completed === "rsvp-TENTATIVE" ? "Maybe" : "RSVP updated"))
      actionStatusTimer.restart()
      rsvpExpectedStatus = completed.slice(5)
      rsvpRefreshPending = true
      refresh()
      Qt.callLater(function() { keyCatcher.forceActiveFocus() })
      return
    }
    editorMode = ""
    selectedEvent = null
    selectedEventKey = ""
    resetEditState()
    actionStatus = completed === "delete-this" ? "Occurrence removed" : (completed === "delete-following" ? "Later occurrences removed" : (completed === "delete-series" ? "All events deleted" : (completed === "delete" ? "Event deleted" : (completed === "edit" ? "Event updated" : "Event created"))))
    actionStatusTimer.restart()
    refresh()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function openUrl(url) {
    if (!url) return
    Quickshell.execDetached(["xdg-open", String(url)])
  }

  function joinEvent() {
    if (mutationBusy || editLoadBusy) return
    openUrl(Model.eventOpenUrl(selectedEvent))
  }

  function openMap() {
    if (mutationBusy || editLoadBusy) return
    openUrl(Model.eventMapUrl(selectedEvent))
  }

  function copyEventDetails() {
    if (mutationBusy || editLoadBusy) return
    var details = Model.eventDetailsText(selectedEvent)
    if (!details) return
    Quickshell.execDetached(["wl-copy", details])
    actionStatus = "Copied event details"
    actionStatusTimer.restart()
  }

  function openChroncal() {
    if (mutationBusy || editLoadBusy) return
    Quickshell.execDetached(["omarchy-launch-floating-terminal-with-presentation"].concat(Model.chroncalLaunchArgs(selectedEvent)))
    root.close()
  }

  Timer {
    id: actionStatusTimer
    interval: 2000
    onTriggered: root.actionStatus = ""
  }

  Process {
    id: mutationProc
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.mutationStdoutText = text }
    stderr: StdioCollector { waitForEnd: true; onStreamFinished: root.mutationStderrText = text }
    onExited: function(exitCode) { Qt.callLater(function() { root.finishMutation(exitCode) }) }
  }

  Process {
    id: editLoadProc
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.editLoadStdoutText = text }
    stderr: StdioCollector { waitForEnd: true; onStreamFinished: root.editLoadStderrText = text }
    onExited: function(exitCode) { Qt.callLater(function() { root.finishEditLoad(exitCode) }) }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(430))
    contentHeight: panel.fittedContentHeight(Style.space(520))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: (root.searching && searchField.activeFocus) || root.showingEditor
        || (root.showingCalendarEditor && !deleteConfirm.opened)
        || ((root.showingAccountEditor || root.showingAccountDetails || root.showingAccountCalendars || root.showingIcalImport) && !deleteConfirm.opened)
      onMoveRequested: function(dx, dy) {
        if (deleteConfirm.opened) {
          if (dx !== 0) deleteConfirm.cycle(dx)
          else if (dy !== 0) deleteConfirm.cycle(dy)
          return
        }
        if (root.showingDetails || root.showingSettings || root.showingEditor || root.showingHelp) return
        if (dy !== 0) root.moveSelection(dy)
        else if (dx !== 0) root.moveSelectionByDay(dx)
      }
      onCloseRequested: root.handleClose()
      onActivateRequested: {
        if (deleteConfirm.opened) deleteConfirm.activate()
        else if (!root.showingDetails && !root.showingSettings && !root.showingEditor && !root.showingHelp) root.activateSelection()
      }
      onTabRequested: function(direction) {
        if (deleteConfirm.opened) deleteConfirm.cycle(direction)
        else root.switchPanel(direction)
      }
      onDeleteRequested: root.requestDelete()
      onTextKey: function(text) {
        if (deleteConfirm.opened) {
          if (text === "q") root.handleClose()
          return
        }
        if (text === "q") root.handleClose()
        else if (text === "?") root.toggleHelp()
        else if (root.showingHelp) return
        else if (text === "s" || text === "S") root.refresh()
        else if (text === "/") root.beginSearch()
        else if (text === "," || text === "C") root.toggleSettings()
        else if (text === "c") root.startCreate()
        else if (!root.showingDetails && !root.showingSettings && !root.showingEditor && !root.showingCalendarEditor && !root.showingAccountEditor && !root.showingAccountDetails && !root.showingAccountCalendars && !root.showingIcalImport && (text === "t" || text === "T")) root.selectToday()
        else if (!root.showingSettings && !root.showingEditor && !root.showingCalendarEditor && !root.showingAccountEditor && !root.showingAccountDetails && !root.showingAccountCalendars && !root.showingIcalImport && (text === "e" || text === "E")) root.startEdit()
        else if (root.showingDetails && (text === "v" || text === "V")) root.joinEvent()
        else if (root.showingDetails && (text === "p" || text === "P")) root.copyEventDetails()
        else if (root.showingDetails && (text === "g" || text === "G")) root.openChroncal()
        else if (root.showingDetails && (text === "y" || text === "Y")) root.rsvpEvent("ACCEPTED")
        else if (root.showingDetails && (text === "n" || text === "N")) root.rsvpEvent("DECLINED")
        else if (root.showingDetails && (text === "m" || text === "M")) root.rsvpEvent("TENTATIVE")
      }

      Shortcut {
        sequence: "Delete"
        enabled: root.opened && !keyCatcher.blocked
        onActivated: root.requestDelete()
      }

      Column {
        anchors.fill: parent
        spacing: Style.space(10)

        Row {
          width: parent.width
          height: Style.space(28)

          Text {
            width: parent.width - headerActions.width
            anchors.verticalCenter: parent.verticalCenter
            text: root.showingAccountCalendars ? "MANAGE CALENDARS"
              : (root.showingIcalImport ? "IMPORT ICAL"
              : (root.showingAccountEditor ? "NEW ACCOUNT"
              : (root.showingAccountDetails ? "ACCOUNT"
              : (root.showingCalendarEditor ? (root.calendarEditorMode === "edit" ? "EDIT CALENDAR" : "NEW CALENDAR") : (root.showingEditor ? (root.editorMode === "edit" ? "EDIT EVENT" : "NEW EVENT") : (root.showingDetails ? "EVENT DETAILS" : (root.showingSettings ? "SETTINGS" : (root.showingHelp ? "SHORTCUTS" : "UPCOMING"))))))))
            color: root.contentForeground
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
            font.letterSpacing: 1.2
          }

          Row {
            id: headerActions
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(4)

            PanelActionButton {
              visible: root.showingSubview
              iconText: "←"
              tooltipText: root.showingEditor || root.showingCalendarEditor || root.showingAccountEditor || root.showingAccountDetails || root.showingAccountCalendars || root.showingIcalImport
                ? "Cancel and go back"
                : "Back to agenda"
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              onClicked: root.handleClose()
            }

            PanelActionButton {
              visible: !root.showingSubview
              iconText: "󰒓"
              tooltipText: "Calendar Settings"
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              onClicked: root.toggleSettings()
            }

            PanelActionButton {
              visible: !root.showingSubview
              iconText: "?"
              tooltipText: "Keyboard shortcuts"
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              onClicked: root.toggleHelp()
            }

            PanelActionButton {
              visible: !root.showingSubview
              iconText: "+"
              tooltipText: "Create event"
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              onClicked: root.startCreate()
            }
          }
        }

        Rectangle {
          width: parent.width
          height: 1
          color: Util.alpha(root.contentForeground, 0.12)
        }

        Item {
          width: parent.width
          height: Math.max(0, parent.height - y)

          TextField {
            id: searchField
            visible: root.searching && !root.showingDetails && !root.showingSettings && !root.showingEditor && !root.showingCalendarEditor && !root.showingAccountEditor && !root.showingAccountDetails && !root.showingAccountCalendars && !root.showingIcalImport && !root.showingHelp && root.agendaData.status === "ok"
            enabled: visible
            activeFocusOnPress: visible
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: visible ? Style.space(34) : 0
            text: root.searchQuery
            placeholderText: "Search events"
            color: root.contentForeground
            placeholderTextColor: Util.alpha(root.contentForeground, 0.46)
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.body
            leftPadding: Style.space(10)
            rightPadding: Style.space(10)
            selectByMouse: true
            onTextEdited: root.searchQuery = text
            Keys.onPressed: function(event) {
              if (event.key === Qt.Key_Escape) {
                if (text !== "") {
                  text = ""
                  root.searchQuery = ""
                } else {
                  root.endSearch()
                }
                event.accepted = true
              } else if (event.key === Qt.Key_Down) {
                root.moveSelection(1)
                event.accepted = true
              } else if (event.key === Qt.Key_Up) {
                root.moveSelection(-1)
                event.accepted = true
              } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.activateSelection()
                event.accepted = true
              }
            }

            background: Rectangle {
              radius: Style.cornerRadius
              color: Util.alpha(root.contentForeground, searchField.activeFocus ? 0.10 : 0.06)
              border.width: 1
              border.color: Util.alpha(root.contentForeground, searchField.activeFocus ? 0.28 : 0.12)
            }
          }

          Text {
            visible: !root.showingDetails && !root.showingSettings && !root.showingEditor && !root.showingCalendarEditor && !root.showingAccountEditor && !root.showingAccountDetails && !root.showingAccountCalendars && !root.showingIcalImport && !root.showingHelp && root.agendaData.status === "unavailable"
            anchors.centerIn: parent
            width: parent.width - Style.space(24)
            text: "Chroncal is unavailable\nThe agenda will retry automatically."
            color: Util.alpha(root.contentForeground, 0.66)
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.body
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
          }

          Column {
            visible: !root.showingDetails && !root.showingSettings && !root.showingEditor && !root.showingCalendarEditor && !root.showingAccountEditor && !root.showingAccountDetails && !root.showingAccountCalendars && !root.showingIcalImport && !root.showingHelp && root.agendaData.status === "ok" && root.groups.length === 0
            anchors.centerIn: parent
            width: parent.width - Style.space(24)
            spacing: Style.space(10)

            Text {
              visible: root.calendars.length === 0 && root.searchQuery === ""
              width: parent.width
              horizontalAlignment: Text.AlignHCenter
              text: "No calendars yet"
              color: Util.alpha(root.contentForeground, 0.66)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.body
            }

            Text {
              visible: root.calendars.length === 0 && root.searchQuery === ""
              width: parent.width
              horizontalAlignment: Text.AlignHCenter
              wrapMode: Text.WordWrap
              text: "Add a CalDAV account or create a local calendar to see events here."
              color: Util.alpha(root.contentForeground, 0.56)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
            }

            Row {
              visible: root.calendars.length === 0 && root.searchQuery === ""
              anchors.horizontalCenter: parent.horizontalCenter
              spacing: Style.space(8)

              Button {
                text: "Add account"
                bordered: true
                focusable: true
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                enabled: !root.mutationBusy
                opacity: enabled ? 1 : 0.55
                onClicked: root.openAccountCreate()
              }

              Button {
                text: "New calendar"
                bordered: true
                focusable: true
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                enabled: !root.mutationBusy
                opacity: enabled ? 1 : 0.55
                onClicked: root.openCalendarCreate()
              }
            }

            Text {
              visible: root.calendars.length > 0 || root.searchQuery !== ""
              text: root.searchQuery !== "" ? "No matching events" : "No upcoming events"
              color: Util.alpha(root.contentForeground, 0.66)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.body
            }
          }

          Flickable {
            id: agendaFlick
            visible: !root.showingDetails && !root.showingSettings && !root.showingEditor && !root.showingCalendarEditor && !root.showingAccountEditor && !root.showingAccountDetails && !root.showingAccountCalendars && !root.showingIcalImport && !root.showingHelp && root.agendaData.status === "ok" && root.groups.length > 0
            anchors.top: searchField.bottom
            anchors.topMargin: searchField.visible ? Style.space(10) : 0
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            contentWidth: width
            contentHeight: groupsColumn.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick
            interactive: contentHeight > height
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            Column {
              id: groupsColumn
              width: agendaFlick.width
              spacing: Style.space(14)

              Repeater {
                model: root.groups

                Column {
                  required property var modelData
                  property var groupData: modelData
                  width: groupsColumn.width
                  spacing: Style.space(4)

                  Text {
                    width: parent.width
                    text: parent.groupData.label.toUpperCase()
                    color: Util.alpha(root.contentForeground, 0.52)
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    font.letterSpacing: 1
                  }

                  Repeater {
                    model: parent.groupData.events

                    EventRow {
                      id: eventRow
                      required property var modelData
                      width: groupsColumn.width
                      bar: root.bar
                      eventData: modelData
                      nowIso: root.agendaData.generated_at || ""
                      selected: root.selectedEventKey === Model.eventKey(modelData)
                      onSelectedChanged: {
                        if (selected) Qt.callLater(function() { root.ensureAgendaItemVisible(eventRow) })
                      }
                      onActivated: function(eventData) { root.showEvent(eventData) }
                    }
                  }
                }
              }
            }
          }

          EventDetails {
            visible: root.showingDetails
            enabled: !deleteConfirm.opened
            anchors.fill: parent
            bar: root.bar
            eventData: root.selectedEvent || ({})
            nowIso: root.agendaData.generated_at || ""
            actionStatus: root.actionStatus
            busy: root.mutationBusy || root.editLoadBusy
            showOpenInChroncal: Model.showOpenInChroncalEnabled(root.settings)
            onJoinRequested: root.joinEvent()
            onMapRequested: root.openMap()
            onChroncalRequested: root.openChroncal()
            onEditRequested: root.startEdit()
            onDeleteRequested: root.requestDelete()
            onRsvpRequested: function(status) { root.rsvpEvent(status) }
            onLinkRequested: function(url) { root.openUrl(url) }
          }

          EventEditor {
            id: eventEditor
            visible: root.showingEditor
            anchors.fill: parent
            bar: root.bar
            editorMode: root.editorMode
            eventData: root.editorEvent
            editingSeries: root.editingSeries
            calendars: root.calendars
            busy: root.mutationBusy
            externalError: root.mutationError
            onCanceled: root.cancelEditor()
            onSubmitted: function(values) { root.submitEditor(values) }
          }

          CalendarSettings {
            visible: root.showingSettings && !root.showingCalendarEditor
              && !root.showingAccountEditor && !root.showingAccountDetails
              && !root.showingAccountCalendars && !root.showingIcalImport
            anchors.fill: parent
            bar: root.bar
            calendars: root.calendars
            accounts: root.accounts
            busy: root.mutationBusy
            syncStatus: root.syncStatusRows
            syncIssues: root.syncIssueRows
            syncStateBusy: root.syncStateBusy
            statusText: root.actionStatus
            errorText: root.settingsErrorText
            includedCalendarIds: Model.selectedCalendarIds(root.calendars, root.settings)
            calendarSelectionCustomized: Model.calendarSelectionCustomized(root.settings)
            showTime: root.setting("showTime", "On")
            showTitle: root.setting("showTitle", "On")
            relativeLeadMinutes: Number(root.setting("relativeLeadMinutes", 10))
            lookaheadDays: Number(root.setting("lookaheadDays", 7))
            showAllDay: root.setting("showAllDay", "On")
            showEventsWithoutParticipants: root.setting("showEventsWithoutParticipants", "On")
            showEventsWithoutLocation: root.setting("showEventsWithoutLocation", "On")
            showOpenInChroncal: root.setting("showOpenInChroncal", "Off")
            onConfigurationChanged: function(values) { root.persistSettings(values) }
            onNewCalendarRequested: root.openCalendarCreate()
            onEditCalendarRequested: function(calendar) { root.openCalendarEdit(calendar) }
            onAddAccountRequested: root.openAccountCreate()
            onOpenAccountRequested: function(account) { root.openAccountDetails(account) }
            onImportIcalRequested: root.openIcalImport()
            onSyncRequested: function(account) {
              if (!root.mutationBusy) root.runMutation(Model.syncRunAccountArgs(account), "sync-run")
            }
            onResolveRequested: function(issue, pick) {
              var args = Model.syncResolveArgs({ id: (issue || {}).id, pick: pick })
              if (!root.mutationBusy && args.length > 0) root.runMutation(args, "sync-resolve")
            }
            onResetRequested: function(row) { root.requestSyncReset(row) }
          }

          CalendarEditor {
            id: calendarEditor
            visible: root.showingCalendarEditor
            anchors.fill: parent
            bar: root.bar
            mode: root.calendarEditorMode
            calendar: root.calendarEditorTarget
            calendars: root.calendars
            busy: root.mutationBusy
            externalError: root.mutationError
            onCanceled: root.closeCalendarEditor()
            onSubmitted: function(values) { root.submitCalendarEditor(values) }
          }

          AccountEditor {
            id: accountEditor
            visible: root.showingAccountEditor
            enabled: !deleteConfirm.opened
            anchors.fill: parent
            bar: root.bar
            busy: root.mutationBusy
            busyLabel: root.accountBusyLabel
            externalError: root.mutationError
            onCanceled: root.closeAccountEditor()
            onSubmitted: function(values) { root.submitAccountEditor(values) }
            onCancelRequested: root.cancelSetupMutation()
          }

          AccountDetails {
            id: accountDetails
            visible: root.showingAccountDetails && !root.showingAccountCalendars
            enabled: !deleteConfirm.opened
            anchors.fill: parent
            bar: root.bar
            account: root.accountDetailsTarget
            calendars: root.calendars
            busy: root.mutationBusy
            busyLabel: root.accountBusyLabel
            externalError: root.mutationError
            onCanceled: root.closeAccountDetails()
            onSubmitted: function(values) { root.submitAccountDetails(values) }
            onCancelRequested: root.cancelSetupMutation()
            onManageCalendarsRequested: root.openAccountCalendars(root.accountDetailsTarget)
          }

          AccountCalendars {
            id: accountCalendars
            visible: root.showingAccountCalendars
            enabled: !deleteConfirm.opened
            anchors.fill: parent
            bar: root.bar
            account: root.accountCalendarsAccount
            rows: root.discoveryRows
            loading: root.discoveryBusy
            busy: root.mutationBusy
            externalError: root.discoveryError !== "" ? root.discoveryError : root.mutationError
            defaultCalendarId: {
              var target = String((root.accountCalendarsAccount || {}).id || "")
              if (target === "") return ""
              var list = root.calendars
              for (var i = 0; i < list.length; i += 1) {
                var calendar = list[i] || {}
                if (calendar.is_default === true && String(calendar.account_id || "") === target)
                  return String(calendar.id)
              }
              return ""
            }
            onCanceled: root.closeAccountCalendars()
            onSubmitted: function(values) { root.submitAccountCalendars(values) }
          }

          IcalImport {
            id: icalImport
            visible: root.showingIcalImport
            enabled: !deleteConfirm.opened
            anchors.fill: parent
            bar: root.bar
            calendars: root.calendars
            busy: root.mutationBusy
            externalError: root.mutationError
            onCanceled: root.closeIcalImport()
            onSubmitted: function(values) { root.submitIcalImport(values) }
          }

          ShortcutHelp {
            visible: root.showingHelp
            anchors.fill: parent
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            onCloseRequested: root.toggleHelp()
          }

        }
      }

      DeleteConfirm {
        id: deleteConfirm
        anchors.fill: parent
        z: 20
        question: root.pendingSyncResetCalendar !== null
          ? "Reset sync state for “" + String((root.pendingSyncResetCalendar || {}).calendar_name || "this calendar") + "”?"
          : ""
        title: root.pendingSyncResetCalendar !== null
          ? String((root.pendingSyncResetCalendar || {}).calendar_name || "this calendar")
          : (root.pendingDeleteAccount !== null
            ? String((root.pendingDeleteAccount || {}).display_name
              || (root.accountDetailsTarget || {}).display_name || "this account")
            : (root.pendingDeleteCalendarValues !== null
              ? String((root.calendarEditorTarget || {}).name || "this calendar")
              : String((root.pendingDeleteEvent || root.selectedEvent) ? (root.pendingDeleteEvent || root.selectedEvent).title : "this event")))
        background: root.bar ? root.bar.background : Color.background
        foreground: root.contentForeground
        fontFamily: root.contentFontFamily
        onCanceled: root.dismissCalendarDeleteConfirm()
        onChosen: function(scope) {
          if (root.pendingSyncResetCalendar !== null) root.confirmSyncReset()
          else if (root.pendingDeleteAccount !== null) root.confirmAccountRemove()
          else if (root.pendingDeleteCalendarValues !== null) root.confirmCalendarDelete()
          else root.confirmDelete(scope)
        }
      }
    }
  }
}
