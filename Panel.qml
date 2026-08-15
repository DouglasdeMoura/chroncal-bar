pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell
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
  readonly property var groups: Model.groupEvents(agendaData.events || [], agendaData.generated_at || new Date().toISOString())
  readonly property var calendars: hostWidget ? (hostWidget.agendaData.calendars || []) : []
  property int selectedEventId: -1
  property var selectedEvent: null
  readonly property bool showingDetails: selectedEvent !== null
  property bool showingSettings: false
  property string actionStatus: ""

  readonly property color contentForeground: bar ? bar.foreground : Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family

  function open() {
    if (hostWidget && hostWidget.refresh) hostWidget.refresh()
    root.controller.show()
  }

  function close() {
    root.selectedEvent = null
    root.selectedEventId = -1
    root.showingSettings = false
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
    selectedEventId = Number(eventData.id)
    selectedEvent = eventData
    showingSettings = false
    actionStatus = ""
  }

  function backToAgenda() {
    selectedEvent = null
    showingSettings = false
    actionStatus = ""
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function toggleSettings() {
    selectedEvent = null
    showingSettings = showingSettings ? false : true
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function persistSettings(values) {
    var entry = { id: root.moduleName }
    for (var existing in root.settings) if (existing !== "id") entry[existing] = root.settings[existing]
    for (var key in values) entry[key] = values[key]
    root.settings = entry
    if (root.hostWidget && "settings" in root.hostWidget) root.hostWidget.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  function showFirstEvent() {
    var events = agendaData.events || []
    if (events.length > 0) showEvent(events[0])
  }

  function refresh() {
    if (hostWidget && hostWidget.refresh) hostWidget.refresh()
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
      onCloseRequested: {
        if (root.showingDetails || root.showingSettings) root.backToAgenda()
        else root.close()
      }
      onActivateRequested: {
        if (!root.showingDetails && !root.showingSettings) root.showFirstEvent()
      }
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(text) {
        if (text === "r" || text === "R") root.refresh()
        else if (text === ",") root.toggleSettings()
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
            text: root.showingDetails ? "EVENT DETAILS" : (root.showingSettings ? "SETTINGS" : "UPCOMING")
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
              visible: !root.showingDetails
              iconText: root.showingSettings ? "←" : "󰒓"
              tooltipText: root.showingSettings ? "Back to agenda" : "Calendar settings"
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              onClicked: root.toggleSettings()
            }

            PanelActionButton {
              visible: !root.showingDetails && !root.showingSettings
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

          Text {
            visible: !root.showingDetails && !root.showingSettings && root.agendaData.status === "unavailable"
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
            visible: !root.showingDetails && !root.showingSettings && root.agendaData.status === "ok" && root.groups.length === 0
            anchors.centerIn: parent
            text: "No upcoming events"
            color: Util.alpha(root.contentForeground, 0.66)
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.body
          }

          Flickable {
            id: agendaFlick
            visible: !root.showingDetails && !root.showingSettings && root.agendaData.status === "ok" && root.groups.length > 0
            anchors.fill: parent
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
                      required property var modelData
                      width: groupsColumn.width
                      bar: root.bar
                      eventData: modelData
                      nowIso: root.agendaData.generated_at || ""
                      selected: Number(root.selectedEventId) === Number(modelData.id)
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
            onBackRequested: root.backToAgenda()
            onJoinRequested: root.joinEvent()
            onMapRequested: root.openMap()
            onEmailRequested: root.emailParticipants()
            onCopyRequested: root.copyEventDetails()
            onChroncalRequested: root.openChroncal()
          }

          CalendarSettings {
            visible: root.showingSettings
            anchors.fill: parent
            bar: root.bar
            calendars: root.calendars
            includedCalendarIds: root.setting("includedCalendarIds", [])
            showTime: root.setting("showTime", "On")
            showTitle: root.setting("showTitle", "On")
            showAllDay: root.setting("showAllDay", "On")
            showEventsWithoutParticipants: root.setting("showEventsWithoutParticipants", "On")
            showEventsWithoutLocation: root.setting("showEventsWithoutLocation", "On")
            onConfigurationChanged: function(values) { root.persistSettings(values) }
          }
        }
      }
    }
  }
}
