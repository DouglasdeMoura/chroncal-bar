pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import qs.Commons

Flickable {
  id: root

  property color foreground: Color.foreground
  property string fontFamily: Style.font.family

  signal closeRequested()

  contentWidth: width
  contentHeight: shortcuts.implicitHeight
  clip: true
  boundsBehavior: Flickable.StopAtBounds
  flickableDirection: Flickable.VerticalFlick
  ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

  readonly property var entries: [
    { keys: "↑ / ↓   j / k", action: "Move selection" },
    { keys: "← / →   h / l", action: "Previous or next day" },
    { keys: "t", action: "Jump to today" },
    { keys: "Enter / Space", action: "Open selected event" },
    { keys: "/", action: "Open search" },
    { keys: "c", action: "Create event" },
    { keys: "e", action: "Edit event or recurring series" },
    { keys: "x / Delete", action: "Delete this event, this and following, or all events" },
    { keys: "v", action: "Join or open event link" },
    { keys: "p", action: "Copy event details" },
    { keys: "g", action: "Open Chroncal" },
    { keys: "s", action: "Refresh agenda" },
    { keys: "C / ,", action: "Calendar settings" },
    { keys: "?", action: "Open shortcut help" },
    { keys: "Ctrl+S", action: "Save event or series" },
    { keys: "Esc / q", action: "Back or close" }
  ]

  Column {
    id: shortcuts
    width: root.width
    spacing: Style.space(4)

    Text {
      width: parent.width
      bottomPadding: Style.space(8)
      text: "Keyboard-first controls work anywhere in the agenda unless a text field is active."
      color: Util.alpha(root.foreground, 0.62)
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      wrapMode: Text.WordWrap
    }

    Repeater {
      model: root.entries

      Rectangle {
        required property var modelData
        width: shortcuts.width
        height: Style.space(34)
        radius: Style.cornerRadius
        color: Util.alpha(root.foreground, 0.04)

        Text {
          anchors.left: parent.left
          anchors.leftMargin: Style.space(10)
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width * 0.38
          text: parent.modelData.keys
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
        }

        Text {
          anchors.left: parent.left
          anchors.leftMargin: parent.width * 0.4
          anchors.right: parent.right
          anchors.rightMargin: Style.space(10)
          anchors.verticalCenter: parent.verticalCenter
          text: parent.modelData.action
          color: Util.alpha(root.foreground, 0.72)
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }
    }
  }
}
