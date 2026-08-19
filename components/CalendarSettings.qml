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
          height: Math.max(sectionLabel.implicitHeight, sectionOpenButton.implicitHeight)

          Text {
            id: sectionLabel
            anchors.left: parent.left
            anchors.right: accountSection.modelData.account !== null ? sectionOpenButton.left : parent.right
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

          Button {
            id: sectionOpenButton
            visible: accountSection.modelData.account !== null
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
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
