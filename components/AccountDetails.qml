pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as QQC
import qs.Commons
import qs.Ui

Flickable {
  id: root

  property var bar: null
  property var account: null
  property var calendars: []
  property bool busy: false
  property string externalError: ""
  property string busyLabel: ""
  // "none" | "rename" | "credentials". Panel clears this after a
  // successful credentials/reauth mutation.
  property string mode: "none"
  property string nameValue: ""
  property string secretValue: ""
  property bool submitAttempted: false

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property var accountData: account || {}
  readonly property string accountId: String(accountData.id || "")
  // The calendar list carries no auth_type until Task 12 hydrates
  // accounts; empty reads as password auth.
  readonly property string authType: accountData.auth_type === "bearer" || accountData.auth_type === "oauth2"
    ? String(accountData.auth_type)
    : "basic"
  readonly property string authLabel: authType === "oauth2" ? "Google OAuth" : (authType === "bearer" ? "Bearer token" : "Password")
  readonly property int calendarCount: accountData.calendar_count !== undefined
    ? Number(accountData.calendar_count)
    : countedCalendars
  readonly property int countedCalendars: {
    var target = accountId
    if (target === "") return 0
    var count = 0
    var list = calendars || []
    for (var i = 0; i < list.length; i += 1)
      if (String((list[i] || {}).account_id || "") === target) count += 1
    return count
  }
  readonly property var validationErrors: validate()

  signal canceled()
  signal submitted(var values)
  signal cancelRequested()
  signal manageCalendarsRequested(var account)

  function validate() {
    var errors = []
    if (mode === "rename" && String(nameValue || "").trim() === "") errors.push("Name is required")
    if (mode === "credentials" && String(secretValue || "") === "")
      errors.push(authType === "bearer" ? "Token is required" : "Password is required")
    return errors
  }

  function initialize() {
    mode = "none"
    nameValue = String(accountData.display_name || accountData.name || "")
    secretValue = ""
    // Typing breaks the text: binding, so clear the field explicitly.
    secretField.text = ""
    submitAttempted = false
    Qt.callLater(function() { root.forceActiveFocus() })
  }

  function closeSubforms() {
    mode = "none"
    secretValue = ""
    secretField.text = ""
  }

  function submitAction(action) {
    if (busy) return
    submitAttempted = true
    if (validationErrors.length > 0) return
    var form = { action: action, id: accountId }
    if (action === "rename") form.name = String(nameValue || "").trim()
    if (action === "credentials") {
      form.auth = authType
      form.password = authType === "basic" ? secretValue : ""
      form.token = authType === "bearer" ? secretValue : ""
    }
    submitted(form)
    // The secret never stays on screen after spawn; typing broke the
    // text: binding, so the field is cleared explicitly too.
    if (action === "credentials") {
      secretValue = ""
      secretField.text = ""
    }
  }

  onVisibleChanged: if (visible) initialize()

  Keys.priority: Keys.BeforeItem
  Keys.onPressed: function(event) {
    if (event.key === Qt.Key_Escape) {
      if (mode !== "none") closeSubforms()
      else if (busy) cancelRequested()
      else canceled()
      event.accepted = true
    } else if ((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
      if (mode === "rename") submitAction("rename")
      else if (mode === "credentials") submitAction("credentials")
      event.accepted = true
    } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_S) {
      if (mode === "rename") submitAction("rename")
      else if (mode === "credentials") submitAction("credentials")
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

  component SecretField: TextField {
    width: parent.width
    password: true
    color: root.foreground
    placeholderTextColor: Util.alpha(root.foreground, 0.42)
    font.family: root.fontFamily
    selectByMouse: true
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

    Text {
      width: parent.width
      text: String(root.accountData.display_name || root.accountData.name || "Account")
      textFormat: Text.PlainText
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.title
      font.bold: true
      wrapMode: Text.WordWrap
    }

    Caption {
      visible: String(root.accountData.server_url || "") !== ""
      text: String(root.accountData.server_url || "")
    }

    Caption {
      visible: String(root.accountData.username || "") !== ""
      text: String(root.accountData.username || "")
    }

    Caption { text: root.authLabel }

    Caption { text: root.calendarCount === 1 ? "1 calendar" : root.calendarCount + " calendars" }

    Text {
      visible: root.busy
      width: parent.width
      text: root.busyLabel !== "" ? root.busyLabel : "Working…"
      textFormat: Text.PlainText
      color: Util.alpha(root.foreground, 0.62)
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      wrapMode: Text.WordWrap
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

    FormButton {
      width: parent.width
      text: "Manage calendars"
      onClicked: root.manageCalendarsRequested(root.accountData)
    }

    FormButton {
      width: parent.width
      text: root.busy && root.mode === "none" ? "Working…" : "Sync now"
      onClicked: root.submitAction("sync")
    }

    FormButton {
      width: parent.width
      text: root.mode === "rename" ? "Close rename" : "Rename"
      onClicked: {
        root.mode = root.mode === "rename" ? "none" : "rename"
        root.submitAttempted = false
      }
    }

    Column {
      visible: root.mode === "rename"
      width: parent.width
      spacing: Style.space(8)

      FieldLabel { text: "NAME" }
      FormField {
        id: renameField
        width: parent.width
        text: root.nameValue
        placeholderText: "Account name"
        onTextEdited: root.nameValue = text
        onAccepted: root.submitAction("rename")
      }

      FormButton {
        width: parent.width
        text: "Save name"
        onClicked: root.submitAction("rename")
      }
    }

    FormButton {
      visible: root.authType === "oauth2"
      width: parent.width
      text: "Sign in again"
      onClicked: root.submitAction("reauth")
    }

    FormButton {
      visible: root.authType !== "oauth2"
      width: parent.width
      text: root.mode === "credentials" ? "Close credentials" : "Update credentials"
      onClicked: {
        root.mode = root.mode === "credentials" ? "none" : "credentials"
        root.submitAttempted = false
      }
    }

    Column {
      visible: root.mode === "credentials"
      width: parent.width
      spacing: Style.space(8)

      FieldLabel { text: root.authType === "bearer" ? "TOKEN" : "PASSWORD" }
      SecretField {
        id: secretField
        text: root.secretValue
        placeholderText: root.authType === "bearer" ? "New bearer token" : "New password"
        onTextEdited: root.secretValue = text
        onAccepted: root.submitAction("credentials")
      }

      FormButton {
        width: parent.width
        text: "Save credentials"
        onClicked: root.submitAction("credentials")
      }
    }

    FormButton {
      width: parent.width
      text: "Remove account"
      foreground: Color.urgent
      onClicked: root.submitAction("remove")
    }

    Caption { text: "Removal keeps local copies of this account's events." }
  }
}
