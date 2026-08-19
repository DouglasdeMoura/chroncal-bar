pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as QQC
import qs.Commons
import qs.Ui

Flickable {
  id: root

  property var bar: null
  property var account: null
  property var rows: []
  property bool loading: false
  property bool busy: false
  property string externalError: ""
  // Id of the default calendar that belongs to this account ("" when none).
  property string defaultCalendarId: ""

  property var checkedPaths: []
  property string defaultValue: ""

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  // The imported default row; unchecking it forces a replacement pick.
  readonly property var defaultRow: {
    var target = String(defaultCalendarId || "")
    if (target === "") return null
    var list = rows || []
    for (var i = 0; i < list.length; i += 1) {
      var row = list[i] || {}
      if (row.imported === true && String(row.calendar_id || "") === target) return row
    }
    return null
  }
  readonly property bool defaultNeedsPick: defaultRow !== null
    && checkedPaths.indexOf(String(defaultRow.path || "")) === -1
    && checkedPaths.length > 0
  readonly property var defaultOptions: {
    var options = []
    var list = rows || []
    for (var i = 0; i < list.length; i += 1) {
      var row = list[i] || {}
      if (row.importable === true && row.missing !== true
        && checkedPaths.indexOf(String(row.path || "")) !== -1)
        options.push({ value: String(row.path || ""), label: String(row.name || "Calendar") })
    }
    return options
  }
  readonly property bool someImportedUnchecked: {
    var list = rows || []
    for (var i = 0; i < list.length; i += 1) {
      var row = list[i] || {}
      if (row.imported === true && checkedPaths.indexOf(String(row.path || "")) === -1) return true
    }
    return false
  }
  readonly property bool canSubmit: !loading && !busy
    && !(rows.length === 0 && externalError !== "")
    && (!defaultNeedsPick || checkedPaths.indexOf(defaultValue) !== -1)

  signal canceled()
  signal submitted(var values)

  function resetChecks() {
    var paths = []
    var list = rows || []
    for (var i = 0; i < list.length; i += 1) {
      var row = list[i] || {}
      if (row.imported === true && String(row.path || "") !== "") paths.push(String(row.path))
    }
    checkedPaths = paths
    defaultValue = ""
  }

  function togglePath(path) {
    if (busy || loading) return
    var key = String(path || "")
    var next = checkedPaths.slice()
    var index = next.indexOf(key)
    if (index >= 0) {
      next.splice(index, 1)
      // An unchecked calendar cannot stay the replacement default.
      if (key === defaultValue) defaultValue = ""
    } else next.push(key)
    checkedPaths = next
  }

  function closePickers() {
    defaultDropdown.close()
  }

  function values() {
    return { paths: checkedPaths, none: checkedPaths.length === 0, defaultRef: defaultValue }
  }

  function submit() {
    if (!canSubmit) return
    submitted(values())
  }

  onRowsChanged: resetChecks()
  onVisibleChanged: {
    if (visible) {
      resetChecks()
      Qt.callLater(function() { root.forceActiveFocus() })
    } else closePickers()
  }
  onDefaultNeedsPickChanged: if (!defaultNeedsPick) defaultValue = ""

  Keys.priority: Keys.BeforeItem
  Keys.onPressed: function(event) {
    if (event.key === Qt.Key_Escape) {
      if (defaultDropdown.popupOpen) defaultDropdown.close()
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

  component FormButton: Button {
    foreground: root.foreground
    fontFamily: root.fontFamily
    bordered: true
    focusable: true
    enabled: !root.busy && !root.loading
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

    Text {
      width: parent.width
      text: String(root.account !== null ? (root.account.display_name || root.account.name || "Account") : "Account")
      textFormat: Text.PlainText
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.title
      font.bold: true
      wrapMode: Text.WordWrap
    }

    Text {
      visible: root.loading
      width: parent.width
      text: "Loading calendars…"
      color: Util.alpha(root.foreground, 0.62)
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      wrapMode: Text.WordWrap
    }

    Column {
      visible: !root.loading
      width: parent.width
      spacing: Style.space(6)

      Repeater {
        model: root.rows

        Column {
          id: discoveryRow
          required property var modelData
          width: parent.width
          spacing: Style.space(2)

          Toggle {
            visible: discoveryRow.modelData.importable === true && discoveryRow.modelData.missing !== true
            width: parent.width
            label: String(discoveryRow.modelData.name || "Calendar")
            description: [String(discoveryRow.modelData.description || ""),
              String(discoveryRow.modelData.access || "") === "read" ? "read-only" : ""]
              .filter(function(part) { return part !== "" }).join(" · ")
            checked: root.checkedPaths.indexOf(String(discoveryRow.modelData.path || "")) !== -1
            enabled: !root.busy && !root.loading
            opacity: enabled ? 1 : 0.55
            foreground: root.foreground
            fontFamily: root.fontFamily
            onClicked: root.togglePath(discoveryRow.modelData.path)
          }

          Text {
            visible: !(discoveryRow.modelData.importable === true && discoveryRow.modelData.missing !== true)
            width: parent.width
            text: String(discoveryRow.modelData.name || "Calendar")
            textFormat: Text.PlainText
            color: Util.alpha(root.foreground, 0.62)
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            elide: Text.ElideRight
          }

          Caption {
            visible: !(discoveryRow.modelData.importable === true && discoveryRow.modelData.missing !== true)
            text: discoveryRow.modelData.missing === true ? "missing" : "unsupported"
          }
        }
      }

      FieldLabel { visible: root.defaultNeedsPick; text: "NEW DEFAULT" }

      Dropdown {
        id: defaultDropdown
        visible: root.defaultNeedsPick
        width: parent.width
        showLabel: false
        options: root.defaultOptions
        enabled: !root.busy && !root.loading
        foreground: root.foreground
        fontFamily: root.fontFamily
        onChanged: function(value) { root.defaultValue = value }
      }

      Binding {
        target: defaultDropdown
        property: "value"
        value: root.defaultValue
      }
    }

    Text {
      visible: !root.loading && root.checkedPaths.length === 0
      width: parent.width
      text: "No calendars selected. Saving removes the account and its stored credential from Chroncal. Remote calendars are never deleted."
      textFormat: Text.PlainText
      color: Color.urgent
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      wrapMode: Text.WordWrap
    }

    Caption {
      visible: !root.loading && root.checkedPaths.length > 0 && root.someImportedUnchecked
      text: "Deselected calendars and their downloaded data are removed from this computer. Remote calendars are never deleted."
    }

    Text {
      visible: root.externalError !== ""
      width: parent.width
      text: root.externalError
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
        text: root.busy ? "Saving…" : "Save"
        onClicked: root.submit()
      }
    }
  }
}
