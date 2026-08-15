import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "douglasdemoura.chroncal-bar"

  property string outputText: ""
  property string outputTooltip: ""

  function filePathFromUrl(url) {
    var s = String(url || "")
    if (s.indexOf("file://") === 0) s = s.slice(7)
    try { s = decodeURIComponent(s) } catch (e) {}
    return s.replace(/\/$/, "")
  }

  readonly property string nextEventScript: filePathFromUrl(Qt.resolvedUrl("scripts/chroncal-next-event"))
  readonly property string openUrlScript: filePathFromUrl(Qt.resolvedUrl("scripts/chroncal-open-next-event-url"))

  function refresh() {
    if (!statusProc.running) statusProc.running = true
  }

  function update(raw) {
    var data = Util.parseModuleJson(raw)
    outputText = data.text || ""
    outputTooltip = data.tooltip || ""
  }

  function openChroncal() {
    if (root.bar) root.bar.run("omarchy-launch-floating-terminal-with-presentation chroncal")
  }

  function openNextEventUrl() {
    if (root.bar) root.bar.run(Util.shellQuote(openUrlScript))
  }

  visible: outputText !== ""
  implicitWidth: visible ? button.implicitWidth : 0
  implicitHeight: visible ? button.implicitHeight : 0

  Process {
    id: statusProc
    command: ["bash", "-lc", Util.shellQuote(root.nextEventScript)]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.update(text)
    }
  }

  Timer {
    interval: Math.max(15, Number(root.setting("interval", 60))) * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  IpcHandler {
    target: "douglasdemoura.chroncal-bar"
    function refresh(): void {
      root.broadcast("refresh")
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.outputText
    tooltipText: root.outputTooltip
    active: false
    horizontalMargin: Number(root.setting("horizontalMargin", 7.5))
    fontSize: Number(root.setting("fontSize", 12))
    onPressed: function(button) {
      if (button === Qt.MiddleButton) root.openNextEventUrl()
      else if (button === Qt.RightButton) root.refresh()
      else root.openChroncal()
    }
  }
}
