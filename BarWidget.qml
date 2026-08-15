import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

BarWidget {
  id: root
  moduleName: "douglasdemoura.chroncal-bar"

  property var agendaData: ({ status: "loading", events: [] })
  property bool loading: false
  property bool refreshPending: false

  function filePathFromUrl(url) {
    var value = String(url || "")
    if (value.indexOf("file://") === 0) value = value.slice(7)
    try { value = decodeURIComponent(value) } catch (error) {}
    return value.replace(/\/$/, "")
  }

  readonly property string chroncalExecScript: filePathFromUrl(Qt.resolvedUrl("scripts/chroncal-exec"))
  readonly property string agendaScript: filePathFromUrl(Qt.resolvedUrl("scripts/chroncal-bar-agenda"))
  readonly property string openUrlScript: filePathFromUrl(Qt.resolvedUrl("scripts/chroncal-open-next-event-url"))
  readonly property var filterOptions: ({
    includedCalendarIds: Model.selectedCalendarIds(agendaData.calendars, root.settings),
    calendarSelectionCustomized: Model.calendarSelectionCustomized(root.settings),
    showAllDay: root.setting("showAllDay", "On"),
    showEventsWithoutParticipants: root.setting("showEventsWithoutParticipants", "On"),
    showEventsWithoutLocation: root.setting("showEventsWithoutLocation", "On")
  })
  readonly property var filteredAgenda: Model.filterAgenda(agendaData, filterOptions)
  readonly property var presentation: Model.barPresentation(
    filteredAgenda,
    Number(root.setting("maxTitleLength", 42)),
    {
      showTime: root.setting("showTime", "On"),
      showTitle: root.setting("showTitle", "On"),
      relativeLeadMinutes: Number(root.setting("relativeLeadMinutes", 10))
    }
  )
  readonly property string displayText: presentation.text || "\uf133"

  function refresh() {
    if (agendaProc.running) {
      refreshPending = true
      return
    }
    refreshPending = false
    loading = true
    agendaProc.command = [agendaScript, "--days", String(Number(root.setting("lookaheadDays", 7)))]
    agendaProc.running = true
  }

  function updateAgenda(raw) {
    var parsed = Util.parseModuleJson(raw)
    agendaData = parsed && parsed.status ? parsed : ({ status: "unavailable", events: [] })
    loading = false
  }

  function openNextEventUrl() {
    if (root.bar) root.bar.run(Util.shellQuote(openUrlScript))
  }

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function open() {
    if (panelLoader.item) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function togglePanel() {
    if (panelLoader.item) panelLoader.item.toggle()
  }

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Process {
    id: agendaProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.updateAgenda(text)
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) root.updateAgenda("")
      if (root.refreshPending) Qt.callLater(function() { root.refresh() })
    }
  }

  Timer {
    interval: Math.max(15, Number(root.setting("interval", 60))) * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  IpcHandler {
    target: "douglasdemoura.chroncal-bar"
    function refresh(): void { root.broadcast("refresh") }
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.togglePanel() }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.displayText
    tooltipText: ""
    active: false
    horizontalMargin: Number(root.setting("horizontalMargin", 7.5))
    fontSize: Number(root.setting("fontSize", 12))
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.MiddleButton) root.openNextEventUrl()
      else if (buttonCode === Qt.RightButton) root.refresh()
      else root.togglePanel()
    }
  }
}
