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
  property bool busy: false

  signal activated(var eventData)
  signal joinRequested(var eventData)

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property real progress: Model.eventProgress(eventData, nowIso)
  readonly property bool declined: Model.isDeclined(eventData)
  readonly property bool invited: Model.awaitingResponse(eventData)
  readonly property string status: Model.eventRowStatus(eventData, nowIso)
  readonly property string conferenceUrl: Model.eventConferenceUrl(eventData)
  readonly property bool ongoing: root.progress > 0
  // Join shows for video meetings that are on, or start within the hour.
  readonly property bool showJoin: conferenceUrl !== "" && !declined && status !== ""
  readonly property color calendarColor: eventData.calendar_color || "#888888"

  implicitHeight: Style.space(54)
  opacity: declined ? 0.5 : 1

  Rectangle {
    anchors.fill: parent
    radius: Style.cornerRadius
    color: root.selected
      ? Util.alpha(root.foreground, 0.10)
      : (rowMouse.containsMouse ? Util.alpha(root.foreground, 0.05) : "transparent")
  }

  // Unanswered invitations get a hollow stripe, like Notion's hatched block.
  Rectangle {
    width: Style.space(3)
    anchors.left: parent.left
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    radius: width / 2
    color: root.invited ? "transparent" : root.calendarColor
    border.width: root.invited ? 1 : 0
    border.color: root.calendarColor
  }

  MouseArea {
    id: rowMouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.activated(root.eventData)
  }

  Column {
    anchors.left: parent.left
    anchors.leftMargin: Style.space(12)
    anchors.right: trailing.left
    anchors.rightMargin: Style.space(8)
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.space(2)

    Text {
      width: parent.width
      text: root.eventData.title || "Untitled"
      textFormat: Text.PlainText
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
      font.bold: root.ongoing
      font.strikeout: root.declined
      elide: Text.ElideRight
    }

    Text {
      width: parent.width
      text: Model.eventRowSubtitle(root.eventData)
      textFormat: Text.PlainText
      color: Util.alpha(root.foreground, 0.62)
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      elide: Text.ElideRight
    }
  }

  Row {
    id: trailing
    anchors.right: parent.right
    anchors.rightMargin: Style.space(8)
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.space(8)

    Text {
      visible: root.status !== "" && !root.showJoin
      anchors.verticalCenter: parent.verticalCenter
      text: root.status
      color: root.ongoing ? root.foreground : Util.alpha(root.foreground, 0.62)
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }

    JoinButton {
      visible: root.showJoin
      anchors.verticalCenter: parent.verticalCenter
      text: root.ongoing ? "Join" : root.status
      tooltipText: Model.eventJoinLabel(root.eventData)
      tint: root.calendarColor
      filled: root.ongoing
      enabled: !root.busy
      opacity: enabled ? 1 : 0.55
      foreground: root.foreground
      fontFamily: root.fontFamily
      fontSize: Style.font.caption
      horizontalPadding: Style.space(8)
      verticalPadding: Style.space(3)
      onClicked: root.joinRequested(root.eventData)
    }
  }

  Rectangle {
    visible: root.progress > 0
    height: Style.space(2)
    width: Math.max(0, parent.width * root.progress)
    anchors.left: parent.left
    anchors.bottom: parent.bottom
    color: root.calendarColor
  }
}
