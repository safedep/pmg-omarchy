import QtQuick
import Quickshell
import Quickshell.Io
import "PmgModel.js" as PmgModel

// PmgService is the data engine. It polls `pmg setup info --json` for health and
// layers, and watches today's event log for the feed and block alerts. It owns
// all state. The widget and panel show it.
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
  // False when pmg runs but gives no JSON. This means a build before PMG 0.26.
  property bool pmgSupported: true

  readonly property string health: !pmgAvailable ? "unavailable"
                                 : !pmgSupported ? "outdated"
                                 : (status && status.health ? status.health : "unknown")
  readonly property string severity: !pmgAvailable ? "bad"
                                    : !pmgSupported ? "warn"
                                    : PmgModel.healthSeverity(status ? status.health : undefined)
  readonly property var layers: status && status.layers ? status.layers : null
  readonly property var shellInfo: status && status.shell_integration ? status.shell_integration : null
  readonly property string version: status && status.version ? status.version : ""
  // True when pmg is installed but not set up. The panel then offers setup.
  readonly property bool needsSetup: pmgAvailable && status !== null && status.protected === false

  // A login shell finds pmg on PATH under a minimal compositor environment.
  Process {
    id: infoProc
    running: false
    command: ["bash", "-lc", "pmg setup info --json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyInfo(text)
    }
    onExited: function (exitCode) {
      if (exitCode === 0) return
      if (exitCode === 127) {
        root.pmgAvailable = false
        root.status = null
      } else {
        root.pmgSupported = false
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
        root.pmgSupported = true
      }
    } catch (e) {
      // Keep the last status on a parse failure, for example a truncated read.
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

  // Recompute on a timer so the feed follows the log across midnight rotation.
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

  // Seed the cutoff to start time. Blocks written after start always alert.
  // Older history never replays, including the first read of a new day's log.
  property double blockCutoff: Date.now()
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

  function applyLog(text) {
    var evs = PmgModel.parseLog(text)
    root.events = evs

    var fresh = PmgModel.newBlocksSince(evs, root.blockCutoff)
    if (fresh.length === 0) return

    // fresh is newest-first. Advance the cutoff past all of them. Alert
    // oldest-first so a burst notifies in order. The overlay ends on the newest.
    root.blockCutoff = PmgModel.timestampMillis(fresh[0])
    for (var i = fresh.length - 1; i >= 0; i--) {
      root.onBlock(fresh[i])
    }
  }

  function onBlock(ev) {
    if (root.showOverlay) root.pendingBlock = ev

    if (root.notifyOnBlock && root.omarchyPath !== "") {
      var name = (ev.package_name || "unknown") + (ev.version ? "@" + ev.version : "")
      var ecoLabel = PmgModel.humanizeEcosystem(ev.ecosystem)
      var eco = ecoLabel ? " (" + ecoLabel + ")" : ""
      Quickshell.execDetached([root.omarchyPath + "/bin/omarchy-notification-send",
        "PMG blocked a package", name + eco + ". Install aborted."])
    }
  }
}
