import QtQuick
import qs.Commons
import qs.Ui
import "../Model.js" as Model

Item {
  id: root

  property var bar: null
  property var eventData: ({})
  property string nowIso: ""
  property bool selected: false

  signal activated(var eventData)

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property real progress: Model.eventProgress(eventData, nowIso)

  implicitHeight: Style.space(54)

  Rectangle {
    anchors.fill: parent
    radius: Style.cornerRadius
    color: root.selected ? Util.alpha(root.foreground, 0.10) : "transparent"
  }

  Rectangle {
    width: Style.space(3)
    anchors.left: parent.left
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    radius: width / 2
    color: root.eventData.calendar_color || "#888888"
  }

  Column {
    anchors.left: parent.left
    anchors.leftMargin: Style.space(12)
    anchors.right: parent.right
    anchors.rightMargin: Style.space(8)
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.space(2)

    Text {
      width: parent.width
      text: root.eventData.title || "Untitled"
      color: root.foreground
      font.family: root.bar ? root.bar.fontFamily : Style.font.family
      font.pixelSize: Style.font.body
      font.bold: root.progress > 0
      elide: Text.ElideRight
    }

    Text {
      width: parent.width
      text: Model.formatEventRange(root.eventData) + "  ·  " + (root.eventData.calendar_name || "Calendar")
      color: Util.alpha(root.foreground, 0.62)
      font.family: root.bar ? root.bar.fontFamily : Style.font.family
      font.pixelSize: Style.font.caption
      elide: Text.ElideRight
    }
  }

  Rectangle {
    visible: root.progress > 0
    height: Style.space(2)
    width: Math.max(0, parent.width * root.progress)
    anchors.left: parent.left
    anchors.bottom: parent.bottom
    color: root.eventData.calendar_color || Color.accent
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.activated(root.eventData)
  }
}
