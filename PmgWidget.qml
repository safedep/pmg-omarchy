import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

// Entry point: a shield in the bar plus its panel. The root Panel doubles as the
// bar slot (implicit size follows the button) and hosts the popup. All state
// comes from PmgService; this file is presentation only.
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

  // Semantic status colours. Green/amber have no theme token (like PMG's own
  // doctor output), so they are fixed; red tracks the theme's urgent role.
  readonly property color cAllow: "#37d979"
  readonly property color cHold: "#e0af68"
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

  readonly property string heroTitle: {
    if (!svc.pmgAvailable) return "PMG unavailable"
    switch (svc.health) {
    case "protected": return "Protected"
    case "degraded": return "Degraded"
    case "unprotected": return "Unprotected"
    }
    return "PMG"
  }
  readonly property string heroDetail: {
    if (!svc.pmgAvailable) return "pmg was not found on PATH"
    if (svc.needsSetup) return "Run pmg setup install to activate protection"
    var t = svc.today
    return t.analyzed + " vetted today · " + t.allowed + " allowed · " + t.held + " held · " + t.blocked + " blocked"
  }
  readonly property string barTooltip: {
    if (!svc.pmgAvailable) return "PMG not available on PATH"
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
    text: ""
    slotSize: Style.bar.statusSlot
    fontSize: Style.font.caption
    useActiveColor: false
    foreground: root.severityColor(svc.severity)
    tooltipText: root.barTooltip
    onPressed: function (buttonCode) {
      if (buttonCode === Qt.RightButton) root.runDoctor()
      else root.toggle()
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
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: label
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
    }
    Text {
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
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

      Flickable {
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
            title: root.heroTitle
            meta: svc.version !== "" ? "PMG " + svc.version : "PMG"
            detail: root.heroDetail
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconComponent: Component {
              Text {
                text: ""
                color: root.severityColor(svc.severity)
                font.family: root.fontFamily
                font.pixelSize: Style.font.display
              }
            }
          }

          // ---- Protection layers ----
          Column {
            width: parent.width
            spacing: Style.space(2)
            visible: svc.layers !== null

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
              value: svc.layers && svc.layers.ca && svc.layers.ca.trusted
                ? "trusted (" + svc.layers.ca.scope + ")" : "not trusted"
              valueColor: svc.layers && svc.layers.ca && svc.layers.ca.trusted ? root.cAllow : root.dim
            }
            LayerRow {
              label: "Persistent proxy"
              value: svc.layers && svc.layers.proxy && svc.layers.proxy.running
                ? svc.layers.proxy.addr : "off"
              valueColor: svc.layers && svc.layers.proxy && svc.layers.proxy.running ? root.cAllow : root.dim
            }
          }

          // ---- Today ----
          Column {
            width: parent.width
            spacing: Style.space(6)

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

          // ---- Recent activity ----
          Column {
            width: parent.width
            spacing: Style.space(2)

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
                    text: modelData.verdict + (modelData.ecosystem !== "" ? " · " + modelData.ecosystem : "")
                    color: root.rowColor(modelData.severity)
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                  }
                }
              }
            }
          }

          // ---- Actions ----
          Column {
            width: parent.width
            spacing: Style.space(6)

            ActionButton {
              label: "Run pmg setup install"
              visible: svc.needsSetup
              onClicked: root.runSetup()
            }
            ActionButton {
              label: "Run doctor"
              onClicked: root.runDoctor()
            }
            ActionButton {
              label: "Open logs"
              onClicked: root.openLogs()
            }
          }
        }
      }
    }
  }
}
