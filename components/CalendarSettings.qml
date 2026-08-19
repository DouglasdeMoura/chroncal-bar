import QtQuick
import QtQuick.Controls as QQC
import qs.Commons
import qs.Ui
import "../Model.js" as Model

Flickable {
  id: root

  property var bar: null
  property var calendars: []
  property var accounts: []
  property var includedCalendarIds: []
  property bool calendarSelectionCustomized: false
  property bool busy: false
  property var syncStatus: []
  property var syncIssues: []
  property bool syncStateBusy: false
  property string statusText: ""
  property string errorText: ""
  property string showTime: "On"
  property string showTitle: "On"
  property int relativeLeadMinutes: 10
  property int lookaheadDays: 7
  property string showAllDay: "On"
  property string showEventsWithoutParticipants: "On"
  property string showEventsWithoutLocation: "On"
  property string showOpenInChroncal: "Off"

  signal configurationChanged(var values)
  signal newCalendarRequested()
  signal editCalendarRequested(var calendar)
  signal addAccountRequested()
  signal openAccountRequested(var account)
  signal importIcalRequested()
  signal syncRequested(var account)
  signal resolveRequested(var issue, string pick)
  signal resetRequested(var calendarRow)

  // Mirrors Model.groupCalendars' local test: 0/"0"/""/null/undefined are local.
  readonly property bool hasConnectedCalendar: {
    var list = root.calendars || []
    for (var i = 0; i < list.length; i += 1) {
      var rawId = (list[i] || {}).account_id
      if (!(rawId === undefined || rawId === null || rawId === 0 || rawId === "0" || String(rawId) === ""))
        return true
    }
    return false
  }

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  contentWidth: width
  contentHeight: settingsColumn.implicitHeight
  clip: true
  boundsBehavior: Flickable.StopAtBounds
  flickableDirection: Flickable.VerticalFlick
  interactive: contentHeight > height
  QQC.ScrollBar.vertical: QQC.ScrollBar { policy: QQC.ScrollBar.AsNeeded }

  Column {
    id: settingsColumn
    width: root.width
    spacing: Style.space(10)

    Text {
      text: "CALENDARS"
      color: Util.alpha(root.foreground, 0.52)
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
      font.letterSpacing: 1
    }

    Repeater {
      model: Model.groupCalendars(root.calendars, root.accounts)

      Column {
        id: accountSection
        required property var modelData
        width: parent.width
        spacing: Style.space(4)

        Item {
          width: parent.width
          height: Math.max(sectionLabel.implicitHeight, sectionActions.implicitHeight)

          Text {
            id: sectionLabel
            anchors.left: parent.left
            anchors.right: accountSection.modelData.account !== null ? sectionActions.left : parent.right
            anchors.rightMargin: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            text: accountSection.modelData.account !== null
              ? String(accountSection.modelData.account.display_name || accountSection.modelData.account.name || "Account")
              : "On this computer"
            color: Util.alpha(root.foreground, 0.52)
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
            font.letterSpacing: 1
            elide: Text.ElideRight
          }

          Row {
            id: sectionActions
            visible: accountSection.modelData.account !== null
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(4)

            Button {
              text: "Sync"
              bordered: true
              focusable: true
              foreground: root.foreground
              fontFamily: root.fontFamily
              enabled: !root.busy && !root.syncStateBusy
              opacity: enabled ? 1 : 0.55
              onClicked: root.syncRequested(accountSection.modelData.account)
            }

            Button {
              text: "Open"
              bordered: true
              focusable: true
              foreground: root.foreground
              fontFamily: root.fontFamily
              enabled: !root.busy
              opacity: enabled ? 1 : 0.55
              onClicked: root.openAccountRequested(accountSection.modelData.account)
            }
          }
        }

        Text {
          visible: accountSection.modelData.account !== null
            && (String(accountSection.modelData.account.username || "") !== ""
              || String(accountSection.modelData.account.auth_type || "") !== "")
          width: parent.width
          text: [String(accountSection.modelData.account.username || ""), String(accountSection.modelData.account.auth_type || "")]
            .filter(function(part) { return part !== "" }).join(" · ")
          color: Util.alpha(root.foreground, 0.52)
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }

        Repeater {
          model: accountSection.modelData.calendars

          Column {
            id: calendarRow
            required property var modelData
            width: parent.width
            spacing: Style.space(2)

            Item {
              width: parent.width
              height: editButton.implicitHeight

              Rectangle {
                id: colorDot
                width: Style.space(10)
                height: Style.space(10)
                radius: width / 2
                anchors.left: parent.left
                anchors.leftMargin: Style.space(8)
                anchors.verticalCenter: parent.verticalCenter
                color: String(calendarRow.modelData.color || "#888888")
              }

              Button {
                id: editButton
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "Edit"
                bordered: true
                focusable: true
                foreground: root.foreground
                fontFamily: root.fontFamily
                enabled: !root.busy
                opacity: enabled ? 1 : 0.55
                onClicked: root.editCalendarRequested(calendarRow.modelData)
              }

              Text {
                id: stateLabel
                visible: stateText !== ""
                readonly property string stateText: [calendarRow.modelData.is_default === true ? "default" : "",
                  calendarRow.modelData.hidden === true ? "hidden" : "",
                  String(calendarRow.modelData.remote_access || "") === "read" ? "read-only" : ""]
                  .filter(function(part) { return part !== "" }).join(" · ")
                anchors.right: editButton.left
                anchors.rightMargin: Style.space(8)
                anchors.verticalCenter: parent.verticalCenter
                text: stateText
                color: Util.alpha(root.foreground, 0.52)
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }

              Text {
                anchors.left: colorDot.right
                anchors.leftMargin: Style.space(8)
                anchors.right: stateLabel.visible ? stateLabel.left : editButton.left
                anchors.rightMargin: Style.space(8)
                anchors.verticalCenter: parent.verticalCenter
                text: String(calendarRow.modelData.name || "")
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                elide: Text.ElideRight
              }
            }

            Text {
              visible: String(calendarRow.modelData.last_sync_error || "") !== ""
              width: parent.width
              text: String(calendarRow.modelData.last_sync_error || "")
              textFormat: Text.PlainText
              color: Color.urgent
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }
          }
        }
      }
    }

    Button {
      width: parent.width
      text: "Add account"
      bordered: true
      focusable: true
      leftAlign: true
      foreground: root.foreground
      fontFamily: root.fontFamily
      enabled: !root.busy
      opacity: enabled ? 1 : 0.55
      onClicked: root.addAccountRequested()
    }

    Button {
      width: parent.width
      text: "New calendar"
      bordered: true
      focusable: true
      leftAlign: true
      foreground: root.foreground
      fontFamily: root.fontFamily
      enabled: !root.busy
      opacity: enabled ? 1 : 0.55
      onClicked: root.newCalendarRequested()
    }

    Button {
      width: parent.width
      text: "Import iCal"
      bordered: true
      focusable: true
      leftAlign: true
      foreground: root.foreground
      fontFamily: root.fontFamily
      enabled: !root.busy
      opacity: enabled ? 1 : 0.55
      onClicked: root.importIcalRequested()
    }

    Column {
      visible: root.hasConnectedCalendar || root.syncStateBusy
      width: parent.width
      spacing: Style.space(6)

      Text {
        width: parent.width
        text: "SYNC"
        color: Util.alpha(root.foreground, 0.52)
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
        font.letterSpacing: 1
      }

      Text {
        visible: root.syncStateBusy && root.syncStatus.length === 0
        width: parent.width
        text: "Loading sync status…"
        color: Util.alpha(root.foreground, 0.56)
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }

      Text {
        visible: root.statusText !== ""
        width: parent.width
        text: root.statusText
        textFormat: Text.PlainText
        color: Util.alpha(root.foreground, 0.56)
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        wrapMode: Text.WordWrap
      }

      Text {
        visible: root.errorText !== ""
        width: parent.width
        text: root.errorText
        textFormat: Text.PlainText
        color: Color.urgent
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        wrapMode: Text.WordWrap
      }

      Repeater {
        model: root.syncStatus

        Column {
          id: syncStatusRow
          required property var modelData
          width: parent.width
          spacing: Style.space(4)

          Item {
            width: parent.width
            height: Math.max(syncStatusText.implicitHeight, syncResetButton.implicitHeight)

            Text {
              id: syncStatusText
              anchors.left: parent.left
              anchors.right: syncResetButton.left
              anchors.rightMargin: Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
              text: [String(syncStatusRow.modelData.calendar_name || ""),
                "Last sync " + (String(syncStatusRow.modelData.last_sync_at || "") !== "" ? String(syncStatusRow.modelData.last_sync_at) : "Never")]
                .concat(syncStatusRow.modelData.pending_push === true ? ["pending push"] : [])
                .join(" · ")
              textFormat: Text.PlainText
              color: Util.alpha(root.foreground, 0.56)
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
            }

            Button {
              id: syncResetButton
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              text: "Reset…"
              bordered: true
              focusable: true
              foreground: root.foreground
              fontFamily: root.fontFamily
              enabled: !root.busy && !root.syncStateBusy
              opacity: enabled ? 1 : 0.55
              onClicked: root.resetRequested(syncStatusRow.modelData)
            }
          }

          Text {
            visible: Number(syncStatusRow.modelData.conflicts || 0) > 0
            width: parent.width
            text: Number(syncStatusRow.modelData.conflicts || 0) === 1
              ? "1 conflict"
              : Number(syncStatusRow.modelData.conflicts || 0) + " conflicts"
            textFormat: Text.PlainText
            color: Color.urgent
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
        }
      }

      Column {
        visible: root.syncIssues.length > 0
        width: parent.width
        spacing: Style.space(6)

        Text {
          width: parent.width
          text: "Unresolved conflicts"
          color: Color.urgent
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
          font.letterSpacing: 1
        }

        Repeater {
          model: root.syncIssues

          Item {
            id: conflictRow
            required property var modelData
            width: parent.width
            height: Math.max(conflictText.implicitHeight, conflictButtons.implicitHeight)

            readonly property string calendarLabel: {
              var target = String(conflictRow.modelData.calendar_id)
              var list = root.calendars || []
              for (var i = 0; i < list.length; i += 1) {
                if (String((list[i] || {}).id) === target)
                  return String(list[i].name || target)
              }
              return "Calendar " + target
            }

            Text {
              id: conflictText
              anchors.left: parent.left
              anchors.right: conflictButtons.left
              anchors.rightMargin: Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
              text: [conflictRow.calendarLabel,
                String(conflictRow.modelData.uid || ""),
                String(conflictRow.modelData.detected_at || "")]
                .filter(function(part) { return part !== "" }).join(" · ")
              textFormat: Text.PlainText
              color: Util.alpha(root.foreground, 0.56)
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
            }

            Row {
              id: conflictButtons
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(4)

              Button {
                text: "Keep local"
                bordered: true
                focusable: true
                foreground: root.foreground
                fontFamily: root.fontFamily
                enabled: !root.busy
                opacity: enabled ? 1 : 0.55
                onClicked: root.resolveRequested(conflictRow.modelData, "local")
              }

              Button {
                text: "Keep server"
                bordered: true
                focusable: true
                foreground: root.foreground
                fontFamily: root.fontFamily
                enabled: !root.busy
                opacity: enabled ? 1 : 0.55
                onClicked: root.resolveRequested(conflictRow.modelData, "server")
              }
            }
          }
        }
      }
    }

    MultiSelect {
      id: calendarSelect
      width: parent.width
      label: "Included calendars"
      options: Model.calendarOptions(root.calendars)
      noSelectionText: "No calendars"
      placeholderText: "Filter calendars..."
      foreground: root.foreground
      fontFamily: root.fontFamily
      onChanged: function(values) {
        root.configurationChanged({
          includedCalendarIds: values,
          calendarSelectionCustomized: true
        })
      }
    }

    Binding {
      target: calendarSelect
      property: "values"
      value: root.includedCalendarIds || []
    }

    Text {
      width: parent.width
      text: "Included calendars only filter this bar. Hidden calendars are removed from Chroncal and the agenda entirely."
      textFormat: Text.PlainText
      color: Util.alpha(root.foreground, 0.56)
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      wrapMode: Text.WordWrap
    }

    Button {
      visible: root.calendarSelectionCustomized
      text: "Use default (all calendars)"
      bordered: true
      focusable: true
      foreground: root.foreground
      fontFamily: root.fontFamily
      onClicked: root.configurationChanged({
        includedCalendarIds: [],
        calendarSelectionCustomized: false
      })
    }

    Text {
      topPadding: Style.space(6)
      text: "BAR PREVIEW"
      color: Util.alpha(root.foreground, 0.52)
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
      font.letterSpacing: 1
    }

    Toggle {
      width: parent.width
      label: "Show event time"
      checked: root.showTime !== "Off"
      foreground: root.foreground
      fontFamily: root.fontFamily
      onClicked: root.configurationChanged({ showTime: root.showTime === "Off" ? "On" : "Off" })
    }

    Toggle {
      width: parent.width
      label: "Show event title"
      checked: root.showTitle !== "Off"
      foreground: root.foreground
      fontFamily: root.fontFamily
      onClicked: root.configurationChanged({ showTitle: root.showTitle === "Off" ? "On" : "Off" })
    }

    NumberField {
      width: parent.width
      label: "Relative countdown window (minutes)"
      value: root.relativeLeadMinutes
      from: 0
      to: 120
      stepSize: 5
      foreground: root.foreground
      fontFamily: root.fontFamily
      onModified: function(value) { root.configurationChanged({ relativeLeadMinutes: value }) }
    }

    Text {
      topPadding: Style.space(6)
      text: "AGENDA FILTERS"
      color: Util.alpha(root.foreground, 0.52)
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
      font.letterSpacing: 1
    }

    NumberField {
      width: parent.width
      label: "Days ahead"
      value: root.lookaheadDays
      from: 1
      to: 30
      stepSize: 1
      foreground: root.foreground
      fontFamily: root.fontFamily
      onModified: function(value) { root.configurationChanged({ lookaheadDays: value }) }
    }

    Toggle {
      width: parent.width
      label: "All-day events"
      checked: root.showAllDay !== "Off"
      foreground: root.foreground
      fontFamily: root.fontFamily
      onClicked: root.configurationChanged({ showAllDay: root.showAllDay === "Off" ? "On" : "Off" })
    }

    Toggle {
      width: parent.width
      label: "Events without participants"
      checked: root.showEventsWithoutParticipants !== "Off"
      foreground: root.foreground
      fontFamily: root.fontFamily
      onClicked: root.configurationChanged({ showEventsWithoutParticipants: root.showEventsWithoutParticipants === "Off" ? "On" : "Off" })
    }

    Toggle {
      width: parent.width
      label: "Events without location"
      description: "Includes physical locations and meeting links"
      checked: root.showEventsWithoutLocation !== "Off"
      foreground: root.foreground
      fontFamily: root.fontFamily
      onClicked: root.configurationChanged({ showEventsWithoutLocation: root.showEventsWithoutLocation === "Off" ? "On" : "Off" })
    }

    Text {
      topPadding: Style.space(6)
      text: "EVENT DETAILS"
      color: Util.alpha(root.foreground, 0.52)
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
      font.letterSpacing: 1
    }

    Toggle {
      width: parent.width
      label: "Open in Chroncal"
      description: "Shows a button that launches Chroncal on this event"
      checked: root.showOpenInChroncal !== "Off"
      foreground: root.foreground
      fontFamily: root.fontFamily
      onClicked: root.configurationChanged({ showOpenInChroncal: root.showOpenInChroncal === "Off" ? "On" : "Off" })
    }
  }
}
