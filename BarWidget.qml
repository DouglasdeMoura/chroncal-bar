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
  // Wall clock for countdowns and progress; ticks between agenda refreshes so
  // "in 5m" stays honest without spawning Chroncal every minute.
  property string nowIso: new Date().toISOString()
  property var notifiedEventKeys: ({})

  function filePathFromUrl(url) {
    var value = String(url || "")
    if (value.indexOf("file://") === 0) value = value.slice(7)
    try { value = decodeURIComponent(value) } catch (error) {}
    return value.replace(/\/$/, "")
  }

  readonly property string chroncalExecScript: filePathFromUrl(Qt.resolvedUrl("scripts/chroncal-exec"))
  readonly property string agendaScript: filePathFromUrl(Qt.resolvedUrl("scripts/chroncal-bar-agenda"))
  readonly property string notifyScript: filePathFromUrl(Qt.resolvedUrl("scripts/chroncal-bar-notify"))
  readonly property var filterOptions: ({
    includedCalendarIds: Model.selectedCalendarIds(agendaData.calendars, root.settings),
    calendarSelectionCustomized: Model.calendarSelectionCustomized(root.settings),
    showAllDay: root.setting("showAllDay", "On"),
    showEventsWithoutParticipants: root.setting("showEventsWithoutParticipants", "On"),
    showEventsWithoutLocation: root.setting("showEventsWithoutLocation", "On"),
    showDeclinedEvents: root.setting("showDeclinedEvents", "On")
  })
  readonly property var filteredAgenda: Model.filterAgenda(agendaData, filterOptions)
  readonly property var presentation: Model.barPresentation(
    filteredAgenda,
    Number(root.setting("maxTitleLength", 42)),
    {
      now: root.nowIso,
      showTime: root.setting("showTime", "On"),
      showTitle: root.setting("showTitle", "On"),
      relativeLeadMinutes: Number(root.setting("relativeLeadMinutes", 10)),
      barHorizonHours: Number(root.setting("barHorizonHours", 0))
    }
  )
  readonly property string displayText: presentation.text || "\uf133"
  readonly property string displayHtml: presentation.html || ""

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

  function tick() {
    root.nowIso = new Date().toISOString()
    root.checkReminders()
  }

  // Middle click / `join` IPC: the ongoing or next meeting with a video link,
  // else whatever link the event on the bar carries.
  function joinNextMeeting() {
    var event = Model.joinableEvent(filteredAgenda.events || [], root.nowIso)
    var url = event ? Model.eventConferenceUrl(event) : Model.eventOpenUrl(presentation.event)
    if (url === "" || !/^https?:\/\//i.test(url)) {
      Quickshell.execDetached(["notify-send", "-a", "Chroncal", "-u", "low", "Chroncal", "No meeting link for the next event"])
      return
    }
    Quickshell.execDetached(["xdg-open", url])
  }

  // Notion-style "starting now" alert with a Join action. Opt-in, since
  // Chroncal's own alarm service may already remind about the same event.
  function checkReminders() {
    var lead = Number(root.setting("joinReminderMinutes", -1))
    if (!(lead >= 0) || filteredAgenda.status !== "ok") return
    var due = Model.dueReminders(filteredAgenda.events || [], root.nowIso, lead, root.notifiedEventKeys)
    if (due.length === 0) return
    var seen = {}
    for (var key in root.notifiedEventKeys) seen[key] = root.notifiedEventKeys[key]
    for (var index = 0; index < due.length; index++) {
      var event = due[index]
      seen[Model.eventKey(event)] = event.end_time
      var url = Model.eventConferenceUrl(event)
      Quickshell.execDetached([root.notifyScript, String(event.title || "Untitled"), Model.reminderBody(event, root.nowIso), url, Model.eventJoinLabel(event)])
    }
    root.notifiedEventKeys = Model.pruneReminderKeys(seen, root.nowIso)
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
    interval: 15000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.tick()
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
    function join(): void { root.joinNextMeeting() }
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
    labelVisible: root.displayHtml === ""
    tooltipText: ""
    active: false
    horizontalMargin: Number(root.setting("horizontalMargin", 7.5))
    fontSize: Number(root.setting("fontSize", 12))
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.MiddleButton) root.joinNextMeeting()
      else if (buttonCode === Qt.RightButton) root.refresh()
      else root.togglePanel()
    }

    // StyledText lets each calendar square carry its own <font color>; the
    // plain label above stays for the icon fallback and width measurement.
    Text {
      id: styledLabel
      visible: root.displayHtml !== ""
      anchors.centerIn: parent
      // Same figure-centering offset WidgetButton applies to its own label.
      anchors.verticalCenterOffset: (styledMetrics.descent - styledMetrics.ascent + styledMetrics.tightBoundingRect("0").height) / 2
      textFormat: Text.StyledText
      text: root.displayHtml
      color: button.foreground
      font.family: button.fontFamily
      font.pixelSize: button.fontSize
      renderType: Text.NativeRendering
      scale: button.pressScale
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter
    }

    FontMetrics {
      id: styledMetrics
      font: styledLabel.font
    }
  }
}
