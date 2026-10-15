import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// NanoKVM — a bar button for NanoKVM-USB offline. Click opens the KVM window
// (starting the nanokvm-usb package's local server first) or focuses it;
// right-click closes it, which stops the server. bin/nanokvm does the work.
// Hidden while the package is not installed.
BarWidget {
  id: root
  moduleName: "osia.nanokvm"

  readonly property string bin: decodeURIComponent(Qt.resolvedUrl("bin/nanokvm").toString().replace(/^file:\/\//, ""))
  property var st: ({ installed: false, server: false, window: false })

  function refresh() { if (!statusProc.running) statusProc.running = true }
  function run(action) {
    actionProc.command = [bin, action]
    actionProc.running = true
  }

  visible: st.installed
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Process {
    id: statusProc
    command: [root.bin, "status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: { try { root.st = JSON.parse(text) } catch (e) {} }
    }
  }
  Process {
    id: actionProc
    onExited: root.refresh()
  }
  Timer { interval: 4000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.refresh() }

  IpcHandler {
    target: "osia.nanokvm"
    function open(): void { root.run("open") }
    function toggle(): void { root.run("toggle") }
    function stop(): void { root.run("stop") }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    hasVisualContent: true
    tooltipText: root.st.window ? "NanoKVM: open (right-click closes)" : "NanoKVM"

    Text {
      anchors.centerIn: parent
      text: "󰍹"
      color: root.st.window || actionProc.running ? Color.accent : button.foreground
      font.family: root.bar ? root.bar.fontFamily : Style.font.family
      font.pixelSize: Style.bar.iconFont
    }

    onPressed: function(b) {
      if (b === Qt.RightButton) root.run("stop")
      else root.run("open")
    }
  }
}
