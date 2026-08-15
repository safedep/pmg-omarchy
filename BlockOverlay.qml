import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "PmgModel.js" as PmgModel

// Fullscreen alert for a blocked package. It uses the Reminders overlay pattern:
// a scrimmed Wayland layer with a centered card and exclusive focus. Set
// blockEvent to show it. Dismiss emits dismissed().
PanelWindow {
  id: overlay

  property var blockEvent: null
  signal dismissed()

  readonly property bool shown: blockEvent !== null && blockEvent !== undefined
  readonly property color danger: "#f7768e"
  readonly property string fontFamily: Style.font.family

  readonly property string pkg: shown
    ? (blockEvent.package_name || "unknown") + (blockEvent.version ? "@" + blockEvent.version : "")
    : ""
  readonly property string eco: shown ? PmgModel.humanizeEcosystem(blockEvent.ecosystem) : ""

  visible: shown
  anchors { top: true; bottom: true; left: true; right: true }
  color: "transparent"
  WlrLayershell.namespace: "pmg-block"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
  exclusionMode: ExclusionMode.Ignore

  function dismiss() {
    overlay.dismissed()
  }

  onShownChanged: if (shown) Qt.callLater(function () { keyCatcher.forceActiveFocus() })

  Rectangle {
    anchors.fill: parent
    color: Color.menu.scrim
  }

  MouseArea {
    anchors.fill: parent
    onClicked: overlay.dismiss()
  }

  BorderSurface {
    id: cardSurface
    width: Math.min(Style.space(420), overlay.width - Style.gapsOut * 4)
    height: card.implicitHeight + Style.spacing.panelPadding * 2
    anchors.centerIn: parent
    radius: Style.cornerRadius
    color: Color.menu.background
    borderSpec: Border.surfaceSpec("menu", "border", overlay.danger, Math.max(1, Style.space(2)))
    padding: Style.spacing.panelPadding

    // Swallow clicks on the card so only the backdrop dismisses.
    MouseArea { anchors.fill: parent; onClicked: {} }

    Item {
      id: keyCatcher
      anchors.fill: parent
      focus: overlay.shown
      Keys.priority: Keys.BeforeItem
      Keys.onPressed: function (event) {
        if (event.key === Qt.Key_Escape || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
          overlay.dismiss()
          event.accepted = true
        }
      }

      Column {
        id: card
        anchors.centerIn: parent
        width: keyCatcher.width - Style.spacing.panelPadding * 2
        spacing: Style.spacing.sm

        Rectangle {
          anchors.horizontalCenter: parent.horizontalCenter
          width: Style.space(54)
          height: Style.space(54)
          radius: width / 2
          color: Qt.rgba(overlay.danger.r, overlay.danger.g, overlay.danger.b, 0.14)
          border.width: 1
          border.color: overlay.danger
          Text {
            anchors.centerIn: parent
            text: ""
            color: overlay.danger
            font.family: overlay.fontFamily
            font.pixelSize: Style.font.display
          }
        }
        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: "BLOCKED BY PMG"
          color: overlay.danger
          font.family: overlay.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
          font.letterSpacing: 2
        }
        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: "Malicious package stopped"
          color: Color.menu.text
          font.bold: true
          font.family: overlay.fontFamily
          font.pixelSize: Style.font.heading
        }
        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: overlay.pkg
          color: Color.menu.text
          font.family: overlay.fontFamily
          font.pixelSize: Style.font.title
        }
        Rectangle {
          visible: overlay.eco !== ""
          anchors.horizontalCenter: parent.horizontalCenter
          implicitWidth: ecoText.implicitWidth + Style.space(14)
          implicitHeight: ecoText.implicitHeight + Style.space(5)
          radius: Style.space(4)
          color: "transparent"
          border.width: 1
          border.color: Qt.darker(Color.menu.text, 1.9)
          Text {
            id: ecoText
            anchors.centerIn: parent
            text: overlay.eco
            color: Qt.darker(Color.menu.text, 1.2)
            font.family: overlay.fontFamily
            font.pixelSize: Style.font.caption
          }
        }
        Text {
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          wrapMode: Text.WordWrap
          text: "PMG blocked this install before any code could run."
          color: Qt.darker(Color.menu.text, 1.3)
          font.family: overlay.fontFamily
          font.pixelSize: Style.font.body
        }
        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: "Nothing was executed"
          color: overlay.danger
          font.family: overlay.fontFamily
          font.pixelSize: Style.font.bodySmall
        }
        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: "Press Esc or click to dismiss"
          color: Qt.darker(Color.menu.text, 1.6)
          font.family: overlay.fontFamily
          font.pixelSize: Style.font.caption
        }
      }
    }
  }
}
