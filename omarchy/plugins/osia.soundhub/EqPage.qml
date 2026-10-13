import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Equalizer, in the same card style as Focus:
//   header card  big power button, status + target device, reset
//   curve card   response curve, six draggable bands, preamp (auto/manual)
//   presets      icon tiles
// Edits update the view at once and reach PipeWire through soundhub-eq after
// a short debounce, so dragging stays smooth.
Column {
  id: page
  property var host: null
  spacing: HubStyle.gap

  readonly property color fg: host ? host.fg : "white"
  readonly property color accent: host ? host.accent : "white"
  readonly property string ff: host ? host.ff : ""
  readonly property color bgc: host ? host.bgc : "black"
  // scope: "global" (the system EQ) or a mix id (that mix's own EQ modifier)
  readonly property string scope: host && host.eqScope ? host.eqScope : "global"
  readonly property bool isGlobal: scope === "global"
  property var mixes: []
  readonly property var scopeMix: { for (var i = 0; i < mixes.length; i++) if (mixes[i].id === scope) return mixes[i]; return null }
  readonly property var eq: isGlobal ? (host ? host.eq : ({})) : (scopeMix && scopeMix.eq ? scopeMix.eq : ({}))
  onMixesChanged: if (!isGlobal && !scopeMix && mixes.length >= 0 && mixLoaded) host.eqScope = "global"
  property bool mixLoaded: false

  // send a change to whichever EQ is in scope
  function mixCmd(args) { mixRun.queue = mixRun.queue.concat([[mixBin].concat(args)]); if (!mixRun.running) mixRun.next() }
  Process {
    id: mixRun
    property var queue: []
    function next() { if (!queue.length) { page.checkBypass(); return } command = queue[0]; queue = queue.slice(1); running = true }
    onExited: next()
  }
  readonly property bool eqOn: !!eq.enabled
  readonly property real radius: Math.max(6, Math.min(Style.cornerRadius, 12))
  readonly property color urgent: host ? host.urgent : "red"
  function t(k, a) { return host ? host.t(k, a) : k }

  // friendly name of the device the EQ feeds
  readonly property string targetLabel: {
    if (!isGlobal) {
      var o = scopeMix ? (scopeMix.output || "") : ""
      if (o === "soundhub_eq") return t("mx.viaEq", "").replace(/\s*→\s*$/, "")
      if (!o) return t("mx.virtual")
      var nn = Pipewire.nodes ? Pipewire.nodes.values : []
      for (var j = 0; j < nn.length; j++) if (nn[j] && String(nn[j].name) === o) return Model.nodeLabel(nn[j])
      return o
    }
    var name = String(eq.target || "")
    var nodes = Pipewire.nodes ? Pipewire.nodes.values : []
    for (var i = 0; i < nodes.length; i++)
      if (nodes[i] && String(nodes[i].name) === name) return Model.nodeLabel(nodes[i])
    return name || "—"
  }

  readonly property var presets: ({
    flat:       [0, 0, 0, 0, 0, 0],
    bass:       [6, 4, 0, 0, 0, 0],
    treble:     [0, 0, 0, 2, 4, 6],
    vocal:      [-2, 0, 3, 4, 2, 0],
    rock:       [4, 2, -1, 2, 4, 3],
    pop:        [-1, 2, 4, 3, 0, -1],
    electronic: [5, 3, 0, 1, 3, 4],
    jazz:       [3, 2, -1, 1, 2, 3],
    classical:  [4, 2, 0, 0, 2, 4],
    acoustic:   [3, 1, 1, 2, 2, 2]
  })
  readonly property var presetOrder: ["flat", "bass", "treble", "vocal", "rock", "pop", "electronic", "jazz", "classical", "acoustic"]
  readonly property var presetIcons: ({
    flat: "\u{f01fc}", bass: "\u{f0030}", treble: "\u{f0f70}", vocal: "\u{f05cb}", rock: "\u{f02c4}",
    pop: "\u{f0387}", electronic: "\u{f147d}", jazz: "\u{f0609}", classical: "\u{f060f}", acoustic: "\u{f0771}"
  })

  // local copy the sliders edit; refreshed from the backend when idle
  property var bands: eq.bands ? eq.bands.slice() : [0, 0, 0, 0, 0, 0]
  property string preset: eq.preset || "flat"
  property bool editing: false
  onEqChanged: if (!editing && eq.bands) { bands = eq.bands.slice(); preset = eq.preset || "flat" }

  function setBand(i, v) {
    var b = bands.slice(); b[i] = Math.round(v * 2) / 2; bands = b
    preset = "custom"
    editing = true
    push.restart()
  }
  function applyPreset(name) {
    if (!presets[name]) return
    bands = presets[name].slice(); preset = name
    editing = true
    push.restart()
  }
  Timer {
    id: push
    interval: 160
    onTriggered: {
      if (page.isGlobal) host.eqRun(["set", "--bands", page.bands.join(","), "--preset", page.preset])
      else page.mixCmd(["mix-eq", page.scope, "bands=" + page.bands.join(","), "preset=" + page.preset])
      page.editing = false
    }
  }

  readonly property real shownPreamp: eq.autoPreamp !== false ? Model.autoPreamp(bands) : (eq.preamp || 0)

  component Card: HubCard { fg: page.fg; accent: page.accent }

  // ======== which EQ: the global one or a mix's own ========
  Flow {
    visible: page.mixes.length > 0
    width: parent.width
    spacing: Style.space(6)
    Repeater {
      model: [{ id: "global", name: page.t("eq.global") }].concat(page.mixes.map(function(m) { return { id: m.id, name: m.name, on: m.eq && m.eq.enabled } }))
      delegate: HubChip {
        required property var modelData
        icon: modelData.id === "global" ? "\u{f0ea2}" : "\u{f1542}"
        label: modelData.name + (modelData.id !== "global" && modelData.on ? "  ●" : "")
        on: page.scope === modelData.id
        fg: page.fg; accent: page.accent; ink: page.bgc; fontFamily: page.ff
        onClicked: host.eqScope = modelData.id
      }
    }
  }

  // ======== header card ========
  Card {
    width: parent.width
    height: headerRow.implicitHeight + HubStyle.pad * 2

    Row {
      id: headerRow
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.margins: HubStyle.pad
      spacing: HubStyle.pad

      // power button; a slow ring breathes while the EQ is on
      Item {
        width: Style.space(48); height: width
        anchors.verticalCenter: parent.verticalCenter
        Rectangle {
          anchors.centerIn: parent
          width: parent.width; height: width; radius: width / 2
          color: "transparent"
          border.width: 2; border.color: page.accent
          opacity: 0
          SequentialAnimation on scale {
            running: page.eqOn && page.visible; loops: Animation.Infinite
            NumberAnimation { from: 1.0; to: 1.3; duration: 2200; easing.type: Easing.OutQuad }
          }
          SequentialAnimation on opacity {
            running: page.eqOn && page.visible; loops: Animation.Infinite
            NumberAnimation { from: 0.45; to: 0.0; duration: 2200; easing.type: Easing.OutQuad }
          }
        }
        Rectangle {
          anchors.fill: parent
          radius: width / 2
          color: page.eqOn ? page.accent : Qt.rgba(page.fg.r, page.fg.g, page.fg.b, 0.10)
          opacity: host && host.eqBusy ? 0.6 : 1
          Behavior on color { ColorAnimation { duration: 200 } }
          Text {
            anchors.centerIn: parent
            text: "\u{f0425}"                       // md-power
            color: page.eqOn ? (host ? host.bgc : "black") : page.fg
            font.family: page.ff; font.pixelSize: Style.space(21)
          }
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (!host) return
              if (page.isGlobal) { if (!host.eqBusy) host.eqRun([page.eqOn ? "disable" : "enable"]) }
              else page.mixCmd(["mix-eq", page.scope, "enabled=" + (page.eqOn ? "0" : "1")])
            }
          }
        }
      }

      Column {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - Style.space(48) - resetBtn.width - parent.spacing * 2
        spacing: Style.space(6)
        Text {
          width: parent.width
          elide: Text.ElideRight
          text: (page.isGlobal ? page.t("eq.enabled") : (page.scopeMix ? page.scopeMix.name : "")) + (page.preset === "custom" ? "  ·  " + page.t("eq.custom")
                                       : "  ·  " + page.t("preset." + page.preset))
          color: page.fg
          font.family: page.ff; font.pixelSize: Style.font.title; font.bold: true
        }
        Row {
          spacing: Style.spacing.sm
          Rectangle {                                 // device chip
            visible: page.eqOn
            anchors.verticalCenter: parent.verticalCenter
            width: devText.implicitWidth + Style.space(14)
            height: devText.implicitHeight + Style.space(6)
            radius: height / 2
            color: Qt.rgba(page.accent.r, page.accent.g, page.accent.b, 0.16)
            Text {
              id: devText
              anchors.centerIn: parent
              text: "󰓃  " + page.targetLabel
              color: page.accent
              font.family: page.ff; font.pixelSize: Style.font.caption
            }
          }
          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: !host ? "" : host.eqError ? page.t("eq.error", host.eqError)
                : host.eqBusy ? page.t("eq.working")
                : page.eqOn ? "" : page.t("eq.offHint")
            color: host && host.eqError ? host.urgent : Qt.darker(page.fg, 1.4)
            font.family: page.ff; font.pixelSize: Style.font.caption
          }
        }
      }

      HubChip {
        id: resetBtn
        anchors.verticalCenter: parent.verticalCenter
        iconOnly: true
        icon: "󰑓"
        label: page.t("eq.reset")
        fg: page.fg; accent: page.accent; fontFamily: page.ff
        onClicked: page.applyPreset("flat")
      }
    }
  }

  // ---- mixes that go around the EQ (their output is a device, not the EQ) ----
  readonly property string mixBin: ("" + Qt.resolvedUrl("bin/soundhub-mix")).replace("file://", "")
  property var bypass: []
  function checkBypass() { if (!mixProc.running) { mixProc.command = [mixBin, "snapshot"]; mixProc.running = true } }
  onVisibleChanged: if (visible) checkBypass()
  Component.onCompleted: checkBypass()
  onEqOnChanged: checkBypass()
  Process {
    id: mixProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var r = JSON.parse(text)
          page.mixes = r.mixes || []
          page.mixLoaded = true
          page.bypass = (r.mixes || []).filter(function(m) {
            return m.output && m.output !== "soundhub_eq" && !(m.eq && m.eq.enabled)
          })
        } catch (e) { page.bypass = [] }
      }
    }
  }

  Rectangle {
    visible: page.isGlobal && page.eqOn && page.bypass.length > 0
    width: parent.width
    height: bypassRow.implicitHeight + Style.space(20)
    radius: HubStyle.radius
    color: HubStyle.tint(page.urgent, 0.13)
    Row {
      id: bypassRow
      anchors.verticalCenter: parent.verticalCenter
      x: Style.spacing.md
      width: parent.width - Style.spacing.md * 2
      spacing: Style.spacing.sm
      Text {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - fixBtn.width - parent.spacing
        wrapMode: Text.Wrap
        text: "\u{f0026}  " + page.t("eq.bypass", page.bypass.map(function(m) { return m.name }).join(", "))
        color: page.fg
        font.family: page.ff; font.pixelSize: Style.font.caption
      }
      HubChip {
        id: fixBtn
        anchors.verticalCenter: parent.verticalCenter
        label: page.t("eq.bypassFix")
        on: true
        fg: page.fg; accent: page.accent; ink: page.bgc; fontFamily: page.ff
        onClicked: {
          var cmds = page.bypass.map(function(m) { return [page.mixBin, "mix-set", m.id, "output=soundhub_eq"] })
          for (var i = 0; i < cmds.length; i++) Quickshell.execDetached(cmds[i])
          page.bypass = []
          fixCheck.restart()
        }
      }
    }
  }
  Timer { id: fixCheck; interval: 1500; onTriggered: page.checkBypass() }

  // ======== curve card ========
  Card {
    width: parent.width
    height: board.height + preampRow.height + HubStyle.pad * 2 + Style.space(10)

    Item {
      id: board
      x: HubStyle.pad
      y: HubStyle.pad
      width: parent.width - HubStyle.pad * 2
      height: Style.space(196)
      opacity: page.eqOn ? 1 : 0.5
      Behavior on opacity { NumberAnimation { duration: 200 } }

      readonly property real colW: width / 6
      readonly property real padTop: Style.space(30)
      readonly property real padBottom: height - Style.space(26)
      readonly property real span: padBottom - padTop
      function yFor(db) { return padTop + span * (1 - (db + 12) / 24) }

      // guides: ±12, ±6, 0 dB
      Repeater {
        model: [12, 6, 0, -6, -12]
        delegate: Item {
          required property var modelData
          width: board.width; height: 1
          y: board.yFor(modelData)
          Rectangle {
            anchors.left: parent.left; anchors.right: parent.right
            anchors.leftMargin: Style.space(26)
            height: 1
            color: Qt.rgba(page.fg.r, page.fg.g, page.fg.b, modelData === 0 ? 0.16 : 0.06)
          }
          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: (modelData > 0 ? "+" : "") + modelData
            color: Qt.darker(page.fg, 1.9)
            font.family: page.ff; font.pixelSize: Style.font.caption - 2
          }
        }
      }

      // filled response curve through the band points
      Canvas {
        id: curve
        anchors.fill: parent
        anchors.leftMargin: Style.space(26)
        onPaint: {
          var ctx = getContext("2d")
          ctx.reset()
          var cw = width / 6
          var pts = []
          for (var i = 0; i < 6; i++) pts.push([cw * (i + 0.5), board.yFor(page.bands[i] || 0)])
          ctx.beginPath()
          ctx.moveTo(0, pts[0][1])
          ctx.lineTo(pts[0][0], pts[0][1])
          for (var j = 0; j < 5; j++) {
            var mx = (pts[j][0] + pts[j + 1][0]) / 2
            ctx.bezierCurveTo(mx, pts[j][1], mx, pts[j + 1][1], pts[j + 1][0], pts[j + 1][1])
          }
          ctx.lineTo(width, pts[5][1])
          ctx.strokeStyle = page.accent
          ctx.lineWidth = 2.5
          ctx.stroke()
          ctx.lineTo(width, board.yFor(-12)); ctx.lineTo(0, board.yFor(-12)); ctx.closePath()
          var g = ctx.createLinearGradient(0, board.padTop, 0, board.padBottom)
          g.addColorStop(0, Qt.rgba(page.accent.r, page.accent.g, page.accent.b, 0.28))
          g.addColorStop(1, Qt.rgba(page.accent.r, page.accent.g, page.accent.b, 0.02))
          ctx.fillStyle = g
          ctx.fill()
        }
        Connections { target: page; function onBandsChanged() { curve.requestPaint() } }
        Component.onCompleted: requestPaint()
      }

      Repeater {
        model: 6
        delegate: Item {
          id: band
          required property int index
          readonly property real db: page.bands[index] || 0
          readonly property bool hot: drag.pressed || drag.containsMouse
          x: Style.space(26) + (board.width - Style.space(26)) / 6 * index
          width: (board.width - Style.space(26)) / 6
          height: board.height

          Rectangle {                             // value pill
            anchors.horizontalCenter: parent.horizontalCenter
            y: 0
            width: valText.implicitWidth + Style.space(12)
            height: valText.implicitHeight + Style.space(4)
            radius: height / 2
            color: band.hot ? page.accent
                 : band.db === 0 ? "transparent" : Qt.rgba(page.accent.r, page.accent.g, page.accent.b, 0.14)
            Text {
              id: valText
              anchors.centerIn: parent
              text: (band.db > 0 ? "+" : "") + band.db.toFixed(1)
              color: band.hot ? (host ? host.bgc : "black") : band.db === 0 ? Qt.darker(page.fg, 1.5) : page.accent
              font.family: page.ff; font.pixelSize: Style.font.caption
              font.bold: band.db !== 0
            }
          }
          Rectangle {                             // track
            x: parent.width / 2 - width / 2
            y: board.padTop
            width: Style.space(2)
            height: board.span
            radius: width / 2
            color: Qt.rgba(page.fg.r, page.fg.g, page.fg.b, band.hot ? 0.22 : 0.10)
          }
          Rectangle {                             // knob
            width: Style.space(band.hot ? 18 : 15); height: width; radius: width / 2
            x: parent.width / 2 - width / 2
            y: board.yFor(band.db) - height / 2
            color: host ? host.bgc : "black"
            border.width: 3; border.color: page.accent
            Behavior on width { NumberAnimation { duration: 120 } }
          }
          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            text: Model.eqFreqLabel(Model.eqFreqs[band.index]) + "Hz"
            color: band.hot ? page.fg : Qt.darker(page.fg, 1.45)
            font.family: page.ff; font.pixelSize: Style.font.caption
          }
          MouseArea {
            id: drag
            x: 0; y: board.padTop - Style.space(12)
            width: parent.width; height: board.span + Style.space(24)
            hoverEnabled: true
            cursorShape: Qt.SizeVerCursor
            function dbAt(my) {
              var ry = my + y - board.padTop
              return Math.max(-12, Math.min(12, 12 - 24 * ry / board.span))
            }
            onPressed: function(e) { page.setBand(band.index, dbAt(e.y)) }
            onPositionChanged: function(e) { if (pressed) page.setBand(band.index, dbAt(e.y)) }
            onDoubleClicked: page.setBand(band.index, 0)
            onWheel: function(w) { page.setBand(band.index, band.db + (w.angleDelta.y > 0 ? 0.5 : -0.5)) }
          }
        }
      }
    }

    // preamp, at the foot of the curve card
    Row {
      id: preampRow
      x: HubStyle.pad
      y: board.y + board.height + Style.space(10)
      width: parent.width - HubStyle.pad * 2
      height: HubStyle.controlH
      spacing: Style.spacing.sm
      Text {
        anchors.verticalCenter: parent.verticalCenter
        width: Style.space(110)
        text: "󰕾  " + page.t("eq.preamp")
        color: page.fg
        font.family: page.ff; font.pixelSize: Style.font.body
      }
      HubSlider {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - Style.space(110) - autoChip.width - parent.spacing * 2
        minimum: -24; maximum: 6; step: 0.5
        format: function(v) { return v.toFixed(1) + " dB" }
        value: page.shownPreamp
        enabled: page.eq.autoPreamp === false
        opacity: enabled ? 1 : 0.45
        fillColor: page.accent
        fontFamily: page.ff
        onReleased: function(v) {
          var val = String(Math.round(v * 2) / 2)
          if (page.isGlobal) host.eqRun(["set", "--preamp", val]); else page.mixCmd(["mix-eq", page.scope, "preamp=" + val])
        }
      }
      HubChip {                                       // Auto chip
        id: autoChip
        anchors.verticalCenter: parent.verticalCenter
        label: page.t("eq.auto")
        on: page.eq.autoPreamp !== false
        fg: page.fg; accent: page.accent; ink: page.bgc; fontFamily: page.ff
        onClicked: {
          var val = on ? String(page.shownPreamp) : "auto"
          if (page.isGlobal) host.eqRun(["set", "--preamp", val]); else page.mixCmd(["mix-eq", page.scope, "preamp=" + val])
        }
      }
    }
  }

  // ======== presets: chips in a card ========
  Column {
    width: parent.width
    spacing: Style.space(6)
    HubCaption { text: page.t("eq.presets"); icon: "󰺢"; fg: page.fg; fontFamily: page.ff }
    Card {
      width: parent.width
      height: presetFlow.implicitHeight + HubStyle.pad * 2
      Flow {
        id: presetFlow
        x: HubStyle.pad; y: HubStyle.pad
        width: parent.width - HubStyle.pad * 2
        spacing: Style.space(6)
        Repeater {
          model: page.presetOrder
          delegate: HubChip {
            required property string modelData
            icon: page.presetIcons[modelData] || "󰺢"
            label: page.t("preset." + modelData)
            on: page.preset === modelData
            fg: page.fg; accent: page.accent; ink: page.bgc; fontFamily: page.ff
            onClicked: page.applyPreset(modelData)
          }
        }
      }
    }
  }
}
