import QtQuick
import Quickshell.Io

// omasteam service plugin. The Millennium theme's colours are produced by the
// hook Omarchy runs on every theme change, so nothing to do per switch. This
// only runs the idempotent installer once at shell startup — re-plants the
// template + hook after `omarchy update` and re-seeds the Millennium theme dir.
Item {
  id: root

  property var shell: null
  property var manifest: null

  readonly property string pluginDir: {
    if (manifest && manifest.__sourceDir) return String(manifest.__sourceDir)
    var here = String(Qt.resolvedUrl("."))
    if (here.startsWith("file://")) here = here.substring(7)
    if (here.endsWith("/")) here = here.slice(0, -1)
    return decodeURIComponent(here)
  }

  property string lastError: ""

  Process {
    id: installer
    command: ["bash", root.pluginDir + "/install.sh"]
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var m = String(text || "").trim()
        if (m.length > 0) root.lastError = m.length > 400 ? m.slice(-400) : m
      }
    }
    onExited: function(code) {
      if (code !== 0)
        console.warn("omasteam: installer exited " + code + (root.lastError ? ": " + root.lastError : ""))
    }
  }

  Timer {
    interval: 2500
    running: true
    repeat: false
    onTriggered: if (!installer.running) { root.lastError = ""; installer.running = true }
  }
}
