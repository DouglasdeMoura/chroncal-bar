import QtQuick
import qs.Commons
import qs.Ui
import "../Model.js" as Model

// Join pill tinted with the meeting's calendar color.
//
// The stock Button swaps its fill for a faint theme wash on hover. On a
// filled, colored pill that drops the color and leaves dark ink on a dark
// panel, so the label vanishes. This one keeps the color in every state and
// moves the fill *away* from the ink on hover and press, so contrast only
// ever goes up.
//
//   filled  (meeting is on)    calendar-color fill, ink picked for contrast
//   outline (starting soon)    calendar-color border, wash of it on hover
Item {
  id: root

  property string text: "Join"
  property string iconText: "󰕧"
  property string tooltipText: ""
  property color tint: "#888888"
  property bool filled: true
  property bool focusable: false
  property color foreground: Color.foreground
  property string fontFamily: Style.font.family
  property real fontSize: Style.font.caption
  property real horizontalPadding: Style.space(10)
  property real verticalPadding: Style.space(3)

  signal clicked()

  readonly property bool hot: mouseArea.containsMouse || (focusable && activeFocus)
  readonly property bool down: mouseArea.pressed
  // Ink for the filled pill: the theme color that reads best on the tint,
  // or black/white when neither clears 4.5:1.
  readonly property color ink: Model.readableTextColor(tint, [Color.background, root.foreground])
  readonly property bool lightInk: Model.relativeLuminance(ink) > 0.5
  // Shade toward the opposite of the ink, so hover and press add contrast.
  readonly property color shade: lightInk ? "#000000" : "#ffffff"

  readonly property color fillColor: filled
    ? Qt.tint(tint, Util.alpha(shade, down ? 0.26 : (hot ? 0.16 : 0)))
    : Util.alpha(tint, down ? 0.36 : (hot ? 0.24 : 0))
  readonly property color labelColor: filled ? ink : root.foreground

  implicitWidth: row.implicitWidth + horizontalPadding * 2
  implicitHeight: row.implicitHeight + verticalPadding * 2

  activeFocusOnTab: focusable
  Keys.onReturnPressed: if (enabled) root.clicked()
  Keys.onEnterPressed: if (enabled) root.clicked()
  Keys.onSpacePressed: if (enabled) root.clicked()

  scale: down ? 0.97 : 1
  Behavior on scale {
    NumberAnimation { duration: Style.duration(160); easing.type: Easing.Bezier; easing.bezierCurve: Style.easeOut }
  }

  Rectangle {
    anchors.fill: parent
    radius: Style.cornerRadius
    color: root.fillColor
    border.width: root.filled ? (root.hot ? 1 : 0) : 1
    // Filled: a hairline of the ink frames the pill on hover, so it reads
    // as raised even when the calendar color sits close to the panel's.
    border.color: root.filled ? Util.alpha(root.ink, 0.35) : root.tint
    Behavior on color { ColorAnimation { duration: Style.duration(120) } }
  }

  Row {
    id: row
    anchors.centerIn: parent
    spacing: Style.space(5)

    Text {
      visible: root.iconText !== ""
      anchors.verticalCenter: parent.verticalCenter
      text: root.iconText
      textFormat: Text.PlainText
      color: root.labelColor
      font.family: root.fontFamily
      font.pixelSize: root.fontSize + 1
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: root.text
      textFormat: Text.PlainText
      color: root.labelColor
      font.family: root.fontFamily
      font.pixelSize: root.fontSize
      font.bold: true
    }
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    // Undo the press scale so a press near the edge still lands.
    scale: 1 / root.scale
    hoverEnabled: true
    cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    onClicked: {
      if (root.focusable) root.forceActiveFocus()
      root.clicked()
    }
  }

  PanelToolTip {
    visible: root.tooltipText !== "" && mouseArea.containsMouse
    text: root.tooltipText
    fontFamily: root.fontFamily
  }
}
