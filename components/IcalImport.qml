pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as QQC
import qs.Commons
import qs.Ui

Flickable {
  id: root

  property var bar: null
  property var calendars: []
  property bool busy: false
  property string externalError: ""

  property string pathValue: ""
  property string calendarValue: ""
  property bool submitAttempted: false

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property var calendarOptions: {
    var options = [{ value: "", label: "First available calendar" }]
    var list = calendars || []
    for (var i = 0; i < list.length; i += 1)
      options.push({ value: String(list[i].name || ""), label: String(list[i].name || "Calendar") })
    return options
  }
  readonly property var validationErrors: {
    var errors = []
    if (String(pathValue || "").trim() === "") errors.push("Path is required")
    return errors
  }
  readonly property bool canSubmit: !busy && validationErrors.length === 0

  signal canceled()
  signal submitted(var values)

  function values() {
    return {
      path: String(pathValue || "").trim(),
      calendar: String(calendarValue || "")
    }
  }

  function initialize() {
    pathValue = ""
    pathField.text = ""
    calendarValue = ""
    submitAttempted = false
    Qt.callLater(function() { pathField.forceActiveFocus() })
  }

  function closePickers() {
    calendarDropdown.close()
  }

  function submit() {
    submitAttempted = true
    if (!canSubmit) return
    submitted(values())
  }

  onVisibleChanged: {
    if (visible) initialize()
    else closePickers()
  }

  Keys.priority: Keys.BeforeItem
  Keys.onPressed: function(event) {
    if (event.key === Qt.Key_Escape) {
      if (calendarDropdown.popupOpen) calendarDropdown.close()
      else canceled()
      event.accepted = true
    } else if ((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
      submit()
      event.accepted = true
    } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_S) {
      submit()
      event.accepted = true
    }
  }

  contentWidth: width
  contentHeight: form.implicitHeight
  clip: true
  boundsBehavior: Flickable.StopAtBounds
  flickableDirection: Flickable.VerticalFlick
  QQC.ScrollBar.vertical: QQC.ScrollBar { policy: QQC.ScrollBar.AsNeeded }

  component FieldLabel: Text {
    color: Util.alpha(root.foreground, 0.56)
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    font.bold: true
    font.letterSpacing: 0.8
  }

  component FormField: QQC.TextField {
    color: root.foreground
    placeholderTextColor: Util.alpha(root.foreground, 0.42)
    font.family: root.fontFamily
    font.pixelSize: Style.font.body
    leftPadding: Style.space(10)
    rightPadding: Style.space(10)
    selectByMouse: true
    background: Rectangle {
      radius: Style.cornerRadius
      color: Util.alpha(root.foreground, parent.activeFocus ? 0.10 : 0.06)
      border.width: 1
      border.color: Util.alpha(root.foreground, parent.activeFocus ? 0.28 : 0.12)
    }
  }

  component FormButton: Button {
    foreground: root.foreground
    fontFamily: root.fontFamily
    bordered: true
    focusable: true
    enabled: !root.busy
    opacity: enabled ? 1 : 0.55
  }

  component Caption: Text {
    width: parent.width
    textFormat: Text.PlainText
    color: Util.alpha(root.foreground, 0.56)
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    wrapMode: Text.WordWrap
  }

  Column {
    id: form
    width: root.width
    spacing: Style.space(8)

    FieldLabel { text: "FILE PATH" }
    FormField {
      id: pathField
      width: parent.width
      text: root.pathValue
      placeholderText: "~/Downloads/calendar.ics"
      onTextEdited: root.pathValue = text
      onAccepted: root.submit()
    }

    FieldLabel { text: "CALENDAR" }
    Dropdown {
      id: calendarDropdown
      width: parent.width
      showLabel: false
      options: root.calendarOptions
      enabled: !root.busy
      foreground: root.foreground
      fontFamily: root.fontFamily
      onChanged: function(value) { root.calendarValue = value }
    }

    Binding {
      target: calendarDropdown
      property: "value"
      value: root.calendarValue
    }

    Caption { text: "Events are imported into the chosen calendar. Large files stay limited by Chroncal (8 MiB)." }

    Text {
      visible: (root.submitAttempted && root.validationErrors.length > 0) || root.externalError !== ""
      width: parent.width
      text: root.externalError !== "" ? root.externalError : root.validationErrors.join("\n")
      textFormat: Text.PlainText
      color: Color.urgent
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      wrapMode: Text.WordWrap
    }

    Row {
      width: parent.width
      spacing: Style.space(8)

      FormButton {
        width: (parent.width - parent.spacing) / 2
        text: "Cancel"
        onClicked: root.canceled()
      }

      FormButton {
        width: (parent.width - parent.spacing) / 2
        enabled: !root.busy && root.canSubmit
        opacity: enabled ? 1 : 0.55
        text: root.busy ? "Importing…" : "Import"
        onClicked: root.submit()
      }
    }
  }
}
