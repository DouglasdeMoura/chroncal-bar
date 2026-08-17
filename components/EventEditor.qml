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
  property string repeatPreset: "none"
  property int repeatInterval: 1
  property string repeatFreq: "WEEKLY"
  property var repeatWeekDays: [false, false, false, false, false, false, false]
  property string repeatMonthlyMode: "date"
  property string repeatEnds: "never"
  property int repeatCount: 1
  property string repeatUntil: ""
  property bool submitAttempted: false

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property var validationErrors: Model.validateEventForm(values())
  readonly property bool canEditTime: editorMode !== "edit" || !eventData || String(eventData.timezone || "") === ""
  readonly property bool canEditRecurrence: editorMode !== "edit" || !eventData || String(eventData.recurrence_id || "") === ""
  readonly property bool showingRepeatEnds: repeatPreset !== "none"
  readonly property bool showingCustomRepeat: repeatPreset === "custom"

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
      description: descriptionValue,
      recurrence: {
        preset: repeatPreset,
        interval: repeatInterval,
        freq: repeatFreq,
        weekDays: repeatWeekDays,
        monthlyMode: repeatMonthlyMode,
        ends: repeatEnds,
        count: repeatCount,
        until: repeatUntil
      }
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
    var rec = initial.recurrence || Model.defaultRecurrenceForm(initial.date)
    repeatPreset = rec.preset
    repeatInterval = rec.interval
    repeatFreq = rec.freq
    repeatWeekDays = rec.weekDays.slice()
    repeatMonthlyMode = rec.monthlyMode
    repeatEnds = rec.ends
    repeatCount = rec.count
    repeatUntil = rec.until
    submitAttempted = false
    Qt.callLater(function() { titleField.forceActiveFocus() })
  }

  function recurrenceForm() { return values().recurrence }

  function applyRepeatPreset(value) {
    var next = Model.applyRepeatPreset(recurrenceForm(), value, root.dateValue)
    repeatPreset = next.preset
    repeatInterval = next.interval
    repeatFreq = next.freq
    repeatWeekDays = next.weekDays.slice()
    repeatMonthlyMode = next.monthlyMode
    repeatEnds = next.ends
    repeatCount = next.count
    repeatUntil = next.until
  }

  function closePickers() {
    datePicker.close()
    endsDatePicker.close()
    repeatDropdown.close()
    endsDropdown.close()
    freqDropdown.close()
    monthlyDropdown.close()
  }

  function submit() {
    submitAttempted = true
    if (validationErrors.length === 0 && !busy) submitted(values())
  }

  onVisibleChanged: {
    if (visible) initialize()
    else closePickers()
  }

  Keys.priority: Keys.BeforeItem
  Keys.onPressed: function(event) {
    if (event.key === Qt.Key_Escape) {
      if (datePicker.opened) datePicker.close()
      else if (endsDatePicker.opened) endsDatePicker.close()
      else if (repeatDropdown.popupOpen) repeatDropdown.close()
      else if (endsDropdown.popupOpen) endsDropdown.close()
      else if (freqDropdown.popupOpen) freqDropdown.close()
      else if (monthlyDropdown.popupOpen) monthlyDropdown.close()
      else root.canceled()
      event.accepted = true
    } else if ((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
      datePicker.commitIfOpen()
      endsDatePicker.commitIfOpen()
      root.submit()
      event.accepted = true
    } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_S) {
      datePicker.commitIfOpen()
      endsDatePicker.commitIfOpen()
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

    FieldLabel { text: "REPEAT" }
    Dropdown {
      id: repeatDropdown
      width: parent.width
      showLabel: false
      options: Model.repeatPresetOptions()
      enabled: !root.busy && root.canEditRecurrence
      foreground: root.foreground
      fontFamily: root.fontFamily
      onChanged: function(value) { root.applyRepeatPreset(value) }
    }

    Binding {
      target: repeatDropdown
      property: "value"
      value: root.repeatPreset
    }

    Text {
      visible: !root.canEditRecurrence
      width: parent.width
      text: "Open the series editor to change Repeat. This override keeps the series rule."
      textFormat: Text.PlainText
      color: Util.alpha(root.foreground, 0.56)
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      wrapMode: Text.WordWrap
    }

    Column {
      visible: root.showingCustomRepeat
      width: parent.width
      spacing: Style.space(4)

      FieldLabel { text: "REPEAT EVERY" }
      Row {
        width: parent.width
        spacing: Style.space(8)

        NumberField {
          id: intervalField
          width: (parent.width - Style.space(8)) * 0.4
          fieldWidth: width
          value: root.repeatInterval
          from: 1
          to: 99
          stepSize: 1
          enabled: !root.busy && root.canEditRecurrence
          foreground: root.foreground
          fontFamily: root.fontFamily
          onModified: function(value) { root.repeatInterval = value }
        }

        Dropdown {
          id: freqDropdown
          width: (parent.width - Style.space(8)) * 0.6
          showLabel: false
          options: Model.frequencyOptions()
          enabled: !root.busy && root.canEditRecurrence
          foreground: root.foreground
          fontFamily: root.fontFamily
          onChanged: function(value) { root.repeatFreq = value }
        }
      }

      Binding {
        target: freqDropdown
        property: "value"
        value: root.repeatFreq
      }
      Binding {
        target: intervalField.field
        property: "value"
        value: root.repeatInterval
      }

      Column {
        visible: root.repeatFreq === "WEEKLY"
        width: parent.width
        spacing: Style.space(4)

        FieldLabel { text: "ON" }
        Row {
          id: weekDaysRow
          width: parent.width
          spacing: Style.space(4)

          Repeater {
            model: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]

            FormButton {
              required property int index
              required property string modelData

              width: (weekDaysRow.width - weekDaysRow.spacing * 6) / 7
              text: modelData
              fontSize: Style.font.caption
              horizontalPadding: Style.space(2)
              selected: root.repeatWeekDays[index] === true
              enabled: !root.busy && root.canEditRecurrence
              onClicked: {
                var next = root.repeatWeekDays.slice()
                if (next[index] === true) {
                  var remaining = 0
                  for (var i = 0; i < next.length; i++) if (next[i]) remaining += 1
                  if (remaining <= 1) return
                }
                next[index] = !next[index]
                root.repeatWeekDays = next
              }
            }
          }
        }
      }

      Column {
        visible: root.repeatFreq === "MONTHLY"
        width: parent.width
        spacing: Style.space(4)

        FieldLabel { text: "ON" }
        Dropdown {
          id: monthlyDropdown
          width: parent.width
          showLabel: false
          options: Model.monthlyOnOptions(root.dateValue)
          enabled: !root.busy && root.canEditRecurrence
          foreground: root.foreground
          fontFamily: root.fontFamily
          onChanged: function(value) { root.repeatMonthlyMode = value }
        }

        Binding {
          target: monthlyDropdown
          property: "value"
          value: root.repeatMonthlyMode
        }
      }
    }

    Column {
      visible: root.showingRepeatEnds
      width: parent.width
      spacing: Style.space(4)
      FieldLabel { text: "ENDS" }
      Dropdown {
        id: endsDropdown
        width: parent.width
        showLabel: false
        options: Model.endsOptions()
        enabled: !root.busy && root.canEditRecurrence
        foreground: root.foreground
        fontFamily: root.fontFamily
        onChanged: function(value) { root.repeatEnds = value }
      }

      Binding {
        target: endsDropdown
        property: "value"
        value: root.repeatEnds
      }
      NumberField {
        visible: root.repeatEnds === "after"
        width: parent.width
        label: "Times"
        value: root.repeatCount
        from: 1
        to: 999
        stepSize: 1
        enabled: !root.busy && root.canEditRecurrence
        foreground: root.foreground
        fontFamily: root.fontFamily
        onModified: function(value) { root.repeatCount = value }
      }
      DatePicker {
        id: endsDatePicker
        visible: root.repeatEnds === "ondate"
        width: parent.width
        value: root.repeatUntil
        enabled: !root.busy && root.canEditRecurrence
        foreground: root.foreground
        fontFamily: root.fontFamily
        onChanged: function(value) { root.repeatUntil = value }
      }
    }

    Text {
      visible: root.showingCustomRepeat
      width: parent.width
      text: Model.recurrenceRuleSummary(root.recurrenceForm(), root.dateValue)
      textFormat: Text.PlainText
      color: Util.alpha(root.foreground, 0.62)
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      wrapMode: Text.WordWrap
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
