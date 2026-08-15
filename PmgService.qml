import QtQuick
import Quickshell
import Quickshell.Io
import "PmgModel.js" as PmgModel

// PmgService is the headless data engine. It polls `pmg setup info --json` for
// protection health + layers and watches today's JSONL event log for the live
// feed and block alerts. It owns all state and exposes it as bindable
// properties; the widget and panel are pure presentation over it.
Item {
  id: root
  visible: false

  property var settings: ({})
  function setting(name, fallback) {
    var v = settings ? settings[name] : undefined
    return (v === undefined || v === null) ? fallback : v
  }

  readonly property int refreshIntervalSec: Math.max(10, Number(setting("refreshIntervalSec", 30)))
  readonly property int feedLimit: Math.max(5, Number(setting("feedLimit", 12)))
  readonly property bool showOverlay: String(setting("showOverlay", "On")) === "On"
  readonly property bool notifyOnBlock: String(setting("notifyOnBlock", "On")) === "On"

  readonly property string omarchyPath: Quickshell.env("OMARCHY_PATH") || ""
  readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")
  readonly property string logDir: configHome + "/safedep/pmg/logs"

  // ---------------------------------------------------------------- status

  property var status: null
  property bool pmgAvailable: true

  readonly property string health: status && status.health ? status.health
                                                           : (pmgAvailable ? "unknown" : "unavailable")
  readonly property string severity: pmgAvailable ? PmgModel.healthSeverity(status ? status.health : undefined) : "bad"
  readonly property var layers: status && status.layers ? status.layers : null
  readonly property var shellInfo: status && status.shell_integration ? status.shell_integration : null
  readonly property string version: status && status.version ? status.version : ""
  // Unprotected with an installed-but-unconfigured PMG: the panel offers a
  // one-click setup instead of an empty dashboard.
  readonly property bool needsSetup: pmgAvailable && status !== null && status.protected === false

  // A login shell resolves PMG on PATH even when the compositor launched the
  // Omarchy shell with a minimal environment.
  Process {
    id: infoProc
    running: false
    command: ["bash", "-lc", "pmg setup info --json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyInfo(text)
    }
    onExited: function (exitCode) {
      if (exitCode === 127) {
        root.pmgAvailable = false
        root.status = null
      }
    }
  }

  function refreshStatus() {
    if (!infoProc.running) infoProc.running = true
  }

  function applyInfo(text) {
    try {
      var parsed = JSON.parse(String(text || ""))
      if (parsed && typeof parsed === "object") {
        root.status = parsed
        root.pmgAvailable = true
      }
    } catch (e) {
      // Transient parse failure (e.g. a truncated read): keep the last status.
    }
  }

  Timer {
    interval: root.refreshIntervalSec * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refreshStatus()
  }

  // ------------------------------------------------------------- event log

  // Recomputed on a timer so the feed follows the date-stamped log across
  // midnight rotation without restarting the shell.
  property string logName: PmgModel.dailyLogName(new Date())
  readonly property string logPath: logDir + "/" + logName

  Timer {
    interval: 60000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.logName = PmgModel.dailyLogName(new Date())
  }

  property var events: []
  property double nowMs: Date.now()

  Timer {
    interval: 30000
    running: true
    repeat: true
    onTriggered: root.nowMs = Date.now()
  }

  readonly property var today: PmgModel.todayCounts(events)
  readonly property var feed: PmgModel.feedRows(events, feedLimit, nowMs)

  // blockCutoff is the newest block timestamp already surfaced. It starts unset
  // so the first load establishes a baseline instead of replaying history.
  property double blockCutoff: -1
  property var pendingBlock: null
  function clearPendingBlock() { pendingBlock = null }

  FileView {
    id: logFile
    path: root.logPath
    watchChanges: true
    printErrors: false
    onLoaded: root.applyLog(text())
    onFileChanged: reload()
    onLoadFailed: root.events = []
  }

  function newestTimestamp(evs) {
    var m = 0
    for (var i = 0; i < evs.length; i++) {
      var t = PmgModel.timestampMillis(evs[i])
      if (t > m) m = t
    }
    return m
  }

  function applyLog(text) {
    var evs = PmgModel.parseLog(text)
    root.events = evs

    if (root.blockCutoff < 0) {
      root.blockCutoff = newestTimestamp(evs)
      return
    }

    var fresh = PmgModel.newBlocksSince(evs, root.blockCutoff)
    if (fresh.length > 0) {
      root.blockCutoff = PmgModel.timestampMillis(fresh[0])
      root.onBlock(fresh[0])
    }
  }

  function onBlock(ev) {
    if (root.showOverlay) root.pendingBlock = ev

    if (root.notifyOnBlock && root.omarchyPath !== "") {
      var name = (ev.package_name || "unknown") + (ev.version ? "@" + ev.version : "")
      var eco = ev.ecosystem ? " (" + ev.ecosystem + ")" : ""
      Quickshell.execDetached([root.omarchyPath + "/bin/omarchy-notification-send",
        "PMG blocked malware", name + eco + " — install aborted"])
    }
  }
}
