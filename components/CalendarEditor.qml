pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as QQC
import qs.Commons
import qs.Ui

Flickable {
  id: root

  property var bar: null
  property string mode: "create"
  property var calendar: null
  property var calendars: []
  property bool busy: false
  property string externalError: ""

  property string nameValue: ""
  property string colorValue: ""
  property string descriptionValue: ""
  property string emailValue: ""
  property bool setDefaultChecked: false
  property bool hiddenChecked: false
  property string promoteValue: ""
  property bool submitAttempted: false

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property bool editing: mode === "edit"
  readonly property bool editingDefault: editing && calendar && calendar.is_default === true
  readonly property bool editingRemote: editing && calendar && calendar.account_id ? true : false
  readonly property string normalizedColor: {
    var value = String(colorValue || "").trim()
    if (value === "") return ""
    if (/^#?[0-9A-Fa-f]{6}$/.test(value)) return value.charAt(0) === "#" ? value : "#" + value
    return ""
  }
  readonly property var validationErrors: validate()
  readonly property var promoteOptions: {
    var options = []
    var currentId = calendar ? String(calendar.id) : ""
    for (var index = 0; index < calendars.length; index += 1) {
      var entry = calendars[index]
      var id = String(entry.id)
      if (id === currentId) continue
      options.push({ value: id, label: String(entry.name || "Calendar") })
    }
    return options
  }

  signal canceled()
  signal submitted(var values)

  function validate() {
    var errors = []
    if (String(nameValue || "").trim() === "") errors.push("Name is required")
    var color = String(colorValue || "").trim()
    if (color !== "" && !/^#?[0-9A-Fa-f]{6}$/.test(color)) errors.push("Color must be 6 hex digits, like #3B82F6")
    return errors
  }

  function values() {
    return {
      action: editing ? "update" : "create",
      id: editing && calendar ? String(calendar.id) : "",
      name: String(nameValue || "").trim(),
      color: normalizedColor,
      description: String(descriptionValue || "").trim(),
      email: String(emailValue || "").trim(),
      setDefault: !editing && setDefaultChecked,
      hidden: hiddenChecked,
      promote: promoteValue
    }
  }

  function initialize() {
    var source = editing ? (calendar || {}) : {}
    nameValue = String(source.name || "")
    colorValue = String(source.color || "")
    descriptionValue = String(source.description || "")
    emailValue = String(source.owner_email || "")
    setDefaultChecked = false
    hiddenChecked = source.hidden === true
    promoteValue = ""
    submitAttempted = false
    Qt.callLater(function() { nameField.forceActiveFocus() })
  }

  function closePickers() {
    promoteDropdown.close()
  }

  function submit() {
    submitAttempted = true
    if (validationErrors.length === 0 && !busy) submitted(values())
  }

  function submitAction(action) {
    if (busy) return
    var form = values()
    form.action = action
    submitted(form)
  }

  onVisibleChanged: {
    if (visible) initialize()
    else closePickers()
  }

  // A failed mutation leaves the editor open; undo optimistic toggle flips
  // so the switch matches Chroncal again.
  onExternalErrorChanged: {
    if (externalError !== "" && editing && calendar) hiddenChecked = calendar.hidden === true
  }

  Keys.priority: Keys.BeforeItem
  Keys.onPressed: function(event) {
    if (event.key === Qt.Key_Escape) {
      if (promoteDropdown.popupOpen) promoteDropdown.close()
      else root.canceled()
      event.accepted = true
    } else if ((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
      root.submit()
      event.accepted = true
    } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_S) {
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

    FieldLabel { text: "NAME" }
    FormField {
      id: nameField
      width: parent.width
      text: root.nameValue
      placeholderText: "Calendar name"
      onTextEdited: root.nameValue = text
      onAccepted: root.submit()
    }

    FieldLabel { text: "COLOR" }
    Row {
      width: parent.width
      spacing: Style.space(8)

      FormField {
        width: parent.width - Style.space(36)
        text: root.colorValue
        placeholderText: "#3B82F6"
        onTextEdited: root.colorValue = text
      }

      Rectangle {
        width: Style.space(28)
        height: Style.space(28)
        radius: Style.cornerRadius
        anchors.verticalCenter: parent.verticalCenter
        color: root.normalizedColor !== "" ? root.normalizedColor : "transparent"
        border.width: 1
        border.color: Util.alpha(root.foreground, 0.28)
      }
    }

    FieldLabel { text: "DESCRIPTION" }
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

    FieldLabel { text: "OWNER EMAIL" }
    FormField {
      width: parent.width
      text: root.emailValue
      placeholderText: "Optional"
      onTextEdited: root.emailValue = text
      onAccepted: root.submit()
    }

    Toggle {
      visible: !root.editing && root.calendars.length > 0
      width: parent.width
      label: "Set as default"
      description: "New events land on the default calendar"
      checked: root.setDefaultChecked
      enabled: !root.busy
      foreground: root.foreground
      fontFamily: root.fontFamily
      onClicked: root.setDefaultChecked = !root.setDefaultChecked
    }

    Text {
      visible: !root.editing && root.calendars.length === 0
      width: parent.width
      text: "The first calendar becomes the default automatically."
      textFormat: Text.PlainText
      color: Util.alpha(root.foreground, 0.56)
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      wrapMode: Text.WordWrap
    }

    Toggle {
      visible: root.editing
      width: parent.width
      label: "Hidden"
      description: "Hidden calendars keep their events but leave the agenda"
      checked: root.hiddenChecked
      enabled: !root.busy
      foreground: root.foreground
      fontFamily: root.fontFamily
      onClicked: {
        root.hiddenChecked = !root.hiddenChecked
        root.submitAction(root.hiddenChecked ? "hide" : "show")
      }
    }

    FormButton {
      visible: root.editing && !root.editingDefault
      width: parent.width
      text: "Set as default"
      onClicked: root.submitAction("default")
    }

    FormButton {
      visible: root.editingRemote
      width: parent.width
      text: "Keep local"
      onClicked: root.submitAction("disconnect")
    }

    Text {
      visible: root.editingRemote
      width: parent.width
      text: "Unlinks this calendar from " + String((root.calendar || {}).account_name || "its account") + " and keeps the events on this computer."
      textFormat: Text.PlainText
      color: Util.alpha(root.foreground, 0.56)
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      wrapMode: Text.WordWrap
    }

    Column {
      visible: root.editing
      width: parent.width
      spacing: Style.space(8)

      Text {
        visible: root.editingDefault
        width: parent.width
        text: "Deleting the default calendar hands the default to another calendar."
        textFormat: Text.PlainText
        color: Util.alpha(root.foreground, 0.56)
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        wrapMode: Text.WordWrap
      }

      Dropdown {
        id: promoteDropdown
        visible: root.editingDefault && root.promoteOptions.length > 0
        width: parent.width
        showLabel: false
        options: root.promoteOptions
        enabled: !root.busy
        foreground: root.foreground
        fontFamily: root.fontFamily
        onChanged: function(value) { root.promoteValue = value }
      }

      Binding {
        target: promoteDropdown
        property: "value"
        value: root.promoteValue
      }

      FormButton {
        width: parent.width
        text: root.busy ? "Deleting…" : "Delete calendar"
        foreground: Color.urgent
        enabled: !root.busy && (!root.editingDefault || root.promoteValue !== "")
        onClicked: root.submitAction("delete")
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
        text: root.busy ? "Saving…" : (root.editing ? "Save" : "Create")
        background: Util.alpha(root.foreground, 0.08)
        onClicked: root.submit()
      }
    }
  }
}
