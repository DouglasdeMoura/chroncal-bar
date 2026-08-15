import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui
import "../Model.js" as Model

Flickable {
  id: root

  property var bar: null
  property var calendars: []
  property var includedCalendarIds: []
  property string showTime: "On"
  property string showTitle: "On"
  property int relativeLeadMinutes: 10
  property string showAllDay: "On"
  property string showEventsWithoutParticipants: "On"
  property string showEventsWithoutLocation: "On"

  signal configurationChanged(var values)

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  contentWidth: width
  contentHeight: settingsColumn.implicitHeight
  clip: true
  boundsBehavior: Flickable.StopAtBounds
  flickableDirection: Flickable.VerticalFlick
  interactive: contentHeight > height
  ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

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

    MultiSelect {
      width: parent.width
      label: "Included calendars"
      values: root.includedCalendarIds || []
      options: Model.calendarOptions(root.calendars)
      noSelectionText: "All calendars"
      placeholderText: "Filter calendars..."
      foreground: root.foreground
      fontFamily: root.fontFamily
      onChanged: function(values) { root.configurationChanged({ includedCalendarIds: values }) }
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
  }
}
