import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui
import "../Model.js" as Model

Flickable {
  id: root

  property var bar: null
  property var eventData: ({})
  property string actionStatus: ""
  property bool busy: false

  signal backRequested()
  signal joinRequested()
  signal mapRequested()
  signal emailRequested()
  signal copyRequested()
  signal chroncalRequested()
  signal editRequested()
  signal deleteRequested()

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property bool canMutate: Model.canMutateEvent(eventData)

  contentWidth: width
  contentHeight: detailsColumn.implicitHeight
  clip: true
  boundsBehavior: Flickable.StopAtBounds
  flickableDirection: Flickable.VerticalFlick
  interactive: contentHeight > height
  ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

  Column {
    id: detailsColumn
    width: root.width
    spacing: Style.space(12)

    Row {
      width: parent.width
      spacing: Style.space(8)

      PanelActionButton {
        iconText: "←"
        tooltipText: "Back to agenda"
        foreground: root.foreground
        fontFamily: root.fontFamily
        focusable: true
        onClicked: root.backRequested()
      }

      Text {
        width: parent.width - Style.space(38)
        anchors.verticalCenter: parent.verticalCenter
        text: root.eventData.title || "Untitled"
        textFormat: Text.PlainText
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.title
        font.bold: true
        elide: Text.ElideRight
      }
    }

    Rectangle {
      width: parent.width
      implicitHeight: eventSummary.implicitHeight + Style.space(20)
      radius: Style.cornerRadius
      color: Util.alpha(root.foreground, 0.06)

      Rectangle {
        width: Style.space(3)
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        radius: width / 2
        color: root.eventData.calendar_color || "#888888"
      }

      Column {
        id: eventSummary
        anchors.left: parent.left
        anchors.leftMargin: Style.space(14)
        anchors.right: parent.right
        anchors.rightMargin: Style.space(12)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(5)

        Text {
          width: parent.width
          text: Model.formatEventRange(root.eventData)
          textFormat: Text.PlainText
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          font.bold: true
        }

        Text {
          width: parent.width
          text: root.eventData.calendar_name || "Calendar"
          textFormat: Text.PlainText
          color: Util.alpha(root.foreground, 0.62)
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }
    }

    Text {
      visible: Model.eventAttributes(root.eventData) !== ""
      width: parent.width
      text: Model.eventAttributes(root.eventData)
      textFormat: Text.PlainText
      color: Util.alpha(root.foreground, 0.54)
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      elide: Text.ElideRight
    }

    Column {
      visible: String(root.eventData.location || "") !== ""
      width: parent.width
      spacing: Style.space(3)

      Text {
        text: "LOCATION"
        color: Util.alpha(root.foreground, 0.52)
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
        font.letterSpacing: 1
      }

      Text {
        width: parent.width
        text: root.eventData.location || ""
        textFormat: Text.PlainText
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        wrapMode: Text.Wrap
      }
    }

    Column {
      visible: String(root.eventData.description || "") !== ""
      width: parent.width
      spacing: Style.space(3)

      Text {
        text: "NOTES"
        color: Util.alpha(root.foreground, 0.52)
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
        font.letterSpacing: 1
      }

      Text {
        width: parent.width
        text: root.eventData.description || ""
        textFormat: Text.PlainText
        color: Util.alpha(root.foreground, 0.82)
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        wrapMode: Text.Wrap
      }
    }

    Column {
      visible: (root.eventData.attendees || []).length > 0
      width: parent.width
      spacing: Style.space(3)

      Text {
        text: "PARTICIPANTS"
        color: Util.alpha(root.foreground, 0.52)
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
        font.letterSpacing: 1
      }

      Text {
        width: parent.width
        text: Model.attendeeSummary(root.eventData)
        textFormat: Text.PlainText
        color: Util.alpha(root.foreground, 0.82)
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        wrapMode: Text.Wrap
      }
    }

    Rectangle {
      width: parent.width
      height: 1
      color: Util.alpha(root.foreground, 0.12)
    }

    Text {
      visible: !root.canMutate
      width: parent.width
      text: "Edit this recurring series in Chroncal. This generated occurrence has no separate identity."
      textFormat: Text.PlainText
      color: Util.alpha(root.foreground, 0.62)
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      wrapMode: Text.WordWrap
    }

    Text {
      text: "QUICK ACTIONS"
      color: Util.alpha(root.foreground, 0.52)
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
      font.letterSpacing: 1
    }

    Row {
      width: parent.width
      spacing: Style.space(18)

      PanelActionButton {
        iconText: "󰒃"
        tooltipText: "Join or open event link"
        foreground: root.foreground
        fontFamily: root.fontFamily
        focusable: true
        enabled: Model.eventOpenUrl(root.eventData) !== ""
        onClicked: root.joinRequested()
      }

      PanelActionButton {
        iconText: "󰍎"
        tooltipText: "Open location in maps"
        foreground: root.foreground
        fontFamily: root.fontFamily
        focusable: true
        enabled: Model.eventMapUrl(root.eventData) !== ""
        onClicked: root.mapRequested()
      }

      PanelActionButton {
        iconText: "󰇮"
        tooltipText: "Email participants"
        foreground: root.foreground
        fontFamily: root.fontFamily
        focusable: true
        enabled: Model.eventMailUrl(root.eventData) !== ""
        onClicked: root.emailRequested()
      }

      PanelActionButton {
        iconText: "󰆏"
        tooltipText: "Copy event details"
        foreground: root.foreground
        fontFamily: root.fontFamily
        focusable: true
        onClicked: root.copyRequested()
      }

      PanelActionButton {
        iconText: "󰃭"
        tooltipText: "Open Chroncal"
        foreground: root.foreground
        fontFamily: root.fontFamily
        focusable: true
        onClicked: root.chroncalRequested()
      }

      PanelActionButton {
        iconText: "󰏫"
        tooltipText: root.canMutate ? "Edit event" : "Edit the recurring series in Chroncal"
        foreground: root.foreground
        fontFamily: root.fontFamily
        focusable: true
        enabled: !root.busy && root.canMutate
        onClicked: root.editRequested()
      }

      PanelActionButton {
        iconText: "󰆴"
        tooltipText: root.canMutate ? "Delete event" : "Delete the recurring series in Chroncal"
        foreground: Color.urgent
        fontFamily: root.fontFamily
        focusable: true
        enabled: !root.busy && root.canMutate
        onClicked: root.deleteRequested()
      }
    }

    Text {
      visible: root.actionStatus !== ""
      text: root.actionStatus
      textFormat: Text.PlainText
      color: Util.alpha(root.foreground, 0.62)
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }
  }
}
