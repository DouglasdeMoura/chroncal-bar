pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as QQC
import qs.Commons
import qs.Ui
import "../Model.js" as Model

Flickable {
  id: root

  property var bar: null
  property bool busy: false
  property string externalError: ""
  property string busyLabel: ""

  // Secrets live in these properties only until spawn; submit() clears
  // them and the bound fields. Switching the auth method keeps the typed
  // snapshot so going back restores it (like the Chroncal TUI).
  property string nameValue: ""
  property string serverValue: ""
  property string usernameValue: ""
  property string authValue: "basic"
  property string passwordValue: ""
  property string tokenValue: ""
  property string clientIdValue: ""
  property string clientSecretValue: ""
  property bool allowInsecureChecked: false
  property bool submitAttempted: false

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property string effectiveServer: String(serverValue || "").trim() || Model.defaultAccountServer(authValue)
  readonly property bool serverLoopback: Model.isLoopbackHttpServer(effectiveServer)
  readonly property bool allowInsecureEffective: serverLoopback || allowInsecureChecked
  readonly property var authOptions: [
    { value: "basic", label: "Password" },
    { value: "bearer", label: "Bearer token" },
    { value: "oauth2", label: "Google OAuth" }
  ]
  readonly property var validationErrors: Model.validateAccountForm(values())

  signal canceled()
  signal submitted(var values)
  signal cancelRequested()

  function values() {
    return {
      action: "add",
      name: String(nameValue || "").trim(),
      server: String(serverValue || "").trim(),
      username: String(usernameValue || "").trim(),
      auth: authValue,
      password: passwordValue,
      token: tokenValue,
      clientId: String(clientIdValue || "").trim(),
      clientSecret: clientSecretValue,
      allowInsecure: allowInsecureEffective
    }
  }

  function initialize() {
    nameValue = ""
    serverValue = ""
    usernameValue = ""
    authValue = "basic"
    clearSecrets()
    clientIdValue = ""
    allowInsecureChecked = false
    submitAttempted = false
    Qt.callLater(function() { nameField.forceActiveFocus() })
  }

  function closePickers() {
    authDropdown.close()
  }

  function clearSecrets() {
    passwordValue = ""
    tokenValue = ""
    clientSecretValue = ""
    // Typing breaks the text: bindings, so the visible fields keep
    // the secret unless they are cleared explicitly.
    passwordField.text = ""
    tokenField.text = ""
    clientSecretField.text = ""
  }

  function submit() {
    submitAttempted = true
    if (validationErrors.length > 0 || busy) return
    submitted(values())
    clearSecrets()
  }

  onVisibleChanged: {
    if (visible) initialize()
    else closePickers()
  }

  Keys.priority: Keys.BeforeItem
  Keys.onPressed: function(event) {
    if (event.key === Qt.Key_Escape) {
      if (authDropdown.popupOpen) authDropdown.close()
      else if (busy) cancelRequested()
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

  component FieldColumn: Column {
    width: parent.width
    spacing: Style.space(8)
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
      placeholderText: "Account name"
      onTextEdited: root.nameValue = text
      onAccepted: root.submit()
    }

    FieldLabel { text: "SERVER URL" }
    FormField {
      width: parent.width
      text: root.serverValue
      placeholderText: root.authValue === "oauth2"
        ? "https://apidata.googleusercontent.com/caldav"
        : "https://cal.example.com/dav/"
      onTextEdited: root.serverValue = text
      onAccepted: root.submit()
    }

    Text {
      visible: root.authValue === "oauth2" && String(root.serverValue || "").trim() === ""
      width: parent.width
      text: "Empty server signs in against Google's CalDAV endpoint."
      textFormat: Text.PlainText
      color: Util.alpha(root.foreground, 0.56)
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      wrapMode: Text.WordWrap
    }

    FieldLabel { text: "USERNAME" }
    FormField {
      width: parent.width
      text: root.usernameValue
      placeholderText: "you@example.com"
      onTextEdited: root.usernameValue = text
      onAccepted: root.submit()
    }

    FieldLabel { text: "SIGN-IN METHOD" }
    Dropdown {
      id: authDropdown
      width: parent.width
      showLabel: false
      options: root.authOptions
      enabled: !root.busy
      foreground: root.foreground
      fontFamily: root.fontFamily
      onChanged: function(value) { root.authValue = value }
    }

    Binding {
      target: authDropdown
      property: "value"
      value: root.authValue
    }

    FieldColumn {
      visible: root.authValue === "basic"

      FieldLabel { text: "PASSWORD" }
      SecretField {
        id: passwordField
        text: root.passwordValue
        placeholderText: "Password or app password"
        onTextEdited: root.passwordValue = text
        onAccepted: root.submit()
      }
    }

    FieldColumn {
      visible: root.authValue === "bearer"

      FieldLabel { text: "TOKEN" }
      SecretField {
        id: tokenField
        text: root.tokenValue
        placeholderText: "Bearer token"
        onTextEdited: root.tokenValue = text
        onAccepted: root.submit()
      }
    }

    FieldColumn {
      visible: root.authValue === "oauth2"

      FieldLabel { text: "OAUTH CLIENT ID" }
      FormField {
        text: root.clientIdValue
        placeholderText: "id.apps.googleusercontent.com"
        onTextEdited: root.clientIdValue = text
        onAccepted: root.submit()
      }

      FieldLabel { text: "OAUTH CLIENT SECRET" }
      SecretField {
        id: clientSecretField
        text: root.clientSecretValue
        placeholderText: "Client secret"
        onTextEdited: root.clientSecretValue = text
        onAccepted: root.submit()
      }

      Text {
        width: parent.width
        text: "Chroncal opens a browser window to authorize Google."
        textFormat: Text.PlainText
        color: Util.alpha(root.foreground, 0.56)
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        wrapMode: Text.WordWrap
      }
    }

    Toggle {
      width: parent.width
      label: "Allow HTTP"
      description: root.serverLoopback
        ? "Auto-enabled for localhost servers"
        : "Allow plain-HTTP server URLs"
      checked: root.allowInsecureEffective
      enabled: !root.busy && !root.serverLoopback
      foreground: root.foreground
      fontFamily: root.fontFamily
      onClicked: root.allowInsecureChecked = !root.allowInsecureChecked
    }

    Text {
      visible: root.allowInsecureChecked && !root.serverLoopback
      width: parent.width
      text: "HTTP is unencrypted; your password and events can be read on the network."
      textFormat: Text.PlainText
      color: Color.urgent
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

    Text {
      visible: root.busy
      width: parent.width
      text: root.busyLabel !== "" ? root.busyLabel : "Signing in…"
      textFormat: Text.PlainText
      color: Util.alpha(root.foreground, 0.62)
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      wrapMode: Text.WordWrap
    }

    Row {
      anchors.right: parent.right
      spacing: Style.space(8)

      FormButton {
        text: root.busy ? "Stop" : "Cancel"
        onClicked: root.busy ? root.cancelRequested() : root.canceled()
      }

      FormButton {
        text: root.busy ? "Adding…" : "Add account"
        background: Util.alpha(root.foreground, 0.08)
        onClicked: root.submit()
      }
    }
  }
}
