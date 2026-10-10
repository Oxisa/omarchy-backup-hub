import QtQuick

// Live spectrum.
//   style   bars | dots | beads | glow | spikes | steps | wave
//           ("mirror" is accepted as bars in mirror mode, for old settings)
//   mode    bottom | mirror | top
//   palette accent | foreground | muted | gradient | spectrum | cover
//           ("" = flat `color`/`colorTop` from the caller)
// Discrete styles are plain rectangles (cheap for the scene graph); the
// continuous ones (spikes, steps, wave) are one Canvas path per frame.
Item {
  id: root

  property var levels: []
  property string style: "bars"
  property string mode: "bottom"
  property string palette: ""
  property color color: "white"
  property color colorTop: color
  property color accent: color
  property color fg: "white"
  property var coverColors: []           // 1–3 colours taken from the album art
  property real gap: 2
  property real minLevel: 0.03
  property bool peaks: true

  readonly property string shape: style === "mirror" ? "bars" : style
  readonly property string dir: style === "mirror" ? "mirror" : mode
  readonly property int count: levels ? levels.length : 0
  readonly property real barWidth: count > 0 ? Math.max(1, (width - gap * (count - 1)) / count) : 0
  readonly property bool continuous: shape === "spikes" || shape === "steps" || shape === "wave"

  // falling peak caps
  property var peakLevels: []
  onLevelsChanged: {
    if (peaks && shape === "bars") {
      var p = peakLevels.length === count ? peakLevels.slice() : new Array(count).fill(0)
      for (var i = 0; i < count; i++) p[i] = Math.max(levels[i] || 0, (p[i] || 0) - 0.025)
      peakLevels = p
    }
    if (continuous) canvas.requestPaint()
  }

  function mix(a, b, t) {
    return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, a.a + (b.a - a.a) * t)
  }

  // colour of band i at level l
  function colorAt(i, l) {
    switch (palette) {
      case "accent":     return accent
      case "foreground": return fg
      case "muted":      return Qt.rgba(fg.r, fg.g, fg.b, 0.45)
      case "gradient":   return mix(Qt.rgba(accent.r, accent.g, accent.b, 0.55), fg, Math.min(1, l * 1.2))
      case "spectrum": {
        var h = accent.hslHue < 0 ? 0 : accent.hslHue
        return Qt.hsla((h + (count > 1 ? i / (count - 1) : 0) * 0.75) % 1, Math.max(0.45, accent.hslSaturation),
                       Math.min(0.68, Math.max(0.5, accent.hslLightness)), 1)
      }
      case "cover": {
        var cs = coverColors && coverColors.length ? coverColors : [accent]
        if (cs.length === 1) return cs[0]
        var t = count > 1 ? i / (count - 1) : 0
        var seg = t * (cs.length - 1), k = Math.min(cs.length - 2, Math.floor(seg))
        return mix(cs[k], cs[k + 1], seg - k)
      }
      default: return mix(color, colorTop, Math.min(1, l))
    }
  }

  // ---- discrete styles ----
  Repeater {
    model: root.continuous ? 0 : root.count

    delegate: Item {
      id: cell
      required property int index
      readonly property real level: Math.max(root.minLevel, root.levels[index] || 0)
      readonly property color tint: root.colorAt(index, level)
      x: index * (root.barWidth + root.gap)
      width: root.barWidth
      height: root.height

      readonly property real h: Math.max(1, level * root.height)
      readonly property real yTop: root.dir === "top" ? 0
                                 : root.dir === "mirror" ? (root.height - h) / 2
                                 : root.height - h

      // bars
      Rectangle {
        visible: root.shape === "bars"
        y: cell.yTop
        width: parent.width
        height: cell.h
        radius: Math.min(width / 2, 2)
        color: cell.tint
      }
      // peak cap
      Rectangle {
        visible: root.shape === "bars" && root.peaks && root.dir !== "mirror"
        readonly property real pk: root.peakLevels[cell.index] || 0
        width: parent.width
        height: Math.max(1, Math.round(root.height * 0.06))
        y: root.dir === "top" ? Math.min(root.height - height, pk * root.height)
                              : Math.max(0, root.height - pk * root.height - height)
        color: cell.tint
        opacity: 0.85
      }
      // beads: one disc riding the top of the bar
      Rectangle {
        visible: root.shape === "beads"
        width: Math.min(parent.width, root.height * 0.35)
        height: width
        radius: width / 2
        x: (parent.width - width) / 2
        y: Math.max(0, Math.min(root.height - height,
             root.dir === "top" ? cell.h - height / 2
             : root.dir === "mirror" ? (root.height - height) / 2 - (cell.level - root.minLevel) * root.height * 0.4
             : root.height - cell.h - height / 2))
        color: cell.tint
      }
      // glow: full-depth cell, level as brightness
      Rectangle {
        visible: root.shape === "glow"
        anchors.fill: parent
        radius: Math.min(width / 2, 2)
        color: cell.tint
        opacity: 0.12 + 0.88 * cell.level
      }
      // dots: LED ladder
      Column {
        visible: root.shape === "dots"
        width: parent.width
        spacing: Math.max(1, root.gap)
        readonly property real cellSize: Math.max(2, root.barWidth)
        readonly property int total: Math.max(2, Math.floor((root.height + spacing) / (cellSize + spacing)))
        readonly property int lit: Math.round(cell.level * total)
        Repeater {
          model: parent.total
          delegate: Rectangle {
            required property int index
            readonly property int fromEdge: root.dir === "top" ? index : parent.total - 1 - index
            readonly property bool on: root.dir === "mirror"
              ? Math.abs(index - (parent.total - 1) / 2) <= parent.lit / 2
              : fromEdge < parent.lit
            width: parent.cellSize; height: width
            radius: width / 2
            color: cell.tint
            opacity: on ? 1 : 0.12
          }
        }
      }
    }
  }

  // ---- continuous styles ----
  Canvas {
    id: canvas
    anchors.fill: parent
    visible: root.continuous
    renderStrategy: Canvas.Cooperative
    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      var n = root.count
      if (n < 2) return
      var W = width, H = height
      var lv = root.levels
      function yOf(l) {
        var h = Math.max(root.minLevel, l) * H
        return root.dir === "top" ? h : root.dir === "mirror" ? (H - h) / 2 : H - h
      }
      var base = root.dir === "top" ? 0 : root.dir === "mirror" ? H / 2 : H
      var step = W / n

      // the edge as points; wave is smoothed when drawn
      var pts = []
      if (root.shape === "steps") {
        for (var i = 0; i < n; i++) { var y = yOf(lv[i] || 0); pts.push([i * step, y]); pts.push([(i + 1) * step, y]) }
      } else if (root.shape === "spikes") {
        for (var j = 0; j < n; j++) { pts.push([(j + 0.5) * step, yOf(lv[j] || 0)]); pts.push([(j + 1) * step, base]) }
      } else {
        for (var k = 0; k < n; k++) pts.push([(k + 0.5) * step, yOf(lv[k] || 0)])
      }
      var smooth = root.shape === "wave"
      function edge(list, flip) {
        for (var e = 0; e < list.length; e++) {
          var q = list[e], qy = flip ? H - q[1] : q[1]
          if (smooth && e > 0) {
            var pr = list[e - 1], pry = flip ? H - pr[1] : pr[1], mx = (pr[0] + q[0]) / 2
            ctx.bezierCurveTo(mx, pry, mx, qy, q[0], qy)
          } else ctx.lineTo(q[0], qy)
        }
      }

      ctx.beginPath()
      ctx.moveTo(0, base)
      ctx.lineTo(0, smooth ? pts[0][1] : base)
      edge(pts, false)
      ctx.lineTo(W, smooth ? pts[pts.length - 1][1] : base)
      if (root.dir === "mirror") {
        var back = pts.slice().reverse()
        ctx.lineTo(W, smooth ? H - pts[pts.length - 1][1] : base)
        edge(back, true)
        ctx.lineTo(0, smooth ? H - pts[0][1] : base)
      } else {
        ctx.lineTo(W, base)
      }
      ctx.closePath()

      var grad = ctx.createLinearGradient(0, 0, W, 0)
      for (var s = 0; s <= 4; s++) {
        var idx = Math.round(s / 4 * (n - 1))
        grad.addColorStop(s / 4, root.colorAt(idx, lv[idx] || 0))
      }
      ctx.fillStyle = grad
      ctx.globalAlpha = 0.85
      ctx.fill()
    }
  }
}
