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
  property bool showingSettings: false
  property bool showingHelp: false
  readonly property bool showingSubview: showingDetails || showingEditor || showingSettings || showingHelp
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

  readonly property color contentForeground: bar ? bar.foreground : Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family

  function open() {
    if (hostWidget && hostWidget.refresh) hostWidget.refresh()
    root.controller.show()
  }

  function close() {
    root.selectedEvent = null
    root.selectedEventKey = ""
    root.resetSearch()
    root.editorMode = ""
    root.showingSettings = false
    root.showingHelp = false
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
    actionStatus = ""
    resetEditState()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function backToAgenda() {
    selectedEvent = null
    editorMode = ""
    showingSettings = false
    showingHelp = false
    actionStatus = ""
    resetEditState()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function toggleSettings() {
    selectedEvent = null
    editorMode = ""
    showingHelp = false
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
    if (showingDetails || showingSettings || showingEditor || showingHelp || visibleEvents.length === 0) return
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
    if (showingDetails || showingSettings || showingEditor || showingHelp || visibleEvents.length === 0) return
    var index = Model.adjacentDayFirstEventIndex(visibleEvents, selectedEventIndex(), direction)
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
    if (showingDetails || showingSettings || showingEditor || showingHelp || visibleEvents.length === 0) return
    var current = selectedEventIndex()
    showEvent(visibleEvents[current < 0 ? 0 : current])
  }

  function beginSearch() {
    if (showingDetails || showingSettings || showingEditor || showingHelp || agendaData.status !== "ok") return
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

  function finishMutation(exitCode) {
    mutationBusy = false
    if (exitCode !== 0) {
      mutationError = String(mutationStderrText || mutationStdoutText || "Chroncal could not save the event").trim()
      actionStatus = mutationError
      actionStatusTimer.restart()
      return
    }
    var completed = mutationKind
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

  function emailParticipants() {
    if (mutationBusy || editLoadBusy) return
    openUrl(Model.eventMailUrl(selectedEvent))
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
    Quickshell.execDetached(["omarchy-launch-floating-terminal-with-presentation", "chroncal"])
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
        else if (!root.showingDetails && !root.showingSettings && !root.showingEditor && (text === "t" || text === "T")) root.selectToday()
        else if (!root.showingSettings && !root.showingEditor && (text === "e" || text === "E")) root.startEdit()
        else if (root.showingDetails && (text === "v" || text === "V")) root.joinEvent()
        else if (root.showingDetails && (text === "p" || text === "P")) root.copyEventDetails()
        else if (root.showingDetails && (text === "g" || text === "G")) root.openChroncal()
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
            text: root.showingEditor ? (root.editorMode === "edit" ? "EDIT EVENT" : "NEW EVENT") : (root.showingDetails ? "EVENT DETAILS" : (root.showingSettings ? "SETTINGS" : (root.showingHelp ? "SHORTCUTS" : "UPCOMING")))
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
            visible: root.searching && !root.showingDetails && !root.showingSettings && !root.showingEditor && !root.showingHelp && root.agendaData.status === "ok"
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
            visible: !root.showingDetails && !root.showingSettings && !root.showingEditor && !root.showingHelp && root.agendaData.status === "unavailable"
            anchors.centerIn: parent
            anchors.verticalCenterOffset: settingsFooter.visible ? -settingsFooter.height / 2 : 0
            width: parent.width - Style.space(24)
            text: "Chroncal is unavailable\nThe agenda will retry automatically."
            color: Util.alpha(root.contentForeground, 0.66)
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.body
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
          }

          Text {
            visible: !root.showingDetails && !root.showingSettings && !root.showingEditor && !root.showingHelp && root.agendaData.status === "ok" && root.groups.length === 0
            anchors.centerIn: parent
            anchors.verticalCenterOffset: settingsFooter.visible ? -settingsFooter.height / 2 : 0
            text: root.searchQuery !== "" ? "No matching events" : "No upcoming events"
            color: Util.alpha(root.contentForeground, 0.66)
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.body
          }

          Flickable {
            id: agendaFlick
            visible: !root.showingDetails && !root.showingSettings && !root.showingEditor && !root.showingHelp && root.agendaData.status === "ok" && root.groups.length > 0
            anchors.top: searchField.bottom
            anchors.topMargin: searchField.visible ? Style.space(10) : 0
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: settingsFooter.top
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
            actionStatus: root.actionStatus
            busy: root.mutationBusy || root.editLoadBusy
            onJoinRequested: root.joinEvent()
            onMapRequested: root.openMap()
            onEmailRequested: root.emailParticipants()
            onCopyRequested: root.copyEventDetails()
            onChroncalRequested: root.openChroncal()
            onEditRequested: root.startEdit()
            onDeleteRequested: root.requestDelete()
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
            onConfigurationChanged: function(values) { root.persistSettings(values) }
          }

          ShortcutHelp {
            visible: root.showingHelp
            anchors.fill: parent
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            onCloseRequested: root.toggleHelp()
          }

          Item {
            id: settingsFooter
            visible: !root.showingSubview
            height: visible ? 1 + Style.space(6) + Style.space(32) : 0
            z: 1
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom

            Rectangle {
              width: parent.width
              height: 1
              color: Util.alpha(root.contentForeground, 0.12)
            }

            Rectangle {
              anchors.fill: parent
              anchors.topMargin: 1
              radius: Style.cornerRadius
              color: settingsFooterMouse.containsMouse ? Util.alpha(root.contentForeground, 0.10) : "transparent"
            }

            Text {
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              anchors.verticalCenterOffset: 1
              text: "Calendar Settings…"
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.body
            }

            MouseArea {
              id: settingsFooterMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.toggleSettings()
            }
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
