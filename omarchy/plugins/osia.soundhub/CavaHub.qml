pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import "Model.js" as Model

// One cava capture for the whole shell (a singleton): every bar — one per
// monitor — and the panel read the same `levels`. Bars declare demand with
// want(key, on); cava runs while anyone wants it.
// cava runs as node "soundhub_cava" with autoconnect off; bin/soundhub-tap
// links the monitor of every device that is playing into it (headphones and
// speakers alike — mixes can send sound to several devices at once), and is
// re-run as the graph changes. Letting cava/WirePlumber pick one source went
// wrong three ways: the default sink (silent when mixes bypass it), the EQ's
// near-silent monitor, and the default microphone.
Item {
  id: root
  visible: false

  property var demands: ({})
  // One track-change notice per track, not one per bar (there is a bar on
  // every monitor): the first bar to see a new track claims it here.
  property string lastNoticeTrack: ""
  function claimNotice(sig) { if (!sig || sig === lastNoticeTrack) return false; lastNoticeTrack = sig; return true }

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

  function start() {
    if (proc.running || !active) return
    proc.command = ["sh", "-c", 'printf "%s" "$1" > "$2" && PIPEWIRE_PROPS="$3" exec cava -p "$2"', "cava",
                    Model.cavaConfig(bars, framerate), configPath,
                    "{ node.name = soundhub_cava node.autoconnect = false stream.capture.sink = true }"]
    proc.running = true
  }

  // feed cava from every playing device; re-run as things change
  readonly property string tapBin: decodeURIComponent(Qt.resolvedUrl("bin/soundhub-tap").toString().replace(/^file:\/\//, ""))
  function tapNow() { if (active && !tap.running) tap.running = true }
  Process { id: tap; command: [root.tapBin] }
  readonly property int sinkCount: {
    var n = Pipewire.nodes ? Pipewire.nodes.values : [], c = 0
    for (var i = 0; i < n.length; i++) if (n[i] && n[i].isSink) c++
    return c
  }
  onSinkCountChanged: tapSoon.restart()
  Timer { id: tapSoon; interval: 600; onTriggered: root.tapNow() }
  Timer { interval: 2000; repeat: true; running: root.active; onTriggered: root.tapNow() }

  function stop() {
    retry.stop()
    if (proc.running) proc.running = false
    levels = Model.zeros(bars)
  }

  onActiveChanged: { if (active) { start(); tapSoon.restart() } else stop() }
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
