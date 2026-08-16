pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as QQC
import qs.Commons
import qs.Ui
import "../Model.js" as Model

Flickable {
  id: root

  property var bar: null
  property string editorMode: "create"
  property var eventData: null
  property bool editingSeries: false
  property var calendars: []
  property bool busy: false
  property string externalError: ""

  property string titleValue: ""
  property string dateValue: ""
  property string timeValue: ""
  property string durationValue: "1h"
  property bool allDay: false
  property string calendarValue: ""
  property string locationValue: ""
  property string descriptionValue: ""
  property bool submitAttempted: false

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property var validationErrors: Model.validateEventForm(values())
  readonly property bool canEditTime: editorMode !== "edit" || !eventData || String(eventData.timezone || "") === ""

  signal canceled()
  signal submitted(var values)

  function values() {
    return {
      title: titleValue,
      date: dateValue,
      time: timeValue,
      duration: durationValue,
      allDay: allDay,
      calendar: calendarValue,
      location: locationValue,
      description: descriptionValue
    }
  }

  function defaultCalendarName() {
    for (var index = 0; index < calendars.length; index += 1)
      if (calendars[index].is_default === true) return String(calendars[index].name || "")
    return calendars.length > 0 ? String(calendars[0].name || "") : ""
  }

  function initialize() {
    var initial = Model.eventEditorValues(editorMode === "edit" ? eventData : null)
    titleValue = initial.title
    dateValue = initial.date
    timeValue = initial.time
    durationValue = initial.duration
    allDay = initial.allDay
    calendarValue = initial.calendar || defaultCalendarName()
    locationValue = initial.location
    descriptionValue = initial.description
    submitAttempted = false
    Qt.callLater(function() { titleField.forceActiveFocus() })
  }

  function submit() {
    submitAttempted = true
    if (validationErrors.length === 0 && !busy) submitted(values())
  }

  onVisibleChanged: {
    if (visible) initialize()
    else datePicker.close()
  }

  Keys.priority: Keys.BeforeItem
  Keys.onPressed: function(event) {
    if (event.key === Qt.Key_Escape) {
      if (datePicker.opened) datePicker.close()
      else root.canceled()
      event.accepted = true
    } else if ((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
      datePicker.commitIfOpen()
      root.submit()
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

  Column {
    id: form
    width: root.width
    spacing: Style.space(8)

    Rectangle {
      visible: root.editorMode === "edit" && root.editingSeries
      width: parent.width
      implicitHeight: seriesWarning.implicitHeight + Style.space(20)
      radius: Style.cornerRadius
      color: Util.alpha(root.foreground, 0.06)

      Column {
        id: seriesWarning
        anchors.left: parent.left
        anchors.leftMargin: Style.space(14)
        anchors.right: parent.right
        anchors.rightMargin: Style.space(12)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(5)

        Text {
          width: parent.width
          text: "Editing entire recurring series"
          textFormat: Text.PlainText
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
        }

        Text {
          width: parent.width
          text: "Changes apply to every occurrence."
          textFormat: Text.PlainText
          color: Util.alpha(root.foreground, 0.62)
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
        }
      }
    }

    FieldLabel { text: "TITLE" }
    FormField {
      id: titleField
      width: parent.width
      text: root.titleValue
      placeholderText: "Event title"
      onTextEdited: root.titleValue = text
      onAccepted: root.submit()
    }

    FieldLabel { text: "DATE" }
    DatePicker {
      id: datePicker
      width: parent.width
      value: root.dateValue
      enabled: root.canEditTime
      foreground: root.foreground
      fontFamily: root.fontFamily
      onChanged: function(value) { root.dateValue = value }
    }

    Row {
      visible: !root.allDay
      width: parent.width
      spacing: Style.space(8)

      Column {
        width: (parent.width - Style.space(8)) * 0.5
        spacing: Style.space(4)
        FieldLabel { text: "TIME" }
        FormField {
          width: parent.width
          text: root.timeValue
          enabled: root.canEditTime
          placeholderText: "HH:MM"
          inputMethodHints: Qt.ImhTime
          onTextEdited: root.timeValue = text
        }
      }

      Column {
        width: (parent.width - Style.space(8)) * 0.5
        spacing: Style.space(4)
        FieldLabel { text: "DURATION" }
        FormField {
          width: parent.width
          text: root.durationValue
          enabled: root.canEditTime
          placeholderText: "1h"
          onTextEdited: root.durationValue = text
        }
      }
    }

    Text {
      visible: root.editorMode === "edit" && !root.canEditTime
      width: parent.width
      text: "Open Chroncal to change this event’s time in " + String(root.eventData ? root.eventData.timezone : "its timezone") + "."
      textFormat: Text.PlainText
      color: Util.alpha(root.foreground, 0.56)
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      wrapMode: Text.WordWrap
    }

    Toggle {
      width: parent.width
      label: "All-day event"
      description: root.editorMode === "edit" ? "Event type is fixed while editing" : "No start time or duration"
      checked: root.allDay
      enabled: root.editorMode !== "edit"
      foreground: root.foreground
      fontFamily: root.fontFamily
      onClicked: {
        if (root.editorMode !== "edit") root.allDay = root.allDay ? false : true
      }
    }

    FieldLabel { text: "CALENDAR" }
    FormField {
      width: parent.width
      text: root.calendarValue
      placeholderText: "Calendar name"
      onTextEdited: root.calendarValue = text
    }

    FieldLabel { text: "LOCATION" }
    FormField {
      width: parent.width
      text: root.locationValue
      placeholderText: "Optional"
      onTextEdited: root.locationValue = text
    }

    FieldLabel { text: "NOTES" }
    QQC.TextArea {
      width: parent.width
      height: Style.space(48)
      text: root.descriptionValue
      placeholderText: "Optional description"
      color: root.foreground
      placeholderTextColor: Util.alpha(root.foreground, 0.42)
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      wrapMode: QQC.TextArea.Wrap
      selectByMouse: true
      padding: Style.space(10)
      onTextChanged: root.descriptionValue = text
      background: Rectangle {
        radius: Style.cornerRadius
        color: Util.alpha(root.foreground, parent.activeFocus ? 0.10 : 0.06)
        border.width: 1
        border.color: Util.alpha(root.foreground, parent.activeFocus ? 0.28 : 0.12)
      }
    }

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
      anchors.right: parent.right
      spacing: Style.space(8)

      FormButton {
        text: "Cancel"
        onClicked: root.canceled()
      }

      FormButton {
        text: root.busy ? "Saving…" : (root.editorMode === "edit" ? (root.editingSeries ? "Save series" : "Save") : "Create")
        background: Util.alpha(root.foreground, 0.08)
        onClicked: root.submit()
      }
    }
  }
}
