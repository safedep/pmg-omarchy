import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Ui

// Fullscreen alert raised the moment PMG blocks a malicious package. Modeled on
// the built-in Reminders overlay: a scrimmed Wayland overlay layer with a
// centered card and exclusive keyboard focus. Setting blockEvent shows it;
// dismissing emits dismissed() so the service can clear its pending block.
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
  readonly property string eco: shown && blockEvent.ecosystem ? blockEvent.ecosystem : ""
  readonly property string reason: shown && blockEvent.message
    ? blockEvent.message
    : "A malicious package was blocked before any install script could run."

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

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: ""
          color: overlay.danger
          font.family: overlay.fontFamily
          font.pixelSize: Style.font.displayLarge
        }
        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: "Malware blocked"
          color: overlay.danger
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
        Text {
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          wrapMode: Text.WordWrap
          text: overlay.reason + (overlay.eco ? " · " + overlay.eco : "")
          color: Qt.darker(Color.menu.text, 1.2)
          font.family: overlay.fontFamily
          font.pixelSize: Style.font.body
        }
        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: "Install aborted — nothing executed"
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
