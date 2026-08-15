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
  property bool mutationBusy: false
  property string mutationKind: ""
  property string mutationError: ""
  property string mutationStdoutText: ""
  property string mutationStderrText: ""
  property string actionStatus: ""

  readonly property color contentForeground: bar ? bar.foreground : Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family

  function open() {
    if (hostWidget && hostWidget.refresh) hostWidget.refresh()
    root.controller.show()
  }

  function close() {
    root.selectedEvent = null
    root.selectedEventKey = ""
    root.searchQuery = ""
    root.editorMode = ""
    root.showingSettings = false
    root.showingHelp = false
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
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function backToAgenda() {
    selectedEvent = null
    editorMode = ""
    showingSettings = false
    showingHelp = false
    actionStatus = ""
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function toggleSettings() {
    selectedEvent = null
    editorMode = ""
    showingHelp = false
    showingSettings = showingSettings ? false : true
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

  function activateSelection() {
    if (showingDetails || showingSettings || showingEditor || showingHelp || visibleEvents.length === 0) return
    var current = selectedEventIndex()
    showEvent(visibleEvents[current < 0 ? 0 : current])
  }

  function beginSearch() {
    if (showingDetails || showingSettings || showingEditor || showingHelp || agendaData.status !== "ok") return
    Qt.callLater(function() { searchField.forceActiveFocus() })
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
    editorMode = "create"
  }

  function startEdit() {
    if (!selectedEvent || !Model.canMutateEvent(selectedEvent)) return
    showingSettings = false
    showingHelp = false
    mutationError = ""
    editorMode = "edit"
    Qt.callLater(function() { eventEditor.initialize() })
  }

  function cancelEditor() {
    var wasEditing = editorMode === "edit"
    editorMode = ""
    mutationError = ""
    if (!wasEditing) selectedEvent = null
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function submitEditor(values) {
    var args = Model.eventMutationArgs(editorMode, selectedEvent, values)
    if (args.length === 0) {
      mutationError = "Check the event fields"
      return
    }
    runMutation(args, editorMode)
  }

  function requestDelete() {
    if (!selectedEvent || mutationBusy || !Model.canMutateEvent(selectedEvent)) return
    deleteConfirm.selectedIndex = 1
    deleteConfirm.opened = true
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function confirmDelete() {
    deleteConfirm.opened = false
    var args = Model.eventDeleteArgs(selectedEvent)
    if (args.length === 0) return
    runMutation(args, "delete")
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
    actionStatus = completed === "delete" ? "Event deleted" : (completed === "edit" ? "Event updated" : "Event created")
    actionStatusTimer.restart()
    refresh()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function openUrl(url) {
    if (!url) return
    Quickshell.execDetached(["xdg-open", String(url)])
  }

  function joinEvent() {
    openUrl(Model.eventOpenUrl(selectedEvent))
  }

  function openMap() {
    openUrl(Model.eventMapUrl(selectedEvent))
  }

  function emailParticipants() {
    openUrl(Model.eventMailUrl(selectedEvent))
  }

  function copyEventDetails() {
    var details = Model.eventDetailsText(selectedEvent)
    if (!details) return
    Quickshell.execDetached(["wl-copy", details])
    actionStatus = "Copied event details"
    actionStatusTimer.restart()
  }

  function openChroncal() {
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
      blocked: searchField.activeFocus || root.showingEditor
      onMoveRequested: function(dx, dy) {
        if (deleteConfirm.opened) {
          if (dx !== 0 || dy !== 0) deleteConfirm.selectedIndex = deleteConfirm.selectedIndex === 0 ? 1 : 0
          return
        }
        if (!root.showingDetails && !root.showingSettings && !root.showingEditor && dy !== 0) root.moveSelection(dy)
      }
      onCloseRequested: {
        if (deleteConfirm.opened) deleteConfirm.opened = false
        else if (root.showingEditor) root.cancelEditor()
        else if (root.showingDetails || root.showingSettings || root.showingHelp) root.backToAgenda()
        else root.close()
      }
      onActivateRequested: {
        if (deleteConfirm.opened) {
          if (deleteConfirm.selectedIndex === 0) deleteConfirm.opened = false
          else root.confirmDelete()
        } else if (!root.showingDetails && !root.showingSettings && !root.showingEditor && !root.showingHelp) root.activateSelection()
      }
      onTabRequested: function(direction) {
        if (deleteConfirm.opened) deleteConfirm.selectedIndex = deleteConfirm.selectedIndex === 0 ? 1 : 0
        else root.switchPanel(direction)
      }
      onDeleteRequested: {
        if (root.showingDetails) root.requestDelete()
      }
      onTextKey: function(text) {
        if (text === "?") root.toggleHelp()
        else if (root.showingHelp) return
        else if (text === "r" || text === "R") root.refresh()
        else if (text === "/") root.beginSearch()
        else if (text === ",") root.toggleSettings()
        else if (!root.showingDetails && !root.showingSettings && !root.showingEditor && text === "N") root.startCreate()
        else if (!root.showingDetails && !root.showingSettings && !root.showingEditor && text === "n") root.moveSelection(1)
        else if (!root.showingDetails && !root.showingSettings && !root.showingEditor && (text === "p" || text === "P" || text === "b" || text === "B")) root.moveSelection(-1)
        else if (!root.showingDetails && !root.showingSettings && !root.showingEditor && (text === "t" || text === "T")) root.selectToday()
        else if (root.showingDetails && (text === "e" || text === "E")) root.startEdit()
        else if (root.showingDetails && (text === "d" || text === "D")) root.requestDelete()
        else if (root.showingDetails && (text === "j" || text === "J")) root.joinEvent()
        else if (root.showingDetails && (text === "c" || text === "C")) root.copyEventDetails()
        else if (root.showingDetails && (text === "o" || text === "O")) root.openChroncal()
      }

      Column {
        anchors.fill: parent
        anchors.margins: Style.space(16)
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

            Text {
              visible: root.showingDetails
              anchors.verticalCenter: parent.verticalCenter
              text: "ESC  Back"
              color: Util.alpha(root.contentForeground, 0.58)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
            }

            PanelActionButton {
              visible: root.showingEditor
              iconText: "←"
              tooltipText: "Cancel and go back"
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              onClicked: root.cancelEditor()
            }

            PanelActionButton {
              visible: !root.showingDetails && !root.showingEditor && !root.showingHelp
              iconText: root.showingSettings ? "←" : "󰒓"
              tooltipText: root.showingSettings ? "Back to agenda" : "Calendar settings"
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              onClicked: root.toggleSettings()
            }

            PanelActionButton {
              visible: root.showingHelp
              iconText: "←"
              tooltipText: "Back to agenda"
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              onClicked: root.toggleHelp()
            }

            PanelActionButton {
              visible: !root.showingDetails && !root.showingSettings && !root.showingEditor && !root.showingHelp
              iconText: "?"
              tooltipText: "Keyboard shortcuts (?)"
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              onClicked: root.toggleHelp()
            }

            PanelActionButton {
              visible: !root.showingDetails && !root.showingSettings && !root.showingEditor && !root.showingHelp
              iconText: "+"
              tooltipText: "Create event (Shift+N)"
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              onClicked: root.startCreate()
            }

            PanelActionButton {
              visible: !root.showingDetails && !root.showingSettings && !root.showingEditor && !root.showingHelp
              iconText: "󰑐"
              tooltipText: root.hostWidget && root.hostWidget.loading ? "Refreshing" : "Refresh agenda"
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              enabled: !(root.hostWidget && root.hostWidget.loading)
              onClicked: root.refresh()
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
          height: parent.height - Style.space(50)

          TextField {
            id: searchField
            visible: !root.showingDetails && !root.showingSettings && !root.showingEditor && !root.showingHelp && root.agendaData.status === "ok"
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: Style.space(34)
            text: root.searchQuery
            placeholderText: "Search events  /"
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
                  keyCatcher.forceActiveFocus()
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
            text: root.searchQuery !== "" ? "No matching events" : "No upcoming events"
            color: Util.alpha(root.contentForeground, 0.66)
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.body
          }

          Flickable {
            id: agendaFlick
            visible: !root.showingDetails && !root.showingSettings && !root.showingEditor && !root.showingHelp && root.agendaData.status === "ok" && root.groups.length > 0
            anchors.top: searchField.bottom
            anchors.topMargin: Style.space(10)
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
            anchors.fill: parent
            bar: root.bar
            eventData: root.selectedEvent || ({})
            actionStatus: root.actionStatus
            busy: root.mutationBusy
            onBackRequested: root.backToAgenda()
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
            eventData: root.selectedEvent
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
            includedCalendarIds: root.setting("includedCalendarIds", [])
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

          ConfirmDialog {
            id: deleteConfirm
            anchors.fill: parent
            z: 20
            message: "Delete “" + String(root.selectedEvent ? root.selectedEvent.title : "this event") + "”?"
            confirmText: "Delete"
            background: root.bar ? root.bar.background : Color.background
            foreground: root.contentForeground
            fontFamily: root.contentFontFamily
            onCanceled: opened = false
            onConfirmed: root.confirmDelete()
          }
        }
      }
    }
  }
}
