import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

// Entry point: a package icon in the bar and its panel. The root Panel is the
// bar slot and hosts the popup. All state comes from PmgService.
Panel {
  id: root
  moduleName: "io.github.safedep.pmg"
  ipcTarget: "io.github.safedep.pmg"
  manageIpc: true

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color surface: Color.popups.background
  readonly property color dim: Qt.darker(foreground, 1.5)
  readonly property color track: Style.selectedFillFor(foreground, Color.accent)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  // Semantic colours. Green and amber have no theme token, so darken them on a
  // light surface for contrast. Red uses the theme urgent role.
  readonly property bool lightSurface: (0.2126 * surface.r + 0.7152 * surface.g + 0.0722 * surface.b) > 0.5
  readonly property color cAllow: lightSurface ? "#1f9d57" : "#37d979"
  readonly property color cHold: lightSurface ? "#b0771c" : "#e0af68"
  readonly property color cBlock: urgent

  function severityColor(sev) {
    switch (sev) {
    case "ok": return foreground
    case "warn": return cHold
    case "bad": return cBlock
    }
    return foreground
  }
  function rowColor(sev) {
    switch (sev) {
    case "block": return cBlock
    case "hold": return cHold
    case "allow": return cAllow
    }
    return dim
  }

  // The hero title is always "PMG". This is the status word for the badge.
  readonly property string heroBadge: {
    if (!svc.pmgAvailable) return "Unavailable"
    if (!svc.pmgSupported) return "Outdated"
    switch (svc.health) {
    case "protected": return "Protected"
    case "degraded": return "Degraded"
    case "unprotected": return "Unprotected"
    }
    return "Unknown"
  }
  readonly property string barTooltip: {
    if (!svc.pmgAvailable) return "PMG not available on PATH"
    if (!svc.pmgSupported) return "PMG is too old for live status. Update to 0.26 or later."
    var t = svc.today
    return "PMG: " + svc.health + " · " + t.analyzed + " vetted today"
      + (t.blocked > 0 ? " · " + t.blocked + " blocked" : "")
  }

  PmgService {
    id: svc
    settings: root.settings
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰏗"
    useActiveColor: false
    foreground: root.severityColor(svc.severity)
    tooltipText: root.barTooltip
    onPressed: function (buttonCode) {
      if (buttonCode === Qt.LeftButton) root.toggle()
      else if (buttonCode === Qt.RightButton) root.runInfo()
    }
  }

  BlockOverlay {
    id: blockOverlay
    blockEvent: svc.pendingBlock
    onDismissed: svc.clearPendingBlock()
  }

  function runDoctor() {
    if (root.bar) root.bar.run("omarchy-launch-floating-terminal-with-presentation 'pmg setup doctor'")
  }
  function runInfo() {
    if (root.bar) root.bar.run("omarchy-launch-floating-terminal-with-presentation 'pmg setup info'")
  }
  function runSetup() {
    if (root.bar) root.bar.run("omarchy-launch-floating-terminal-with-presentation 'pmg setup install'")
  }
  function openLogs() {
    Quickshell.execDetached(["xdg-open", svc.logDir])
  }

  // ------------------------------------------------------------ the panel

  component LayerRow: Item {
    property string label: ""
    property string value: ""
    property color valueColor: root.foreground
    width: parent ? parent.width : 0
    implicitHeight: Style.space(22)
    Text {
      id: layerLabel
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: label
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
    }
    Text {
      anchors.left: layerLabel.right
      anchors.leftMargin: Style.spacing.md
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      horizontalAlignment: Text.AlignRight
      elide: Text.ElideRight
      text: value
      color: valueColor
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
    }
  }

  component StatCount: Column {
    property string label: ""
    property int value: 0
    property color valueColor: root.foreground
    spacing: Style.space(2)
    Text {
      text: value
      color: valueColor
      font.family: root.fontFamily
      font.pixelSize: Style.font.heading
      font.bold: true
    }
    Text {
      text: label
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }
  }

  component ActionButton: Rectangle {
    property string label: ""
    signal clicked()
    width: parent ? parent.width : 0
    implicitHeight: Style.space(28)
    radius: Style.cornerRadius > 0 ? Style.cornerRadius : Style.space(6)
    color: actionMouse.containsMouse ? Style.hoverFill : "transparent"
    border.width: 1
    border.color: Style.normalBorderColor
    Text {
      anchors.centerIn: parent
      text: parent.label
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
    }
    MouseArea {
      id: actionMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: parent.clicked()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(320))
    contentHeight: panel.fittedContentHeight(body.implicitHeight, Style.space(680))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      // PanelKeyCatcher consumes the arrow keys, so drive the Flickable here.
      onMoveRequested: function (dx, dy) {
        if (dy === 0) return
        var max = Math.max(0, flick.contentHeight - flick.height)
        flick.contentY = Math.max(0, Math.min(max, flick.contentY + dy * Style.space(48)))
      }

      Flickable {
        id: flick
        anchors.fill: parent
        contentHeight: body.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
          id: body
          width: parent.width
          spacing: Style.spacing.md

          PanelHero {
            width: parent.width
            title: "PMG"
            meta: svc.version !== "" ? "v" + svc.version : ""
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconComponent: Component {
              Text {
                text: "󰏗"
                color: root.severityColor(svc.severity)
                font.family: root.fontFamily
                font.pixelSize: Style.font.display
              }
            }
            trailingControl: Component {
              Rectangle {
                property color sev: root.severityColor(svc.severity)
                radius: Style.space(5)
                implicitWidth: heroBadgeText.implicitWidth + Style.space(14)
                implicitHeight: heroBadgeText.implicitHeight + Style.space(6)
                color: Qt.rgba(sev.r, sev.g, sev.b, 0.14)
                border.width: 1
                border.color: sev
                Text {
                  id: heroBadgeText
                  anchors.centerIn: parent
                  text: root.heroBadge
                  color: sev
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }
              }
            }
          }

          // ---- Protection layers ----
          Column {
            width: parent.width
            spacing: Style.space(2)
            visible: svc.layers !== null

            PanelSeparator { width: parent.width; foreground: root.foreground }
            PanelSectionHeader {
              text: "PROTECTION LAYERS"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }
            LayerRow {
              label: "Threat intelligence"
              value: svc.layers && svc.layers.threat_intel ? "live" : "off"
              valueColor: svc.layers && svc.layers.threat_intel ? root.cAllow : root.dim
            }
            LayerRow {
              label: "Dependency cooldown"
              value: svc.layers && svc.layers.cooldown && svc.layers.cooldown.enabled
                ? svc.layers.cooldown.days + " days" : "off"
              valueColor: svc.layers && svc.layers.cooldown && svc.layers.cooldown.enabled ? root.cAllow : root.dim
            }
            LayerRow {
              label: "Sandbox"
              value: svc.layers && svc.layers.sandbox && svc.layers.sandbox.enabled
                ? (svc.layers.sandbox.ready ? svc.layers.sandbox.driver : svc.layers.sandbox.driver + " (unavailable)")
                : "off"
              valueColor: svc.layers && svc.layers.sandbox && svc.layers.sandbox.enabled && svc.layers.sandbox.ready
                ? root.cAllow : root.cHold
            }
            LayerRow {
              label: "MITM CA"
              value: {
                var ca = svc.layers ? svc.layers.ca : null
                if (!ca || !ca.trusted) return "not trusted"
                var s = "trusted (" + ca.scope + ")"
                // Show the expiry only when it is within a year, to avoid noise.
                if (ca.expires && Date.parse(ca.expires) - svc.nowMs < 365 * 86400000) {
                  s += " · exp " + String(ca.expires).slice(0, 10)
                }
                return s
              }
              valueColor: {
                var ca = svc.layers ? svc.layers.ca : null
                if (!ca || !ca.trusted) return root.dim
                if (ca.expires && Date.parse(ca.expires) - svc.nowMs < 30 * 86400000) return root.cHold
                return root.cAllow
              }
            }
            LayerRow {
              label: "Persistent proxy"
              value: svc.layers && svc.layers.proxy && svc.layers.proxy.running
                ? svc.layers.proxy.addr : "not running"
              valueColor: svc.layers && svc.layers.proxy && svc.layers.proxy.running ? root.cAllow : root.dim
            }
          }

          // ---- Today ----
          Column {
            width: parent.width
            spacing: Style.space(6)

            PanelSeparator { width: parent.width; foreground: root.foreground }
            PanelSectionHeader {
              text: "TODAY"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }
            Row {
              width: parent.width
              spacing: Style.spacing.lg
              StatCount { label: "vetted"; value: svc.today.analyzed; valueColor: root.foreground }
              StatCount { label: "allowed"; value: svc.today.allowed; valueColor: root.cAllow }
              StatCount { label: "held"; value: svc.today.held; valueColor: root.cHold }
              StatCount { label: "blocked"; value: svc.today.blocked; valueColor: root.cBlock }
            }
            Rectangle {
              width: parent.width
              height: Style.space(6)
              radius: height / 2
              color: root.track
              Row {
                anchors.fill: parent
                Rectangle {
                  width: svc.today.analyzed > 0 ? parent.width * svc.today.allowed / svc.today.analyzed : 0
                  height: parent.height
                  color: root.cAllow
                }
                Rectangle {
                  width: svc.today.analyzed > 0 ? parent.width * svc.today.held / svc.today.analyzed : 0
                  height: parent.height
                  color: root.cHold
                }
                Rectangle {
                  width: svc.today.analyzed > 0 ? parent.width * svc.today.blocked / svc.today.analyzed : 0
                  height: parent.height
                  color: root.cBlock
                }
              }
            }
          }

          // ---- Actions ----
          // Kept above the feed so they never need scrolling to reach.
          Column {
            width: parent.width
            spacing: Style.space(6)

            PanelSeparator { width: parent.width; foreground: root.foreground }
            ActionButton {
              width: parent.width
              label: "Run pmg setup install"
              visible: svc.needsSetup
              onClicked: root.runSetup()
            }
            Row {
              width: parent.width
              spacing: Style.space(6)
              ActionButton {
                width: (parent.width - Style.space(6)) / 2
                label: "Run doctor"
                onClicked: root.runDoctor()
              }
              ActionButton {
                width: (parent.width - Style.space(6)) / 2
                label: "Open logs"
                onClicked: root.openLogs()
              }
            }
          }

          // ---- Recent activity ----
          Column {
            width: parent.width
            spacing: Style.space(2)

            PanelSeparator { width: parent.width; foreground: root.foreground }
            PanelSectionHeader {
              text: "RECENT ACTIVITY"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }
            Text {
              visible: svc.feed.length === 0
              width: parent.width
              text: "No activity today"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
            }
            Repeater {
              model: svc.feed
              delegate: Item {
                required property var modelData
                width: parent ? parent.width : 0
                implicitHeight: Style.space(32)
                Rectangle {
                  id: rail
                  width: Style.space(3)
                  radius: width / 2
                  anchors.top: parent.top
                  anchors.bottom: parent.bottom
                  anchors.topMargin: Style.space(4)
                  anchors.bottomMargin: Style.space(4)
                  color: root.rowColor(modelData.severity)
                }
                Text {
                  id: agoText
                  anchors.right: parent.right
                  anchors.top: parent.top
                  anchors.topMargin: Style.space(4)
                  text: modelData.ago
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }
                Column {
                  anchors.left: rail.right
                  anchors.leftMargin: Style.spacing.sm
                  anchors.right: agoText.left
                  anchors.rightMargin: Style.spacing.sm
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(1)
                  Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: modelData.pkg + (modelData.version !== "" ? " " + modelData.version : "")
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                  }
                  Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: modelData.verdict
                      + (modelData.ecosystem !== "" ? " · " + modelData.ecosystem : "")
                      + (modelData.count > 1 ? " · ×" + modelData.count : "")
                    color: root.rowColor(modelData.severity)
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                  }
                }
              }
            }
          }

        }
      }
    }
  }
}
