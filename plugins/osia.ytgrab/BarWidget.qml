import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Video Grabber — a download button in the bar. Click to open the
// paste-preview-download panel; right-click opens it prefilled from the
// clipboard. The nested Panel owns the flow; this widget owns the button and
// the bar lifecycle contract (opened / open / close / popout helpers), like
// the built-in clock and OmaVideos.
BarWidget {
  id: root
  moduleName: "osia.ytgrab"

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  function open()        { if (panelLoader.item) panelLoader.item.open() }
  function close()       { if (panelLoader.item) panelLoader.item.close() }
  function togglePanel() { if (panelLoader.item) panelLoader.item.toggle() }
  function pasteFromClipboard() { open(); if (panelLoader.item) panelLoader.item.pasteFromClipboard() }
  function openFolder()  { if (panelLoader.item) panelLoader.item.openFolder() }

  // popout coordination, mirroring the clock / OmaVideos
  readonly property real openPanelIndicatorWidth: Style.bar.iconCanvas
  readonly property real openPanelIndicatorHeight: Math.max(Style.space(10), Math.round(Style.bar.iconSlot * 0.55))
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch() }

  readonly property bool busy: panelLoader.item ? panelLoader.item.running === true : false

  function injectPanel() {
    var t = panelLoader.item
    if (!t) return
    if ("bar" in t) t.bar = root.bar
    if ("settings" in t) t.settings = root.settings
    if ("anchorItem" in t) t.anchorItem = button
    if ("hostWidget" in t) t.hostWidget = root
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: { root.injectPanel(); Qt.callLater(root.injectPanel) }
  }

  IpcHandler {
    target: "osia.ytgrab"
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.togglePanel() }
    function paste(): void { root.pasteFromClipboard() }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    hasVisualContent: true
    tooltipText: "Video Grabber — скачать ролик"

    Text {
      anchors.centerIn: parent
      text: "󰇚"
      color: root.busy ? Color.accent : button.foreground
      font.family: root.bar ? root.bar.fontFamily : Style.font.family
      font.pixelSize: Style.bar.iconFont

      SequentialAnimation on opacity {
        running: root.busy
        loops: Animation.Infinite
        NumberAnimation { from: 1.0; to: 0.35; duration: 650; easing.type: Easing.InOutQuad }
        NumberAnimation { from: 0.35; to: 1.0; duration: 650; easing.type: Easing.InOutQuad }
      }
    }

    onPressed: function(b) {
      if (b === Qt.RightButton) root.pasteFromClipboard()
      else if (b === Qt.MiddleButton) root.openFolder()
      else root.togglePanel()
    }
  }
}
