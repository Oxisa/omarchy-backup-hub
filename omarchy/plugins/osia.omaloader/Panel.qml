import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

// Omaloader in the bar: the engine (Engine.qml) plus its UI (Content.qml) in
// a keyboard panel. The bar widget (BarWidget.qml) owns the button.
// Downloads keep running while the panel is closed.
Panel {
  id: root
  moduleName: "osia.omaloader"
  ipcTarget: "osia.omaloader"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  Engine {
    id: engine
    settings: root.settings
    fg: root.bar ? root.bar.barForeground : Color.foreground
    ff: root.bar ? root.bar.fontFamily : Style.font.family
    urgent: root.bar ? root.bar.urgent : Color.urgent
    onPersistRequested: function(values) {
      var e = { id: root.moduleName }
      for (var k in root.settings) if (k !== "id") e[k] = root.settings[k]
      for (var key in values) e[key] = values[key]
      root.settings = e
      if (root.hostWidget && "settings" in root.hostWidget) root.hostWidget.settings = e
      if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
        root.bar.shell.updateEntryInline(root.moduleName, e)
    }
  }

  // what the bar widget reads / calls
  readonly property bool running: engine.running
  property alias tab: engine.tab
  function pasteFromClipboard() { engine.pasteFromClipboard() }
  function openFolder() { engine.openFolder() }

  function open() {
    controller.show()
    Qt.callLater(function() {
      if (!root.opened || engine.tab !== 0) return
      if (engine.opt("autoPaste", false) === true && !String(engine.url).trim()) engine.pasteFromClipboard()
      content.urlField.forceActiveFocus()
    })
  }
  function close() { controller.hide() }
  function toggle() { root.opened ? close() : open() }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: content.urlField
    contentWidth: panel.fittedContentWidth(Style.space(400))
    contentHeight: panel.fittedContentHeight(content.implicitHeight)

    Content {
      id: content
      host: engine
    }
  }
}
