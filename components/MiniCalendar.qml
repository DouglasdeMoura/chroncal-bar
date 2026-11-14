pragma ComponentBehavior: Bound
import QtQuick
import qs.Commons
import qs.Ui
import "../Model.js" as Model

// Compact month grid above the agenda, like Notion Calendar's mini month:
// dots mark days with events, the selected event's day is highlighted, and
// clicking a day jumps the agenda there.
Column {
  id: root

  property color foreground: Color.foreground
  property string fontFamily: Style.font.family
  property int weekStart: Qt.locale().firstDayOfWeek
  property var events: []
  property string todayKey: ""
  property string selectedKey: ""
  property string rangeFrom: ""
  property string rangeTo: ""

  property int viewYear: new Date().getFullYear()
  property int viewMonth: new Date().getMonth()

  signal daySelected(string key)

  readonly property var markers: Model.eventDayMarkers(events)
  readonly property var weekdays: Model.weekdayOrder(weekStart)
  readonly property var weeks: Model.miniCalendarWeeks(viewYear, viewMonth, weekStart, todayKey, selectedKey, markers, rangeFrom, rangeTo)
  readonly property real cellHeight: Style.space(24)

  spacing: Style.space(2)

  function showMonthOf(key) {
    var date = Model.parseDateInput(key)
    if (!date) return
    viewYear = date.getFullYear()
    viewMonth = date.getMonth()
  }

  function moveMonth(delta) {
    var next = Model.stepMonth(viewYear, viewMonth, delta)
    viewYear = next.year
    viewMonth = next.month
  }

  // Follow the selection across months as the agenda is navigated.
  onSelectedKeyChanged: if (selectedKey !== "") showMonthOf(selectedKey)
  onTodayKeyChanged: if (selectedKey === "") showMonthOf(todayKey)

  Item {
    width: parent.width
    height: Style.space(24)

    Text {
      anchors.left: parent.left
      anchors.leftMargin: Style.space(4)
      anchors.verticalCenter: parent.verticalCenter
      text: Qt.formatDate(new Date(root.viewYear, root.viewMonth, 1), "MMMM yyyy")
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
      font.letterSpacing: 0.6
    }

    Row {
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(2)

      PanelActionButton {
        iconText: "󰅁"
        tooltipText: "Previous month"
        foreground: root.foreground
        fontFamily: root.fontFamily
        onClicked: root.moveMonth(-1)
      }

      PanelActionButton {
        iconText: "•"
        tooltipText: "This month"
        foreground: root.foreground
        fontFamily: root.fontFamily
        onClicked: root.showMonthOf(root.todayKey)
      }

      PanelActionButton {
        iconText: "󰅂"
        tooltipText: "Next month"
        foreground: root.foreground
        fontFamily: root.fontFamily
        onClicked: root.moveMonth(1)
      }
    }
  }

  Row {
    width: parent.width
    Repeater {
      model: root.weekdays
      Text {
        required property var modelData
        width: root.width / 7
        horizontalAlignment: Text.AlignHCenter
        text: Qt.locale().dayName(modelData, Locale.NarrowFormat)
        color: Util.alpha(root.foreground, 0.46)
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }
    }
  }

  Repeater {
    model: root.weeks

    Row {
      id: weekRow
      required property var modelData
      width: root.width

      Repeater {
        model: weekRow.modelData

        Item {
          id: cell
          required property var modelData
          readonly property bool selectable: modelData.loaded && !modelData.past
          width: root.width / 7
          height: root.cellHeight

          Rectangle {
            anchors.centerIn: parent
            width: Math.min(parent.width - Style.space(2), root.cellHeight)
            height: root.cellHeight
            radius: height / 2
            color: cell.modelData.today
              ? root.foreground
              : (cell.modelData.selected
                ? Util.alpha(root.foreground, 0.16)
                : (cellMouse.containsMouse && cell.selectable ? Util.alpha(root.foreground, 0.08) : "transparent"))
          }

          Text {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: cell.modelData.colors.length > 0 ? -Style.space(2) : 0
            text: cell.modelData.day
            color: cell.modelData.today
              ? (Color.background)
              : Util.alpha(root.foreground, !cell.modelData.inMonth ? 0.28 : (cell.modelData.past ? 0.42 : (cell.modelData.loaded ? 0.92 : 0.58)))
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: cell.modelData.today || cell.modelData.selected
          }

          Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Style.space(3)
            spacing: Style.space(2)
            visible: cell.modelData.inMonth || cell.modelData.loaded

            Repeater {
              model: cell.modelData.colors
              Rectangle {
                required property var modelData
                width: Style.space(3)
                height: width
                radius: width / 2
                color: cell.modelData.today ? Color.background : modelData
                opacity: cell.modelData.past ? 0.5 : 1
              }
            }
          }

          MouseArea {
            id: cellMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: cell.selectable
            cursorShape: Qt.PointingHandCursor
            onClicked: root.daySelected(cell.modelData.key)
          }
        }
      }
    }
  }
}
