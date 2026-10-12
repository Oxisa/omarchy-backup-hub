import QtQuick
import Quickshell.Io

// omatele service plugin.
//
// The palette is produced by the hook Omarchy runs on every theme change, so
// there is nothing to do per switch. This component's only job is to run the
// idempotent installer once when the shell comes up — that re-plants the
// template + hook after an `omarchy update` and picks up Telegram if it was
// installed after the plugin.
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
        console.warn("omatele: installer exited " + code + (root.lastError ? ": " + root.lastError : ""))
    }
  }

  Timer {
    interval: 2500
    running: true
    repeat: false
    onTriggered: if (!installer.running) { root.lastError = ""; installer.running = true }
  }
}
