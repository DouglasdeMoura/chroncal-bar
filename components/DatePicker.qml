import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui
import "../Model.js" as Model

Item {
  id: root

  property string value: ""
  property color foreground: Color.foreground
  property string fontFamily: Style.font.family
  property int weekStart: Qt.locale().firstDayOfWeek

  readonly property bool opened: popup.opened

  signal changed(string value)

  property int viewYear: new Date().getFullYear()
  property int viewMonth: new Date().getMonth()
  property string cursorKey: ""

  readonly property var weekdays: Model.weekdayOrder(weekStart)
  readonly property var weeks: Model.monthGrid(viewYear, viewMonth, weekStart, Model.formatDateInput(new Date()), value)
  readonly property string triggerLabel: {
    var date = Model.parseDateInput(value)
    return date ? Qt.formatDate(date, "ddd d MMM yyyy") : "Pick a date"
  }

  implicitHeight: trigger.height

  onVisibleChanged: if (!visible) popup.close()

  function close() {
    popup.close()
  }

  function commitIfOpen() {
    if (popup.opened) selectKey(cursorKey)
  }

  function selectKey(key) {
    if (!root.enabled || !Model.parseDateInput(key)) return
    root.changed(key)
    popup.close()
  }

  function openPicker() {
    if (!root.enabled) return
    var date = Model.parseDateInput(root.value) || new Date()
    viewYear = date.getFullYear()
    viewMonth = date.getMonth()
    cursorKey = Model.formatDateInput(date)
    popup.open()
  }

  function moveCursor(days) {
    var next = Model.shiftDateInput(cursorKey || root.value, days)
    if (next === "") return
    cursorKey = next
    var date = Model.parseDateInput(next)
    viewYear = date.getFullYear()
    viewMonth = date.getMonth()
  }

  function moveMonth(delta) {
    var next = Model.stepMonth(viewYear, viewMonth, delta)
    viewYear = next.year
    viewMonth = next.month
    var cursor = Model.parseDateInput(cursorKey || root.value)
    if (!cursor) return
    var last = new Date(next.year, next.month + 1, 0).getDate()
    cursorKey = Model.formatDateInput(new Date(next.year, next.month, Math.min(cursor.getDate(), last)))
  }

  function jumpToday() {
    var today = new Date()
    viewYear = today.getFullYear()
    viewMonth = today.getMonth()
    cursorKey = Model.formatDateInput(today)
  }

  Rectangle {
    id: trigger
    width: parent.width
    height: Style.space(34)
    radius: Style.cornerRadius
    color: Util.alpha(root.foreground, trigger.activeFocus ? 0.10 : 0.06)
    border.width: 1
    border.color: Util.alpha(root.foreground, trigger.activeFocus ? 0.28 : 0.12)
    opacity: root.enabled ? 1 : 0.55
    activeFocusOnTab: root.enabled

    Keys.onPressed: function(event) {
      if (!root.enabled) return
      if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space || event.key === Qt.Key_Down) {
        root.openPicker()
        event.accepted = true
      } else if (event.key === Qt.Key_Escape && popup.opened) {
        popup.close()
        event.accepted = true
      }
    }

    Text {
      anchors.left: parent.left
      anchors.right: chevron.left
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(8)
      text: root.triggerLabel
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
      elide: Text.ElideRight
    }

    Text {
      id: chevron
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.rightMargin: Style.space(10)
      text: "󰅀"
      color: Util.alpha(root.foreground, 0.72)
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
    }

    MouseArea {
      anchors.fill: parent
      enabled: root.enabled
      cursorShape: Qt.PointingHandCursor
      onClicked: {
        trigger.forceActiveFocus()
        popup.opened ? popup.close() : root.openPicker()
      }
    }
  }

  Popup {
    id: popup
    x: 0
    y: trigger.height + Style.space(4)
    width: root.width
    padding: Style.space(8)
    focus: true

    background: Rectangle {
      radius: Style.cornerRadius
      color: Color.popups.background
      border.width: 1
      border.color: Color.popups.border
    }

    onOpened: Qt.callLater(function() { gridFocus.forceActiveFocus() })
    onClosed: Qt.callLater(function() { trigger.forceActiveFocus() })

    contentItem: Column {
      id: calendar
      width: popup.availableWidth
      spacing: Style.space(6)

      Item {
        width: parent.width
        height: Style.space(28)

        PanelActionButton {
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          iconText: "󰅁"
          tooltipText: "Previous month"
          foreground: root.foreground
          fontFamily: root.fontFamily
          onClicked: root.moveMonth(-1)
        }

        Text {
          anchors.centerIn: parent
          width: Style.space(140)
          horizontalAlignment: Text.AlignHCenter
          text: Qt.formatDate(new Date(root.viewYear, root.viewMonth, 1), "MMMM yyyy")
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
          font.letterSpacing: 0.8
        }

        PanelActionButton {
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          iconText: "󰅂"
          tooltipText: "Next month"
          foreground: root.foreground
          fontFamily: root.fontFamily
          onClicked: root.moveMonth(1)
        }
      }

      Row {
        width: parent.width
        Repeater {
          model: root.weekdays
          Text {
            required property var modelData
            width: calendar.width / 7
            horizontalAlignment: Text.AlignHCenter
            text: Qt.locale().dayName(modelData, Locale.ShortFormat)
            color: Util.alpha(root.foreground, 0.54)
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
          }
        }
      }

      Item {
        id: gridFocus
        width: parent.width
        height: gridColumn.height
        activeFocusOnTab: true

        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) {
          var text = event.text
          if (event.key === Qt.Key_Escape) {
            popup.close()
            event.accepted = true
          } else if (event.key === Qt.Key_Left || text === "h" || text === "H") {
            root.moveCursor(-1)
            event.accepted = true
          } else if (event.key === Qt.Key_Right || text === "l" || text === "L") {
            root.moveCursor(1)
            event.accepted = true
          } else if (event.key === Qt.Key_Up || text === "k" || text === "K") {
            root.moveCursor(-7)
            event.accepted = true
          } else if (event.key === Qt.Key_Down || text === "j" || text === "J") {
            root.moveCursor(7)
            event.accepted = true
          } else if (event.key === Qt.Key_PageUp) {
            root.moveMonth(-1)
            event.accepted = true
          } else if (event.key === Qt.Key_PageDown) {
            root.moveMonth(1)
            event.accepted = true
          } else if (text === "t" || text === "T") {
            root.jumpToday()
            event.accepted = true
          } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.selectKey(root.cursorKey)
            event.accepted = true
          }
        }

        Column {
          id: gridColumn
          width: parent.width
          spacing: Style.space(2)

          Repeater {
            model: root.weeks

            Row {
              required property var modelData
              width: gridColumn.width
              Repeater {
                model: parent.modelData

                Rectangle {
                  required property var modelData
                  width: gridColumn.width / 7
                  height: Style.space(28)
                  radius: Style.cornerRadius
                  color: modelData.key === root.cursorKey || modelData.selected
                    ? Util.alpha(root.foreground, 0.10)
                    : "transparent"
                  border.width: modelData.today ? 1 : 0
                  border.color: Util.alpha(root.foreground, 0.45)

                  Text {
                    anchors.centerIn: parent
                    text: modelData.day
                    color: modelData.inMonth ? root.foreground : Util.alpha(root.foreground, 0.38)
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                    font.bold: modelData.selected || modelData.today
                  }

                  MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.cursorKey = parent.modelData.key
                    onClicked: root.selectKey(parent.modelData.key)
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
