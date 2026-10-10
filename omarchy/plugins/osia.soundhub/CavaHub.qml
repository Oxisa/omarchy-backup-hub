pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import "Model.js" as Model

// One cava capture for the whole shell (a singleton): every bar — one per
// monitor — and the panel read the same `levels`. Bars declare demand with
// want(key, on); cava runs while anyone wants it. It runs only while `active`, so a silent desktop costs
// nothing; frames are parsed into a plain array the views bind to.
// It listens to the *physical* output (omarchy-audio-output-sink resolves
// through the EQ) via cava's native pipewire input, pinned with PIPEWIRE_PROPS.
// The default sink would be silent when apps go through a mixer mix straight
// to the device, and the pulse path got moved onto the EQ's near-silent monitor.
Item {
  id: root
  visible: false

  property var demands: ({})
  readonly property bool active: Object.keys(demands).length > 0
  function want(key, on) {
    var d = Object.assign({}, demands)
    if (on) d[key] = true; else delete d[key]
    demands = d
  }
  property int bars: 32
  property int framerate: 40
  property var levels: Model.zeros(bars)

  readonly property string configPath:
    (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/osia-soundhub-cava.conf"

  property int failures: 0
  property string source: ""              // physical sink node name (pipewire input)

  function start() {
    if (proc.running || !active) return
    // cava's pipewire input doesn't mark its stream as capturing a sink, so
    // WirePlumber would hand it the default *microphone*. PIPEWIRE_PROPS adds
    // the flags: capture the sink's monitor, and never move elsewhere.
    proc.command = ["sh", "-c", 'printf "%s" "$1" > "$2" && PIPEWIRE_PROPS="$3" exec cava -p "$2"', "cava",
                    Model.cavaConfig(bars, framerate, source), configPath,
                    source ? "{ stream.capture.sink = true node.dont-reconnect = true }" : ""]
    proc.running = true
  }

  // follow the output: re-resolve when the default sink changes or we start
  readonly property var defaultSink: Pipewire.defaultAudioSink
  onDefaultSinkChanged: resolveTimer.restart()
  // devices coming and going (headphones unplugged / reconnected) too
  readonly property int sinkCount: {
    var n = Pipewire.nodes ? Pipewire.nodes.values : [], c = 0
    for (var i = 0; i < n.length; i++) if (n[i] && n[i].isSink && !n[i].isStream) c++
    return c
  }
  onSinkCountChanged: resolveTimer.restart()
  Timer { id: resolveTimer; interval: 400; onTriggered: if (!resolver.running) resolver.running = true }
  Process {
    id: resolver
    command: ["omarchy-audio-output-sink"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var sink = String(text).trim()
        var src = sink
        if (src !== root.source) {
          root.source = src
          root.failures = 0
          if (proc.running) { root.stop(); Qt.callLater(root.start) }
        }
        // cava may have given up while its device was gone: bring it back
        if (root.active && !proc.running) { root.failures = 0; Qt.callLater(root.start) }
      }
    }
  }

  function stop() {
    retry.stop()
    if (proc.running) proc.running = false
    levels = Model.zeros(bars)
  }

  onActiveChanged: { if (active) { resolveTimer.restart(); start() } else stop() }
  Component.onCompleted: resolveTimer.restart()
  onBarsChanged: { stop(); if (active) Qt.callLater(start) }

  Process {
    id: proc
    stdout: SplitParser {
      onRead: function(line) {
        var f = Model.parseFrame(line, root.bars)
        if (f) { root.levels = f; root.failures = 0 }
      }
    }
    stderr: StdioCollector { waitForEnd: true }
    onExited: function(code) {
      root.levels = Model.zeros(root.bars)
      // cava exits when the audio server restarts or the sink goes away;
      // come back with a growing delay, give up after a few tries.
      if (root.active && root.failures < 6) {
        root.failures += 1
        retry.interval = 500 * root.failures
        retry.restart()
      }
    }
  }

  Timer { id: retry; onTriggered: root.start() }
}
