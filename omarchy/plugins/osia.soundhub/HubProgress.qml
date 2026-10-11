import QtQuick
import qs.Commons
import "Model.js" as Model

// Track progress in one of three looks, with click/drag to seek:
//   squiggle  the played part is a sine wave that flows while playing,
//             the rest a straight line (Android-style)
//   wave      per-track pseudo-waveform bars, played part filled
//   line      a thin bar with a knob
// When the length is unknown (some browser players never say), the bar
// doesn't sit still: a short segment runs back and forth while playing.
//   seekTo(ratio)   on release, when seeking is possible
Item {
  id: root
  property real progress: 0                // 0..1
  property bool known: true                // length is known
  property bool playing: false
  property bool canSeek: false
  property string look: "squiggle"         // squiggle | wave | line
  property string seed: ""                 // track id, for the wave's shape
  property color fg: "white"
  property color accent: "white"
  signal seekTo(real ratio)

  implicitHeight: Style.space(26)

  property bool dragging: false
  property real dragRatio: 0
  readonly property real shown: dragging ? dragRatio : Math.max(0, Math.min(1, progress))
  readonly property color dim: HubStyle.tint(fg, canSeek ? 0.22 : 0.14)

  // animation clock: squiggle phase, and the runner when the length is unknown
  property real phase: 0
  property real run: 0
  readonly property bool animating: visible && playing && (look === "squiggle" || !known)
  Timer {
    interval: 33; repeat: true; running: root.animating
    onTriggered: {
      root.phase = (root.phase + 0.22) % (Math.PI * 2)
      root.run = (root.run + 0.009) % 2
    }
  }
  // runner position 0..1 (ping-pong)
  readonly property real runPos: run < 1 ? run : 2 - run

  // ---------------------------------------------------------------- squiggle
  Canvas {
    id: squiggle
    anchors.fill: parent
    visible: root.look === "squiggle"
    renderStrategy: Canvas.Cooperative
    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      var w = width, h = height, mid = h / 2
      var amp = h * 0.16, len = Style.space(22)
      var k = Math.PI * 2 / len
      ctx.lineCap = "round"
      ctx.lineWidth = Style.space(3)
      function wavy(x0, x1, a) {
        ctx.beginPath()
        for (var x = x0; x <= x1; x += 1.5) {
          var y = mid + Math.sin(x * k - root.phase) * a
          if (x === x0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
        }
        ctx.stroke()
      }
      function flat(x0, x1) {
        if (x1 <= x0) return
        ctx.beginPath(); ctx.moveTo(x0, mid); ctx.lineTo(x1, mid); ctx.stroke()
      }
      var pad = ctx.lineWidth
      if (root.known) {
        var px = pad + (w - pad * 2) * root.shown
        ctx.strokeStyle = root.dim
        flat(px + Style.space(6), w - pad)
        ctx.strokeStyle = root.accent
        // calm down to a line while paused, flow while playing
        wavy(pad, px, root.playing || root.dragging ? amp : amp * 0.35)
        ctx.fillStyle = root.accent                 // knob: a short upright bar
        var kh = h * 0.62, kw = Style.space(4)
        ctx.beginPath()
        ctx.roundedRect(px - kw / 2, mid - kh / 2, kw, kh, kw / 2, kw / 2)
        ctx.fill()
      } else {
        ctx.strokeStyle = root.dim
        flat(pad, w - pad)
        var seg = (w - pad * 2) * 0.28
        var sx = pad + (w - pad * 2 - seg) * root.runPos
        ctx.strokeStyle = root.accent
        wavy(sx, sx + seg, root.playing ? amp : amp * 0.35)
      }
    }
    Connections {
      target: root
      function onPhaseChanged() { if (squiggle.visible) squiggle.requestPaint() }
      function onShownChanged() { if (squiggle.visible) squiggle.requestPaint() }
      function onPlayingChanged() { squiggle.requestPaint() }
      function onKnownChanged() { squiggle.requestPaint() }
      function onAccentChanged() { squiggle.requestPaint() }
    }
    onWidthChanged: requestPaint()
    onVisibleChanged: if (visible) requestPaint()
  }

  // -------------------------------------------------------------------- wave
  Item {
    id: wave
    anchors.fill: parent
    visible: root.look === "wave"
    readonly property real barW: Style.space(3)
    readonly property real gap: Style.space(2)
    readonly property int count: Math.max(8, Math.floor((width + gap) / (barW + gap)))
    readonly property var shape: Model.waveShape(root.seed, count)
    Repeater {
      model: wave.visible ? wave.count : 0
      delegate: Rectangle {
        required property int index
        readonly property real at: (index + 0.5) / wave.count
        readonly property bool lit: root.known ? at <= root.shown
                                    : Math.abs(at - (0.14 + root.runPos * 0.72)) < 0.14
        x: index * (wave.barW + wave.gap)
        width: wave.barW
        height: Math.max(wave.barW, wave.height * (wave.shape[index] || 0.3))
        anchors.verticalCenter: parent.verticalCenter
        radius: width / 2
        color: lit ? root.accent : root.dim
      }
    }
  }

  // -------------------------------------------------------------------- line
  Item {
    anchors.fill: parent
    visible: root.look === "line"
    Rectangle {
      id: lineTrack
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width; height: Style.space(4); radius: height / 2
      color: root.dim
      Rectangle {
        visible: root.known
        width: parent.width * root.shown; height: parent.height; radius: height / 2
        color: root.accent
      }
      Rectangle {                                   // runner when the length is unknown
        visible: !root.known
        width: parent.width * 0.25; height: parent.height; radius: height / 2
        x: (parent.width - width) * root.runPos
        color: root.accent
      }
    }
    Rectangle {
      visible: root.known && (root.canSeek && (seekMouse.containsMouse || root.dragging))
      width: Style.space(12); height: width; radius: width / 2
      x: lineTrack.width * root.shown - width / 2
      anchors.verticalCenter: parent.verticalCenter
      color: root.accent
    }
  }

  // ---------------------------------------------------------------- seeking
  MouseArea {
    id: seekMouse
    anchors.fill: parent
    anchors.topMargin: -Style.space(6); anchors.bottomMargin: -Style.space(6)
    enabled: root.canSeek && root.known
    hoverEnabled: true
    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    function ratioAt(x) { return Math.max(0, Math.min(1, x / width)) }
    onPressed: function(e) { root.dragging = true; root.dragRatio = ratioAt(e.x) }
    onPositionChanged: function(e) { if (root.dragging) root.dragRatio = ratioAt(e.x) }
    onReleased: { root.seekTo(root.dragRatio); root.dragging = false }
  }
}
