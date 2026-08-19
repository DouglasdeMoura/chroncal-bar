import QtQuick
import qs.Commons
import qs.Ui

Item {
  id: root

  property bool opened: false
  property bool recurring: false
  property string actionLabel: ""
  property string title: "this event"
  property int selectedIndex: 0
  property color background: Color.background
  property color foreground: Color.foreground
  property string fontFamily: Style.font.family

  readonly property var actions: root.recurring
    ? [
        { key: "this", label: "This event", destructive: false },
        { key: "following", label: "This and following", destructive: false },
        { key: "series", label: "All events", destructive: true },
        { key: "cancel", label: "Cancel", destructive: false }
      ]
    : [
        { key: "event", label: root.actionLabel !== "" ? root.actionLabel : "Delete", destructive: true },
        { key: "cancel", label: "Cancel", destructive: false }
      ]

  signal canceled()
  signal chosen(string scope)

  function cycle(delta) {
    var count = actions.length
    if (count === 0 || delta === 0) return
    selectedIndex = (selectedIndex + delta % count + count) % count
  }

  function activate() {
    var action = actions[Math.max(0, Math.min(selectedIndex, actions.length - 1))]
    if (!action || action.key === "cancel") root.canceled()
    else root.chosen(action.key)
  }

  visible: opened
  onOpenedChanged: if (opened) selectedIndex = 0
  onRecurringChanged: if (opened) selectedIndex = 0

  Rectangle {
    anchors.fill: parent
    color: Util.alpha(Color.background, 0.7)

    MouseArea { anchors.fill: parent; onClicked: root.canceled() }

    BorderSurface {
      id: card
      width: Math.min(parent.width - Style.space(32), Style.space(370))
      height: card.contentTopInset + card.contentBottomInset + body.implicitHeight
      anchors.centerIn: parent
      color: root.background
      borderSpec: Border.flat(Color.accent, Style.normalBorderWidth)
      padding: Style.space(18)
      radius: Style.cornerRadius

      MouseArea { anchors.fill: parent; onClicked: {} }

      Column {
        id: body
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: card.contentTopInset
        anchors.leftMargin: card.contentLeftInset
        anchors.rightMargin: card.contentRightInset
        spacing: Style.space(12)

        Text {
          width: parent.width
          text: "Delete “" + String(root.title || "this event") + "”?"
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.title
          wrapMode: Text.WordWrap
        }

        Text {
          visible: root.recurring
          width: parent.width
          text: "This event leaves the rest of the series. This and following ends the series here. All events removes every date."
          color: Util.alpha(root.foreground, 0.62)
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
        }

        Column {
          width: parent.width
          spacing: Style.space(8)

          Repeater {
            model: root.actions.length

            Button {
              required property int index
              readonly property var action: root.actions[index]

              width: body.width
              text: action.label
              bordered: true
              foreground: action.destructive ? Color.urgent : root.foreground
              fontFamily: root.fontFamily
              hasCursor: root.selectedIndex === index
              background: root.selectedIndex === index
                ? (action.destructive ? Util.alpha(Color.urgent, 0.16) : Util.alpha(root.foreground, 0.08))
                : (index === 0 && !action.destructive ? Util.alpha(root.foreground, 0.08) : "transparent")
              onHovered: function(isHovered) { if (isHovered) root.selectedIndex = index }
              onClicked: {
                root.selectedIndex = index
                if (action.key === "cancel") root.canceled()
                else root.chosen(action.key)
              }
            }
          }
        }
      }
    }
  }
}
