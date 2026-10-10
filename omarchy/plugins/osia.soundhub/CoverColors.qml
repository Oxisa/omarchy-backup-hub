import QtQuick

// Picks up to three colours from the album art for the "cover" palette.
// The art is drawn into a tiny hidden canvas (24×24) and sampled: the most
// saturated pixels in three horizontal slices, so a gradient across the
// spectrum roughly follows the cover. Falls back to [] (callers use accent).
Item {
  id: root
  visible: false
  width: 24
  height: 24

  property string source: ""
  property var colors: []

  onSourceChanged: {
    colors = []
    if (!source) return
    if (canvas.isImageLoaded(source)) canvas.requestPaint()
    else canvas.loadImage(source)
  }

  Canvas {
    id: canvas
    width: 24
    height: 24
    renderStrategy: Canvas.Immediate
    renderTarget: Canvas.Image
    onImageLoaded: requestPaint()
    onPaint: {
      if (!root.source || !isImageLoaded(root.source)) return
      var ctx = getContext("2d")
      ctx.clearRect(0, 0, width, height)
      ctx.drawImage(root.source, 0, 0, width, height)
      var data
      try { data = ctx.getImageData(0, 0, width, height).data } catch (e) { return }
      var out = []
      for (var band = 0; band < 3; band++) {
        var best = null, bestScore = -1
        for (var y = 0; y < height; y++) {
          for (var x = band * 8; x < band * 8 + 8; x++) {
            var o = (y * width + x) * 4
            var r = data[o] / 255, g = data[o + 1] / 255, b = data[o + 2] / 255
            var mx = Math.max(r, g, b), mn = Math.min(r, g, b)
            var l = (mx + mn) / 2
            var s = mx === mn ? 0 : (l > 0.5 ? (mx - mn) / (2 - mx - mn) : (mx - mn) / (mx + mn))
            // saturated and neither near-black nor near-white
            var score = s * (1 - Math.abs(l - 0.55) * 1.6)
            if (score > bestScore) { bestScore = score; best = Qt.rgba(r, g, b, 1) }
          }
        }
        if (best) out.push(best)
      }
      root.colors = out
    }
  }
}
