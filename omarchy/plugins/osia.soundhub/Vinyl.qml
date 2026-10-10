import QtQuick
import QtQuick.Effects

// A turntable record with a tone arm.
//   - spins at 33⅓ rpm on the render thread (RotationAnimator) while playing,
//     coasts down when paused
//   - the arm drops onto the outer groove on play and tracks inward with
//     `progress` (0..1), lifts back on pause
//   - the light sheen does not rotate, like a real lamp over a real record
// Pressings: classic, theme (accent-tinted), picture (art as the disc),
// clear, gold.
Item {
  id: root

  property real size: 200                 // record diameter
  property string artUrl: ""
  property bool playing: false
  property real progress: 0
  property string pressing: "classic"
  property bool showArm: true
  property color accent: "#7daea3"
  property color fg: "#d4be98"
  property color bg: "#282828"

  implicitWidth: showArm ? size * 1.22 : size
  implicitHeight: size

  readonly property bool hasArt: artUrl !== "" && art.status === Image.Ready
  readonly property color discColor: {
    switch (pressing) {
      case "theme": return Qt.darker(accent, 3.2)
      case "clear": return Qt.rgba(fg.r, fg.g, fg.b, 0.10)
      case "gold":  return "#b08d3c"
      default:      return "#121212"
    }
  }
  readonly property color grooveColor: pressing === "gold" ? Qt.rgba(0, 0, 0, 0.18)
                                      : pressing === "clear" ? Qt.rgba(fg.r, fg.g, fg.b, 0.18)
                                      : Qt.rgba(1, 1, 1, 0.07)

  // ---- the record (rotates) ----
  Item {
    id: disc
    width: root.size
    height: root.size

    // base disc, or the art itself for a picture disc
    Rectangle {
      anchors.fill: parent
      radius: width / 2
      color: root.discColor
      border.width: 1
      border.color: Qt.rgba(0, 0, 0, 0.5)
      visible: !(root.pressing === "picture" && root.hasArt)
    }

    Item {
      id: pictureDisc
      anchors.fill: parent
      visible: root.pressing === "picture" && root.hasArt
      layer.enabled: visible
      layer.effect: MultiEffect {
        maskEnabled: true
        maskSource: fullMask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
      }
      Image {
        anchors.fill: parent
        source: root.artUrl
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize: Qt.size(root.size, root.size)
      }
    }

    // grooves: painted once per size/colour, then just rotated as a texture
    Canvas {
      id: grooves
      anchors.fill: parent
      renderStrategy: Canvas.Cooperative
      onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        var c = width / 2
        ctx.lineWidth = 1
        for (var r = c * 0.40; r < c * 0.97; r += 2.2) {
          ctx.strokeStyle = (Math.round(r) % 9 === 0) ? Qt.rgba(1, 1, 1, 0.11) : root.grooveColor
          ctx.beginPath()
          ctx.arc(c, c, r, 0, Math.PI * 2)
          ctx.stroke()
        }
        // lead-out gap and a couple of track gaps
        ctx.strokeStyle = Qt.rgba(0, 0, 0, 0.35)
        ctx.lineWidth = 2
        var gaps = [0.55, 0.72, 0.86]
        for (var i = 0; i < gaps.length; i++) {
          ctx.beginPath(); ctx.arc(c, c, c * gaps[i], 0, Math.PI * 2); ctx.stroke()
        }
      }
      onWidthChanged: requestPaint()
      Connections {
        target: root
        function onGrooveColorChanged() { grooves.requestPaint() }
      }
    }

    // centre label: album art (or accent) in a circle
    Item {
      id: label
      width: root.size * 0.36
      height: width
      anchors.centerIn: parent
      visible: root.pressing !== "picture" || !root.hasArt
      layer.enabled: true
      layer.effect: MultiEffect {
        maskEnabled: true
        maskSource: labelMask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
      }
      Rectangle { anchors.fill: parent; color: root.accent }
      Image {
        id: art
        anchors.fill: parent
        source: root.artUrl
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize: Qt.size(root.size, root.size)
      }
    }

    // spindle hole
    Rectangle {
      width: Math.max(4, root.size * 0.03)
      height: width
      radius: width / 2
      anchors.centerIn: parent
      color: root.bg
      border.width: 1
      border.color: Qt.rgba(0, 0, 0, 0.6)
    }

    RotationAnimator {
      id: spin
      target: disc
      from: disc.rotation
      to: disc.rotation + 360
      duration: 1800                      // 33⅓ rpm
      loops: Animation.Infinite
      running: root.playing && root.visible
    }

    NumberAnimation {
      id: coast
      target: disc
      property: "rotation"
      to: disc.rotation + 70
      duration: 900
      easing.type: Easing.OutQuad
    }
  }

  Connections {
    target: root
    function onPlayingChanged() { if (!root.playing) coast.restart(); else coast.stop() }
  }

  // masks (hidden, only sampled by the effects)
  Rectangle { id: fullMask; width: root.size; height: width; radius: width / 2; visible: false; layer.enabled: true }
  Rectangle { id: labelMask; width: label.width; height: width; radius: width / 2; visible: false; layer.enabled: true }

  // ---- static light sheen ----
  Rectangle {
    width: root.size
    height: root.size
    radius: width / 2
    color: "transparent"
    gradient: Gradient {
      orientation: Gradient.Horizontal
      GradientStop { position: 0.0;  color: Qt.rgba(1, 1, 1, 0.00) }
      GradientStop { position: 0.42; color: Qt.rgba(1, 1, 1, 0.00) }
      GradientStop { position: 0.50; color: Qt.rgba(1, 1, 1, root.pressing === "clear" ? 0.05 : 0.08) }
      GradientStop { position: 0.58; color: Qt.rgba(1, 1, 1, 0.00) }
      GradientStop { position: 1.0;  color: Qt.rgba(1, 1, 1, 0.00) }
    }
    rotation: -35
  }

  // ---- tone arm ----
  Item {
    id: arm
    visible: root.showArm
    // pivot sits right of the record, a little below its top edge
    x: root.size * 1.06
    y: root.size * 0.10
    width: 1
    height: 1

    // resting off the record; on play: outer groove → inner groove with progress
    readonly property real restAngle: -4
    readonly property real outerAngle: 20
    readonly property real innerAngle: 34
    rotation: root.playing ? outerAngle + (innerAngle - outerAngle) * Math.max(0, Math.min(1, root.progress))
                           : restAngle
    Behavior on rotation { SpringAnimation { spring: 2.2; damping: 0.32; epsilon: 0.05 } }

    // base
    Rectangle {
      width: root.size * 0.13; height: width; radius: width / 2
      x: -width / 2; y: -width / 2
      color: Qt.lighter(root.bg, 1.6)
      border.width: 1; border.color: Qt.rgba(0, 0, 0, 0.5)
      Rectangle {
        width: parent.width * 0.45; height: width; radius: width / 2
        anchors.centerIn: parent
        color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.55)
      }
    }
    // arm tube
    Rectangle {
      id: tube
      width: Math.max(3, root.size * 0.022)
      height: root.size * 0.74
      x: -width / 2
      y: 0
      radius: width / 2
      color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.80)
    }
    // headshell
    Rectangle {
      width: root.size * 0.06
      height: root.size * 0.10
      x: -width / 2 - root.size * 0.012
      y: tube.height - height * 0.35
      radius: 2
      rotation: 18
      color: root.accent
    }
  }
}
