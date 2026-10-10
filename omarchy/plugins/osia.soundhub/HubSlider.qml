import QtQuick
import qs.Commons

// SoundHub's slider: drag or click only — the mouse wheel is deliberately
// ignored so scrolling a list never changes a volume. Optionally shows its
// value (percent by default) to the right.
//   moved(v)     while dragging      released(v)  when let go
Item {
  id: root

  property real value: 0
  property real minimum: 0
  property real maximum: 1
  property real step: 0.01
  property color fillColor: Color.accent
  property color trackColor: Qt.rgba(Color.foreground.r, Color.foreground.g, Color.foreground.b, 0.14)
  property real trackHeight: 4
  property real knobSize: 12
  property bool showValue: true
  property string fontFamily: Style.font.family
  property var format: function(v) { return Math.round(v * 100) + "%" }

  signal moved(real value)
  signal released(real value)

  property bool dragging: false
  property real liveValue: value
  onValueChanged: if (!dragging) liveValue = value

  implicitHeight: Math.max(knobSize, label.implicitHeight) + 4
  implicitWidth: 120

  readonly property real labelW: showValue ? Style.space(40) : 0
  readonly property real trackW: Math.max(10, width - labelW)
  readonly property real ratio: Math.max(0, Math.min(1, (liveValue - minimum) / Math.max(0.0001, maximum - minimum)))

  function valueAt(x) {
    var r = Math.max(0, Math.min(1, (x - knobSize / 2) / Math.max(1, trackW - knobSize)))
    var v = minimum + r * (maximum - minimum)
    return Math.round(v / step) * step
  }

  Rectangle {
    id: track
    x: root.knobSize / 2
    width: root.trackW - root.knobSize
    height: root.trackHeight
    radius: height / 2
    anchors.verticalCenter: parent.verticalCenter
    color: root.trackColor
    Rectangle {
      width: parent.width * root.ratio
      height: parent.height
      radius: height / 2
      color: root.fillColor
    }
  }

  Rectangle {
    id: knob
    width: root.knobSize * (mouse.containsMouse || root.dragging ? 1.25 : 1)
    height: width
    radius: width / 2
    x: track.x + track.width * root.ratio - width / 2
    anchors.verticalCenter: parent.verticalCenter
    color: root.fillColor
    Behavior on width { NumberAnimation { duration: 100 } }
  }

  Text {
    id: label
    visible: root.showValue
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    width: root.labelW
    horizontalAlignment: Text.AlignRight
    text: root.format(root.liveValue)
    color: Qt.darker(Color.foreground, 1.25)
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
  }

  MouseArea {
    id: mouse
    x: 0
    width: root.trackW
    height: parent.height
    anchors.verticalCenter: parent.verticalCenter
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    preventStealing: true
    // no onWheel: the wheel scrolls whatever list this slider sits in
    onPressed: function(m) { root.dragging = true; root.liveValue = root.valueAt(m.x); root.moved(root.liveValue) }
    onPositionChanged: function(m) { if (root.dragging) { root.liveValue = root.valueAt(m.x); root.moved(root.liveValue) } }
    onReleased: { root.dragging = false; root.released(root.liveValue) }
  }
}
