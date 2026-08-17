pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui
import "../Model.js" as Model

Item {
  id: root

  property var bar: null
  property var eventData: ({})
  property string nowIso: ""
  property string actionStatus: ""
  property bool busy: false
  property bool showOpenInChroncal: false

  signal joinRequested()
  signal mapRequested()
  signal chroncalRequested()
  signal editRequested()
  signal deleteRequested()
  signal rsvpRequested(string status)
  signal linkRequested(string url)

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property bool canEdit: Model.canEditEvent(eventData)
  readonly property bool generatedRecurring: Model.isGeneratedRecurringEvent(eventData)
  readonly property bool canMutate: Model.canMutateEvent(eventData)
  readonly property bool canDelete: Model.canDeleteEvent(eventData)
  readonly property bool recurring: Model.isRecurringEvent(eventData)
  readonly property bool canRsvp: Model.canRsvp(eventData)
  readonly property var rsvpChoices: Model.rsvpChoices()
  readonly property string eventDateLabel: Model.formatEventDate(eventData, nowIso)
  readonly property color notesLinkColor: Color.accent

  onEventDataChanged: detailsFlick.contentY = 0

  Flickable {
    id: detailsFlick
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: actionsFooter.top
    anchors.bottomMargin: Style.space(12)
    contentWidth: width
    contentHeight: detailsColumn.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick
    interactive: contentHeight > height
    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

    Column {
      id: detailsColumn
      width: detailsFlick.width
      spacing: Style.space(12)

      Text {
        width: parent.width
        text: root.eventData.title || "Untitled"
        textFormat: Text.PlainText
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.title
        font.bold: true
        wrapMode: Text.Wrap
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
            visible: root.eventDateLabel !== ""
            width: parent.width
            text: root.eventDateLabel
            textFormat: Text.PlainText
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            font.bold: true
            wrapMode: Text.Wrap
          }

          Text {
            width: parent.width
            text: Model.formatEventRange(root.eventData)
            textFormat: Text.PlainText
            color: Util.alpha(root.foreground, 0.82)
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            wrapMode: Text.Wrap
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
        visible: root.canRsvp
        width: parent.width
        spacing: Style.space(6)

        Text {
          text: "GOING"
          color: Util.alpha(root.foreground, 0.52)
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
          font.letterSpacing: 1
        }

        Row {
          id: rsvpRow
          spacing: Style.space(4)

          Repeater {
            model: root.rsvpChoices

            Button {
              required property var modelData
              text: modelData.label
              bordered: true
              focusable: true
              selected: Model.userRsvpStatus(root.eventData) === modelData.value
              enabled: !root.busy
              opacity: enabled ? 1 : 0.55
              foreground: root.foreground
              fontFamily: root.fontFamily
              fontSize: Style.font.bodySmall
              horizontalPadding: Style.space(8)
              verticalPadding: Style.space(3)
              onClicked: root.rsvpRequested(modelData.value)
            }
          }
        }
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

        Item {
          id: locationLine
          width: parent.width
          height: locationText.height

          Item {
            id: locationCluster
            width: locationText.width + (locationOpenIcon.visible ? Style.space(4) + locationOpenIcon.width : 0)
            height: locationText.height

            Text {
              id: locationText
              width: Math.min(implicitWidth, locationLine.width - (locationOpenIcon.visible ? Style.space(4) + locationOpenIcon.width : 0))
              text: root.eventData.location || ""
              textFormat: Text.PlainText
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              wrapMode: Text.Wrap
            }

            Text {
              id: locationOpenIcon
              anchors.left: locationText.right
              anchors.leftMargin: Style.space(4)
              anchors.bottom: locationText.bottom
              text: "󰏌"
              color: locationMouse.containsMouse
                ? Qt.lighter(root.notesLinkColor, 1.18)
                : root.notesLinkColor
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              visible: Model.eventMapUrl(root.eventData) !== ""
              opacity: root.busy ? 0.55 : 1
            }

            MouseArea {
              id: locationMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
              enabled: Model.eventMapUrl(root.eventData) !== "" && !root.busy
              onClicked: root.mapRequested()
            }

            PanelToolTip {
              visible: locationMouse.containsMouse
              text: "Open location in maps"
              fontFamily: root.fontFamily
            }
          }
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
          id: notesText
          width: parent.width
          text: Model.eventNotesHtml(root.eventData, notesText.hoveredLink !== "" ? Qt.lighter(root.notesLinkColor, 1.18) : root.notesLinkColor)
          textFormat: Text.RichText
          color: Util.alpha(root.foreground, 0.82)
          linkColor: root.notesLinkColor
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          wrapMode: Text.Wrap
          onLinkActivated: function(link) { root.linkRequested(link) }

          HoverHandler {
            enabled: parent.hoveredLink !== ""
            cursorShape: Qt.PointingHandCursor
          }
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

      Button {
        visible: root.showOpenInChroncal
        text: "Open in Chroncal"
        tooltipText: "Open this event in Chroncal"
        bordered: true
        focusable: true
        enabled: visible && !root.busy
        opacity: enabled ? 1 : 0.55
        foreground: root.foreground
        fontFamily: root.fontFamily
        fontSize: Style.font.bodySmall
        horizontalPadding: Style.space(8)
        verticalPadding: Style.space(3)
        onClicked: root.chroncalRequested()
      }

    }
  }

  Column {
    id: actionsFooter
    z: 1
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    spacing: Style.space(12)

    Rectangle {
      width: parent.width
      height: 1
      color: Util.alpha(root.foreground, 0.12)
    }

    Item {
      width: parent.width
      height: Math.max(joinButton.height, actionIcons.height)

      Button {
        id: joinButton
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        visible: Model.eventOpenUrl(root.eventData) !== ""
        text: "Join"
        tooltipText: "Join or open event link"
        bordered: true
        focusable: true
        enabled: visible && !root.busy
        opacity: enabled ? 1 : 0.55
        foreground: root.foreground
        fontFamily: root.fontFamily
        fontSize: Style.font.bodySmall
        horizontalPadding: Style.space(8)
        verticalPadding: Style.space(3)
        onClicked: root.joinRequested()
      }

      Row {
        id: actionIcons
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(18)

        PanelActionButton {
          iconText: "󰏫"
          tooltipText: root.generatedRecurring ? "Edit recurring series" : "Edit event"
          foreground: root.foreground
          fontFamily: root.fontFamily
          focusable: true
          enabled: !root.busy && root.canEdit
          onClicked: root.editRequested()
        }

        PanelActionButton {
          iconText: "󰆴"
          tooltipText: root.recurring ? "Delete this event, this and following, or all events" : "Delete event"
          foreground: root.foreground
          fontFamily: root.fontFamily
          focusable: true
          enabled: root.canDelete && !root.busy
          onClicked: root.deleteRequested()
        }
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
