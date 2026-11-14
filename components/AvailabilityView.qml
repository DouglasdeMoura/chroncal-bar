pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as QQC
import qs.Commons
import qs.Ui
import "../Model.js" as Model

// Share availability: free time inside working hours across the next few
// working days, copied as plain text to paste into a chat or email.
Flickable {
  id: root

  property var bar: null
  property var days: []
  property string timezone: ""
  property string nowIso: ""
  property int availabilityDays: 3
  property int startHour: 9
  property int endHour: 18
  property int minMinutes: 30
  property string weekends: "Off"
  property string actionStatus: ""

  signal copyRequested()
  signal slotRequested(var day, var slot)
  signal configurationChanged(var values)

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property string summary: Model.availabilityText(days, timezone, nowIso)

  contentWidth: width
  contentHeight: content.implicitHeight
  clip: true
  boundsBehavior: Flickable.StopAtBounds
  flickableDirection: Flickable.VerticalFlick
  interactive: contentHeight > height
  QQC.ScrollBar.vertical: QQC.ScrollBar { policy: QQC.ScrollBar.AsNeeded }

  component Caption: Text {
    color: Util.alpha(root.foreground, 0.52)
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    font.bold: true
    font.letterSpacing: 1
  }

  Column {
    id: content
    width: root.width
    spacing: Style.space(10)

    Text {
      width: parent.width
      text: "Free time between " + Model.pad2(root.startHour) + ":00 and " + Model.pad2(root.endHour % 24) + ":00"
        + (root.timezone !== "" ? " · " + root.timezone.replace(/_/g, " ") : "")
        + ". Click a slot to book it."
      textFormat: Text.PlainText
      color: Util.alpha(root.foreground, 0.62)
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      wrapMode: Text.WordWrap
    }

    Repeater {
      model: root.days

      Column {
        id: dayColumn
        required property var modelData
        width: content.width
        spacing: Style.space(4)

        Item {
          width: parent.width
          height: dayLabel.implicitHeight

          Text {
            id: dayLabel
            text: dayColumn.modelData.label.toUpperCase()
            color: Util.alpha(root.foreground, 0.52)
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
            font.letterSpacing: 1
          }

          Text {
            anchors.right: parent.right
            anchors.baseline: dayLabel.baseline
            visible: dayColumn.modelData.label.indexOf(",") === -1
            text: dayColumn.modelData.detail
            color: Util.alpha(root.foreground, 0.42)
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
        }

        Text {
          visible: dayColumn.modelData.slots.length === 0
          leftPadding: Style.space(4)
          text: "Fully booked"
          color: Util.alpha(root.foreground, 0.46)
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
        }

        Flow {
          width: parent.width
          spacing: Style.space(6)

          Repeater {
            model: dayColumn.modelData.slots

            Button {
              required property var modelData
              text: Model.slotLabel(modelData)
              tooltipText: "Create an event at " + Model.formatTime(modelData.start)
              bordered: true
              foreground: root.foreground
              fontFamily: root.fontFamily
              fontSize: Style.font.caption
              horizontalPadding: Style.space(10)
              verticalPadding: Style.space(4)
              onClicked: root.slotRequested(dayColumn.modelData, modelData)
            }
          }
        }
      }
    }

    Text {
      visible: root.days.length === 0
      width: parent.width
      text: "No working days left in the loaded agenda. Raise Days ahead in settings."
      textFormat: Text.PlainText
      color: Util.alpha(root.foreground, 0.62)
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
      wrapMode: Text.WordWrap
    }

    Row {
      spacing: Style.space(8)

      Button {
        text: "Copy availability"
        bordered: true
        enabled: root.summary !== ""
        opacity: enabled ? 1 : 0.55
        background: Util.alpha(root.foreground, 0.08)
        foreground: root.foreground
        fontFamily: root.fontFamily
        onClicked: root.copyRequested()
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: root.actionStatus
        textFormat: Text.PlainText
        color: Util.alpha(root.foreground, 0.72)
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }
    }

    Caption { topPadding: Style.space(6); text: "WORKING HOURS" }

    Row {
      width: parent.width
      spacing: Style.space(8)

      NumberField {
        width: (parent.width - Style.space(8)) / 2
        fieldWidth: width
        label: "From (hour)"
        value: root.startHour
        from: 0
        to: 23
        stepSize: 1
        foreground: root.foreground
        fontFamily: root.fontFamily
        onModified: function(value) { root.configurationChanged({ availabilityStartHour: value }) }
      }

      NumberField {
        width: (parent.width - Style.space(8)) / 2
        fieldWidth: width
        label: "Until (hour)"
        value: root.endHour
        from: 1
        to: 24
        stepSize: 1
        foreground: root.foreground
        fontFamily: root.fontFamily
        onModified: function(value) { root.configurationChanged({ availabilityEndHour: value }) }
      }
    }

    Row {
      width: parent.width
      spacing: Style.space(8)

      NumberField {
        width: (parent.width - Style.space(8)) / 2
        fieldWidth: width
        label: "Days to share"
        value: root.availabilityDays
        from: 1
        to: 14
        stepSize: 1
        foreground: root.foreground
        fontFamily: root.fontFamily
        onModified: function(value) { root.configurationChanged({ availabilityDays: value }) }
      }

      NumberField {
        width: (parent.width - Style.space(8)) / 2
        fieldWidth: width
        label: "Shortest slot (minutes)"
        value: root.minMinutes
        from: 15
        to: 240
        stepSize: 15
        foreground: root.foreground
        fontFamily: root.fontFamily
        onModified: function(value) { root.configurationChanged({ availabilityMinMinutes: value }) }
      }
    }

    Toggle {
      width: parent.width
      label: "Include weekends"
      checked: root.weekends === "On"
      foreground: root.foreground
      fontFamily: root.fontFamily
      onClicked: root.configurationChanged({ availabilityWeekends: root.weekends === "On" ? "Off" : "On" })
    }
  }
}
