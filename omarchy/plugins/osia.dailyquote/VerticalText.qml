import QtQuick

// Text set vertically, the way Chinese and Japanese are written: every
// character upright, columns running top to bottom and following one
// another from right to left. Latin or Cyrillic text is stacked the same
// way, wrapping between columns at spaces where it can.
Row {
  id: root
  property string text: ""
  property string fontFamily: ""
  property real pixelSize: 24
  property color color: "white"
  property color styleColor: "transparent"
  property bool italic: false
  property real maxHeight: 600               // a column is at most this tall

  layoutDirection: Qt.RightToLeft
  spacing: Math.round(pixelSize * 0.35)

  readonly property real cell: Math.round(pixelSize * 1.12)
  readonly property int perColumn: Math.max(4, Math.floor(maxHeight / cell))

  // split into columns: whole words where they fit, long words / CJK runs broken
  readonly property var columns: {
    var chars = Array.from(String(text || "").trim())
    var cols = [], cur = []
    var words = [], w = []
    for (var i = 0; i < chars.length; i++) {
      if (chars[i] === " ") { if (w.length) words.push(w); w = []; words.push([" "]) }
      else w.push(chars[i])
    }
    if (w.length) words.push(w)
    for (var j = 0; j < words.length; j++) {
      var word = words[j]
      if (word[0] === " ") { if (cur.length && cur.length < perColumn) cur.push(" "); continue }
      if (cur.length + word.length > perColumn && cur.length) {
        while (cur.length && cur[cur.length - 1] === " ") cur.pop()
        cols.push(cur); cur = []
      }
      for (var k = 0; k < word.length; k++) {
        if (cur.length >= perColumn) { cols.push(cur); cur = [] }
        cur.push(word[k])
      }
    }
    while (cur.length && cur[cur.length - 1] === " ") cur.pop()
    if (cur.length) cols.push(cur)
    return cols
  }

  Repeater {
    model: root.columns
    delegate: Column {
      required property var modelData
      Repeater {
        model: parent.modelData
        delegate: Text {
          required property string modelData
          width: root.cell
          height: modelData === " " ? root.cell * 0.5 : root.cell
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
          textFormat: Text.PlainText
          text: modelData === " " ? "" : modelData
          color: root.color
          font.family: root.fontFamily
          font.pixelSize: root.pixelSize
          font.italic: root.italic
          style: Text.Raised
          styleColor: root.styleColor
        }
      }
    }
  }
}
