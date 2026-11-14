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
  readonly property string nowIso: hostWidget ? hostWidget.nowIso : new Date().toISOString()
  readonly property string localTimezone: hostWidget && hostWidget.agendaData ? String(hostWidget.agendaData.local_timezone || "") : ""
  // Recomputed per minute, not per clock tick, so rows do not churn.
  readonly property string nowMinute: nowIso.slice(0, 16) + ":00Z"
  readonly property var groups: Model.groupEvents(
    Model.searchEvents(Model.activeEvents(agendaData.events || [], nowMinute), searchQuery),
    nowMinute,
    { includeToday: searchQuery === "" && agendaData.status === "ok" }
  )
  // Keyboard order follows the rendered order (all-day first in each day).
  readonly property var visibleEvents: Model.agendaOrder(groups)
  readonly property var calendars: hostWidget ? (hostWidget.agendaData.calendars || []) : []
  property string selectedEventKey: ""
  property var selectedEvent: null
  property string editorMode: ""
  readonly property bool showingEditor: editorMode !== ""
  readonly property bool showingDetails: selectedEvent !== null && !showingEditor
  property bool showingSettings: false
  property bool showingHelp: false
  property bool showingAvailability: false
  readonly property bool showingSubview: showingDetails || showingEditor || showingSettings || showingHelp || showingAvailability
  readonly property bool showingMiniCalendar: setting("showMiniCalendar", "Off") === "On"
  property var editorPrefill: null
  // Free/busy uses every visible calendar, not just the agenda filters.
  readonly property var availabilityDays: Model.availabilitySlots(
    hostWidget && hostWidget.agendaData ? (hostWidget.agendaData.events || []) : [],
    nowMinute,
    {
      days: Number(setting("availabilityDays", 3)),
      startHour: Number(setting("availabilityStartHour", 9)),
      endHour: Number(setting("availabilityEndHour", 18)),
      minMinutes: Number(setting("availabilityMinMinutes", 30)),
      weekends: setting("availabilityWeekends", "Off") === "On",
      rangeTo: hostWidget && hostWidget.agendaData && hostWidget.agendaData.range ? String(hostWidget.agendaData.range.to || "") : ""
    }
  )
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
  property bool rsvpRefreshPending: false
  property string rsvpExpectedStatus: ""

  readonly property color contentForeground: bar ? bar.foreground : Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family

  function open() {
    if (hostWidget && hostWidget.refresh) hostWidget.refresh()
    // Start on the first thing that matters: what is on now or next.
    selectedEventKey = visibleEvents.length > 0 ? Model.eventKey(visibleEvents[0]) : ""
    agendaFlick.contentY = 0
    root.controller.show()
  }

  function close() {
    root.rsvpRefreshPending = false
    root.rsvpExpectedStatus = ""
    root.selectedEvent = null
    root.selectedEventKey = ""
    root.resetSearch()
    root.editorMode = ""
    root.showingSettings = false
    root.showingHelp = false
    root.showingAvailability = false
    root.resetEditState()
    root.pendingDeleteEvent = null
    deleteConfirm.opened = false
    root.controller.hide()
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
    showingSettings = false
    showingHelp = false
    showingAvailability = false
    actionStatus = ""
    resetEditState()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function backToAgenda() {
    rsvpRefreshPending = false
    rsvpExpectedStatus = ""
    selectedEvent = null
    editorMode = ""
    showingSettings = false
    showingHelp = false
    showingAvailability = false
    actionStatus = ""
    resetEditState()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function toggleSettings() {
    selectedEvent = null
    editorMode = ""
    showingHelp = false
    showingAvailability = false
    showingSettings = showingSettings ? false : true
    resetEditState()
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
    if (showingDetails || showingSettings || showingEditor || showingHelp || showingAvailability || visibleEvents.length === 0) return
    var current = selectedEventIndex()
    var next = current < 0 ? (step > 0 ? 0 : visibleEvents.length - 1) : Model.clampSelection(current + step, visibleEvents.length)
    selectedEventKey = Model.eventKey(visibleEvents[next])
  }

  function focusedEvent() {
    if (selectedEvent) return selectedEvent
    if (showingSettings || showingHelp || showingEditor) return null
    var current = selectedEventIndex()
    if (current < 0) return null
    return visibleEvents[current]
  }

  function moveSelectionByDay(direction) {
    if (showingDetails || showingSettings || showingEditor || showingHelp || showingAvailability || visibleEvents.length === 0) return
    var index = Model.adjacentDayFirstEventIndex(visibleEvents, selectedEventIndex(), direction, nowIso)
    if (index >= 0) selectedEventKey = Model.eventKey(visibleEvents[index])
  }

  function handleClose() {
    if (deleteConfirm.opened) {
      deleteConfirm.opened = false
      pendingDeleteEvent = null
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
    if (showingDetails || showingSettings || showingEditor || showingHelp || showingAvailability || visibleEvents.length === 0) return
    var current = selectedEventIndex()
    showEvent(visibleEvents[current < 0 ? 0 : current])
  }

  function beginSearch() {
    if (showingDetails || showingSettings || showingEditor || showingHelp || showingAvailability || agendaData.status !== "ok") return
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
    var maxY = Math.max(0, agendaFlick.contentHeight - agendaFlick.height)
    // Leave room above for the day header the row sits under.
    var top = selectedEventIndex() === 0 ? 0 : Math.max(0, point.y - Style.space(28))
    if (top < agendaFlick.contentY) agendaFlick.contentY = top
    else if (point.y + item.height > agendaFlick.contentY + agendaFlick.height)
      agendaFlick.contentY = Math.min(maxY, point.y + item.height - agendaFlick.height)
    if (agendaFlick.contentY > maxY) agendaFlick.contentY = maxY
  }

  function showFirstEvent() {
    activateSelection()
  }

  function selectToday() {
    var index = Model.firstEventIndexForDate(visibleEvents, nowIso)
    if (index >= 0) selectedEventKey = Model.eventKey(visibleEvents[index])
  }

  function toggleHelp() {
    selectedEvent = null
    editorMode = ""
    showingSettings = false
    showingAvailability = false
    showingHelp = showingHelp ? false : true
    resetEditState()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  onVisibleEventsChanged: syncSelectionToSearch()

  function toggleAvailability() {
    selectedEvent = null
    editorMode = ""
    showingSettings = false
    showingHelp = false
    resetEditState()
    resetSearch()
    showingAvailability = showingAvailability ? false : true
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function copyAvailability() {
    var text = Model.availabilityText(availabilityDays, localTimezone, nowMinute)
    if (text === "") {
      actionStatus = "No free time to share"
    } else {
      Quickshell.execDetached(["wl-copy", "--", text])
      actionStatus = "Copied availability"
    }
    actionStatusTimer.restart()
  }

  function bookSlot(day, slot) {
    var minutes = Math.round((slot.end.getTime() - slot.start.getTime()) / 60000)
    startCreate({
      date: day.key,
      time: Model.formatTime(slot.start),
      duration: minutes >= 30 ? "30m" : minutes + "m",
      allDay: false
    })
  }

  function toggleMiniCalendar() {
    persistSettings({ showMiniCalendar: showingMiniCalendar ? "Off" : "On" })
  }

  // Mini calendar click: select the first event listed on or after the day.
  function jumpToDay(key) {
    var index = Model.firstEventIndexOnOrAfterDay(visibleEvents, key, nowMinute)
    if (index < 0) {
      actionStatus = "Nothing scheduled from " + Model.shortDateLabel(Model.localDateFromKey(key))
      actionStatusTimer.restart()
      return
    }
    var target = visibleEvents[index]
    if (Model.eventDateKey(target, nowMinute) !== key) {
      actionStatus = "Nothing on " + Model.shortDateLabel(Model.localDateFromKey(key))
      actionStatusTimer.restart()
    }
    selectedEventKey = Model.eventKey(target)
  }

  function refresh() {
    if (hostWidget && hostWidget.refresh) hostWidget.refresh()
  }

  function startCreate(prefill) {
    selectedEvent = null
    showingSettings = false
    showingHelp = false
    showingAvailability = false
    editorPrefill = prefill || null
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
    var args = Model.eventMutationArgs(editorMode, editorEvent, values, { series: editingSeries, localTimezone: localTimezone })
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

  function runMutation(args, kind) {
    if (mutationBusy || !hostWidget || !hostWidget.chroncalExecScript) return
    mutationBusy = true
    mutationKind = kind
    mutationError = ""
    mutationStdoutText = ""
    mutationStderrText = ""
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

  function finishMutation(exitCode) {
    var completed = mutationKind
    mutationBusy = false
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
    if (completed !== "edit") selectedEventKey = ""
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

  function joinEvent(eventData) {
    if (mutationBusy || editLoadBusy) return
    var url = Model.eventOpenUrl(eventData || selectedEvent)
    if (url === "") return
    openUrl(url)
    if (eventData) root.close()
  }

  function copyEventLink() {
    if (mutationBusy || editLoadBusy) return
    var url = Model.eventOpenUrl(selectedEvent)
    if (url === "") return
    Quickshell.execDetached(["wl-copy", "--", url])
    actionStatus = "Copied link"
    actionStatusTimer.restart()
  }

  function openMap() {
    if (mutationBusy || editLoadBusy) return
    openUrl(Model.eventMapUrl(selectedEvent))
  }

  function copyEventDetails() {
    if (mutationBusy || editLoadBusy) return
    var details = Model.eventDetailsText(selectedEvent, nowIso)
    if (!details) return
    Quickshell.execDetached(["wl-copy", "--", details])
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
    interval: root.mutationError !== "" ? 6000 : 2200
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
    contentHeight: panel.fittedContentHeight(Style.space(root.showingMiniCalendar ? 660 : 520))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: (root.searching && searchField.activeFocus) || root.showingEditor
      onMoveRequested: function(dx, dy) {
        if (deleteConfirm.opened) {
          if (dx !== 0) deleteConfirm.cycle(dx)
          else if (dy !== 0) deleteConfirm.cycle(dy)
          return
        }
        if (root.showingDetails || root.showingSettings || root.showingEditor || root.showingHelp || root.showingAvailability) return
        if (dy !== 0) root.moveSelection(dy)
        else if (dx !== 0) root.moveSelectionByDay(dx)
      }
      onCloseRequested: root.handleClose()
      onActivateRequested: {
        if (deleteConfirm.opened) deleteConfirm.activate()
        else if (root.showingAvailability) root.copyAvailability()
        else if (!root.showingDetails && !root.showingSettings && !root.showingEditor && !root.showingHelp && !root.showingAvailability) root.activateSelection()
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
        else if (!root.showingDetails && !root.showingSettings && !root.showingEditor && text === "a") root.toggleAvailability()
        else if (!root.showingSubview && text === "m") root.toggleMiniCalendar()
        else if (!root.showingDetails && !root.showingSettings && !root.showingEditor && (text === "t" || text === "T")) root.selectToday()
        else if (!root.showingSettings && !root.showingEditor && (text === "e" || text === "E")) root.startEdit()
        else if (root.showingDetails && (text === "v" || text === "V")) root.joinEvent()
        else if (root.showingDetails && (text === "p" || text === "P")) root.copyEventDetails()
        else if (root.showingDetails && (text === "u" || text === "U")) root.copyEventLink()
        else if (!root.showingSubview && text === "o") root.joinEvent(root.focusedEvent())
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
            text: root.showingEditor ? (root.editorMode === "edit" ? "EDIT EVENT" : "NEW EVENT") : (root.showingDetails ? "EVENT DETAILS" : (root.showingSettings ? "SETTINGS" : (root.showingHelp ? "SHORTCUTS" : (root.showingAvailability ? "SHARE AVAILABILITY" : "UPCOMING"))))
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
              tooltipText: root.showingEditor ? "Cancel and go back" : "Back to agenda"
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              onClicked: {
                if (deleteConfirm.opened) deleteConfirm.opened = false
                else if (root.showingEditor) root.cancelEditor()
                else root.backToAgenda()
              }
            }

            PanelActionButton {
              visible: !root.showingSubview
              iconText: "󰃭"
              tooltipText: root.showingMiniCalendar ? "Hide mini calendar (m)" : "Show mini calendar (m)"
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              onClicked: root.toggleMiniCalendar()
            }

            PanelActionButton {
              visible: !root.showingSubview
              iconText: "󰃰"
              tooltipText: "Share availability (a)"
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              onClicked: root.toggleAvailability()
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

          MiniCalendar {
            id: miniCalendar
            visible: root.showingMiniCalendar && !root.showingSubview && root.agendaData.status === "ok"
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: visible ? implicitHeight : 0
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            events: root.agendaData.events || []
            todayKey: root.nowMinute !== "" ? Model.eventDateKey({ start_time: root.nowMinute }) : ""
            selectedKey: root.selectedEventKey !== "" && root.selectedEventIndex() >= 0
              ? Model.eventDateKey(root.visibleEvents[root.selectedEventIndex()], root.nowMinute) : ""
            rangeFrom: root.agendaData.range ? String(root.agendaData.range.from || "") : ""
            rangeTo: root.agendaData.range ? String(root.agendaData.range.to || "") : ""
            onDaySelected: function(key) { root.jumpToDay(key) }
          }

          Rectangle {
            id: miniCalendarRule
            visible: miniCalendar.visible
            anchors.top: miniCalendar.bottom
            anchors.topMargin: visible ? Style.space(8) : 0
            width: parent.width
            height: visible ? 1 : 0
            color: Util.alpha(root.contentForeground, 0.08)
          }

          TextField {
            id: searchField
            visible: root.searching && !root.showingDetails && !root.showingSettings && !root.showingEditor && !root.showingHelp && !root.showingAvailability && root.agendaData.status === "ok"
            enabled: visible
            activeFocusOnPress: visible
            anchors.top: miniCalendarRule.bottom
            anchors.topMargin: miniCalendar.visible ? Style.space(8) : 0
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
            visible: !root.showingDetails && !root.showingSettings && !root.showingEditor && !root.showingHelp && !root.showingAvailability && root.agendaData.status === "unavailable"
            anchors.centerIn: parent
            width: parent.width - Style.space(24)
            text: "Chroncal is unavailable\nThe agenda will retry automatically."
            color: Util.alpha(root.contentForeground, 0.66)
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.body
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
          }

          Text {
            visible: !root.showingDetails && !root.showingSettings && !root.showingEditor && !root.showingHelp && !root.showingAvailability && root.agendaData.status === "ok" && root.visibleEvents.length === 0
            anchors.centerIn: parent
            anchors.verticalCenterOffset: root.groups.length > 0 ? Style.space(24) : 0
            text: root.searchQuery !== "" ? "No matching events" : "Nothing else in the next " + Number(root.setting("lookaheadDays", 7)) + " days"
            color: Util.alpha(root.contentForeground, 0.66)
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.body
          }

          Flickable {
            id: agendaFlick
            visible: !root.showingDetails && !root.showingSettings && !root.showingEditor && !root.showingHelp && !root.showingAvailability && root.agendaData.status === "ok" && root.groups.length > 0
            anchors.top: searchField.bottom
            anchors.topMargin: searchField.visible || miniCalendar.visible ? Style.space(10) : 0
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

                  Item {
                    width: parent.width
                    height: groupLabel.implicitHeight

                    Text {
                      id: groupLabel
                      anchors.left: parent.left
                      text: parent.parent.groupData.label.toUpperCase()
                      color: parent.parent.groupData.today ? root.contentForeground : Util.alpha(root.contentForeground, 0.52)
                      font.family: root.contentFontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: true
                      font.letterSpacing: 1
                    }

                    Text {
                      anchors.right: parent.right
                      anchors.baseline: groupLabel.baseline
                      visible: parent.parent.groupData.label.indexOf(",") === -1
                      text: parent.parent.groupData.detail
                      color: Util.alpha(root.contentForeground, 0.42)
                      font.family: root.contentFontFamily
                      font.pixelSize: Style.font.caption
                    }
                  }

                  Text {
                    visible: parent.groupData.events.length === 0
                    width: parent.width
                    leftPadding: Style.space(12)
                    topPadding: Style.space(4)
                    bottomPadding: Style.space(4)
                    text: "No more events today"
                    color: Util.alpha(root.contentForeground, 0.46)
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.bodySmall
                  }

                  Repeater {
                    model: parent.groupData.events

                    EventRow {
                      id: eventRow
                      required property var modelData
                      width: groupsColumn.width
                      bar: root.bar
                      eventData: modelData
                      nowIso: root.nowIso
                      selected: root.selectedEventKey === Model.eventKey(modelData)
                      busy: root.mutationBusy || root.editLoadBusy
                      onSelectedChanged: {
                        if (selected) Qt.callLater(function() { root.ensureAgendaItemVisible(eventRow) })
                      }
                      onActivated: function(eventData) { root.showEvent(eventData) }
                      onJoinRequested: function(eventData) { root.joinEvent(eventData) }
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
            nowIso: root.nowIso
            actionStatus: root.actionStatus
            busy: root.mutationBusy || root.editLoadBusy
            showOpenInChroncal: Model.showOpenInChroncalEnabled(root.settings)
            onJoinRequested: root.joinEvent()
            onCopyLinkRequested: root.copyEventLink()
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
            localTimezone: root.localTimezone
            personalMeetingUrl: String(root.setting("personalMeetingUrl", ""))
            prefill: root.editorPrefill
            busy: root.mutationBusy
            externalError: root.mutationError
            onCanceled: root.cancelEditor()
            onSubmitted: function(values) { root.submitEditor(values) }
          }

          CalendarSettings {
            visible: root.showingSettings
            anchors.fill: parent
            bar: root.bar
            calendars: root.calendars
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
            showDeclinedEvents: root.setting("showDeclinedEvents", "On")
            barHorizonHours: Number(root.setting("barHorizonHours", 0))
            joinReminderMinutes: Number(root.setting("joinReminderMinutes", -1))
            showMiniCalendar: root.setting("showMiniCalendar", "Off")
            personalMeetingUrl: String(root.setting("personalMeetingUrl", ""))
            onConfigurationChanged: function(values) { root.persistSettings(values) }
          }

          Rectangle {
            id: agendaToast
            z: 5
            visible: root.actionStatus !== "" && !root.showingDetails && !root.showingEditor && !root.showingAvailability
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            width: Math.min(parent.width, toastText.implicitWidth + Style.space(24))
            height: toastText.implicitHeight + Style.space(12)
            radius: Style.cornerRadius
            color: root.bar ? root.bar.background : Color.background
            border.width: 1
            border.color: Util.alpha(root.contentForeground, 0.2)

            Text {
              id: toastText
              anchors.centerIn: parent
              width: Math.min(implicitWidth, parent.parent.width - Style.space(24))
              text: root.actionStatus
              textFormat: Text.PlainText
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
            }
          }

          AvailabilityView {
            visible: root.showingAvailability
            anchors.fill: parent
            bar: root.bar
            days: root.availabilityDays
            timezone: root.localTimezone
            nowIso: root.nowMinute
            availabilityDays: Number(root.setting("availabilityDays", 3))
            startHour: Number(root.setting("availabilityStartHour", 9))
            endHour: Number(root.setting("availabilityEndHour", 18))
            minMinutes: Number(root.setting("availabilityMinMinutes", 30))
            weekends: root.setting("availabilityWeekends", "Off")
            actionStatus: root.actionStatus
            onCopyRequested: root.copyAvailability()
            onSlotRequested: function(day, slot) { root.bookSlot(day, slot) }
            onConfigurationChanged: function(values) { root.persistSettings(values) }
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
        title: String((root.pendingDeleteEvent || root.selectedEvent) ? (root.pendingDeleteEvent || root.selectedEvent).title : "this event")
        background: root.bar ? root.bar.background : Color.background
        foreground: root.contentForeground
        fontFamily: root.contentFontFamily
        onCanceled: {
          opened = false
          root.pendingDeleteEvent = null
        }
        onChosen: function(scope) { root.confirmDelete(scope) }
      }
    }
  }
}
