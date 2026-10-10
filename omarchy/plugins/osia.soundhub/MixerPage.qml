import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Mixer — Mixline-style routing, built to be operated by clicks:
//   SOURCES  apps playing sound and microphones. Under each, one chip per mix:
//            click a chip to send the source into that mix (or stop sending).
//   MIXES    our virtual mixes (bin/soundhub-mix). Each lists its inputs with
//            their own level, mute and ×; a dropdown picks where the mix goes:
//            a device, through the equalizer, or virtual only (for OBS/Discord).
//   OUTPUTS  physical devices only. The one sound plays on now is marked, with
//            the equalizer as a switch on it; click another card to move the
//            sound there. ✎ lets you hide devices you never use.
// Cables are drawn for overview; dragging a dot still connects. Apps without
// cables go to the active output exactly as without SoundHub.
Item {
  id: page
  property var host: null
  implicitHeight: Style.space(580)

  readonly property color fg: host ? host.fg : "white"
  readonly property color accent: host ? host.accent : "white"
  readonly property color urgent: host ? host.urgent : "red"
  readonly property color bg: Color.background
  readonly property string ff: host ? host.ff : ""
  readonly property real radius: Math.max(6, Math.min(Style.cornerRadius, 12))
  function t(k, a) { return host ? host.t(k, a) : k }
  function fill(c, a) { return Qt.tint(Color.background, Qt.rgba(c.r, c.g, c.b, a)) }

  // ---- backend -----------------------------------------------------------
  readonly property string bin: ("" + Qt.resolvedUrl("bin/soundhub-mix")).replace("file://", "")
  property var snap: ({ sources: [], mixes: [], cables: [], outputs: [], defaultSink: "" })
  property var queue: []
  function cmd(args) {
    if (proc.running) { queue = queue.concat([args]); return }
    proc.command = [bin].concat(args)
    proc.running = true
  }
  Process {
    id: proc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: { try { var r = JSON.parse(text); if (r.sources) page.snap = r } catch (e) {} }
    }
    onExited: if (page.queue.length) { var n = page.queue[0]; page.queue = page.queue.slice(1); page.cmd(n) }
  }
  Timer {
    interval: 1500; repeat: true; triggeredOnStart: true
    running: page.visible && !page.dragging
    onTriggered: if (!proc.running) page.cmd(["snapshot"])
  }

  // ---- presets & folders (stored per preset by the backend) ----------------
  property bool editing: false
  readonly property var presets: snap.presets || []
  readonly property string activePreset: snap.activePreset || ""
  readonly property var folders: snap.folders || ({ out: [], in: [] })
  function presetLabel(p, i) { return p.name ? p.name : (i === 0 ? t("mx.presetMain") : t("mx.presetN", i + 1)) }

  function folderOf(kind, dev) {
    var fs = folders[kind] || []
    for (var i = 0; i < fs.length; i++) if (fs[i].devices.indexOf(dev) >= 0) return fs[i]
    return null
  }
  function cycleFolder(kind, dev) {
    var fs = folders[kind] || [], cur = folderOf(kind, dev)
    var order = [""].concat(fs.map(function(f) { return f.id }))
    var next = order[(order.indexOf(cur ? cur.id : "") + 1) % order.length]
    cmd(["device-folder", kind, dev, next || "-"])
  }
  // sections for a column: loose devices first, then each folder
  function sections(kind, items, nameOf) {
    var fs = folders[kind] || [], used = {}, out = []
    for (var i = 0; i < fs.length; i++) for (var j = 0; j < fs[i].devices.length; j++) used[fs[i].devices[j]] = true
    out.push({ folder: null, items: items.filter(function(x) { return !used[nameOf(x)] }) })
    for (var k = 0; k < fs.length; k++) {
      var f = fs[k]
      out.push({ folder: f, items: items.filter(function(x) { return f.devices.indexOf(nameOf(x)) >= 0 }) })
    }
    return out
  }

  // one-time move of the earlier tags / hidden devices into folders
  property bool migrated: false
  function migrateTags() {
    if (migrated || !host || !snap.presets) return
    migrated = true
    var tagMap = host.opt("deviceTags", ({})) || ({}), hiddenOld = host.opt("hiddenDevices", []) || []
    var groups = {}
    for (var dev in tagMap) if (tagMap[dev]) (groups[tagMap[dev]] = groups[tagMap[dev]] || []).push(dev)
    for (var i = 0; i < hiddenOld.length; i++) (groups["__hidden"] = groups["__hidden"] || []).push(hiddenOld[i])
    var names = Object.keys(groups)
    if (!names.length) return
    var outNames = snap.outputs.map(function(o) { return o.name })
    for (var n = 0; n < names.length; n++) {
      var devs = groups[names[n]]
      var label = names[n] === "__hidden" ? t("mx.tagHidden") : names[n]
      var outs = devs.filter(function(d) { return outNames.indexOf(d) >= 0 })
      var ins = devs.filter(function(d) { return outNames.indexOf(d) < 0 })
      var col = names[n] === "__hidden" ? "collapsed=1" : "collapsed=0"
      if (outs.length) cmd(["folder-add", "out", label, col, "devices=" + outs.join(",")])
      if (ins.length) cmd(["folder-add", "in", label, col, "devices=" + ins.join(",")])
    }
    host.persist({ deviceTags: ({}), hiddenDevices: [], deviceTagList: [], mixerOutTab: "all", mixerInTab: "all" })
  }
  onPresetsChanged: Qt.callLater(migrateTags)

  // ---- derived model -----------------------------------------------------
  readonly property var defMic: Pipewire.defaultAudioSource
  readonly property var cableSrcs: snap.cables.map(function(c) { return c.src })
  readonly property var apps: snap.sources.filter(function(s) { return s.kind === "app" })
  readonly property var mics: snap.sources.filter(function(s) { return s.kind === "mic" })
  // the microphone in use comes first
  readonly property var sortedMics: mics.slice().sort(function(a, b) {
    var da = defMic && a.key === "mic:" + defMic.name, db = defMic && b.key === "mic:" + defMic.name
    return da === db ? 0 : (da ? -1 : 1)
  })
  readonly property var sourceList: apps.concat(sortedMics)
  readonly property var allMicNames: snap.sources.filter(function(x) { return x.kind === "mic" }).map(function(x) { return x.key.slice(4) })
  readonly property var allOutNames: snap.outputs.filter(function(o) { return o.name !== "soundhub_eq" }).map(function(o) { return o.name })
  readonly property var mixes: snap.mixes

  readonly property var eq: host ? host.eq : ({})
  readonly property bool eqOn: !!(eq && eq.enabled)
  readonly property string defaultSink: snap.defaultSink || ""
  // the physical device sound plays on now (through the EQ when it is on)
  readonly property string activeOut: defaultSink === "soundhub_eq" ? ("" + (eq.target || "")) : defaultSink
  readonly property var devices: snap.outputs.filter(function(o) {
    return o.name !== "soundhub_eq"
  })
  function outLabel(name) {
    for (var i = 0; i < snap.outputs.length; i++) if (snap.outputs[i].name === name) return snap.outputs[i].label
    return name
  }

  // Mix colours follow the theme: the first mix is the accent, the next ones
  // step around the colour wheel from it (same idea as the "rainbow" palette).
  function mixTint(m) {
    var i = mixes.indexOf(m)
    if (i <= 0) return accent
    var h = accent.hslHue < 0 ? 0 : accent.hslHue
    return Qt.hsla((h + i * 0.17) % 1, Math.max(0.4, accent.hslSaturation),
                   Math.min(0.72, Math.max(0.55, accent.hslLightness)), 1)
  }
  function mixById(id) { for (var i = 0; i < mixes.length; i++) if (mixes[i].id === id) return mixes[i]; return null }
  function cable(src, mid) {
    for (var i = 0; i < snap.cables.length; i++) { var c = snap.cables[i]; if (c.src === src && c.mix === mid) return c }
    return null
  }
  function sourceLabel(key) {
    for (var i = 0; i < snap.sources.length; i++) if (snap.sources[i].key === key) return snap.sources[i].label
    var c = snap.cables.filter(function(x) { return x.src === key })[0]
    return c && c.label ? c.label : key.split(":").slice(1).join(":")
  }
  function toggleCable(src, mid, label) {
    if (cable(src, mid)) cmd(["cable-remove", src, mid])
    else cmd(["cable-set", src, mid, "label=" + label])
  }

  // ---- output switching ----
  function useDevice(name) {
    if (eqOn) { if (host) host.eqRun(["retarget", name]); return }
    var n = nodeByName(name)
    if (!n) return
    Pipewire.preferredDefaultAudioSink = n
    Quickshell.execDetached(["omarchy-audio-output-set-default", "" + n.id, "" + n.name])
  }
  function toggleEq() { if (host && !host.eqBusy) host.eqRun([eqOn ? "disable" : "enable"]) }

  // PipeWire nodes behind the cards, for direct volume control
  readonly property var pwNodes: Pipewire.nodes ? Pipewire.nodes.values : []
  function nodesByIds(ids) {
    var out = []
    for (var i = 0; i < pwNodes.length; i++) if (pwNodes[i] && ids.indexOf(pwNodes[i].id) >= 0) out.push(pwNodes[i])
    return out
  }
  function nodeByName(name) {
    for (var i = 0; i < pwNodes.length; i++) if (pwNodes[i] && pwNodes[i].name === name) return pwNodes[i]
    return null
  }
  readonly property var trackedIds: {
    var ids = []
    for (var i = 0; i < sourceList.length; i++) ids = ids.concat(sourceList[i].nodeIds || [])
    for (var j = 0; j < devices.length; j++) ids.push(devices[j].id)
    return ids
  }
  PwObjectTracker { objects: page.nodesByIds(page.trackedIds) }

  function appGlyph(s) {
    var k = ("" + (s.key || "")).toLowerCase()
    if (s.kind === "mic") return "\u{f036c}"
    if (k.indexOf("zen") >= 0 || k.indexOf("firefox") >= 0) return "\u{f0239}"
    if (k.indexOf("brave") >= 0 || k.indexOf("chrom") >= 0) return "\u{f02af}"
    if (k.indexOf("vesktop") >= 0 || k.indexOf("discord") >= 0) return "\u{f066f}"
    if (k.indexOf("mpv") >= 0) return "\u{f040c}"
    if (k.indexOf("focus") >= 0) return "\u{f117b}"
    return "\u{f075a}"
  }

  // ---- dot registry for drawing cables ------------------------------------------
  property var dots: ({})
  property int tick: 0
  function reg(k, item) { var d = dots; d[k] = item; dots = d; relayout() }
  function unreg(k, item) { if (dots[k] === item) { var d = dots; delete d[k]; dots = d; relayout() } }
  function relayout() { tick++; cables.requestPaint() }
  function pt(k) {
    var it = dots[k]
    if (!it || !it.visible) return null
    var p = it.mapToItem(page, it.width / 2, it.height / 2)
    return { x: p.x, y: p.y }
  }
  onSnapChanged: { switching = false; Qt.callLater(relayout) }
  onWidthChanged: Qt.callLater(relayout)

  // ---- drag to connect (optional; chips do the same) ----
  property bool dragging: false
  property string dragKind: ""
  property string dragFrom: ""
  property point dragAt: Qt.point(0, 0)
  function startDrag(kind, from, item, m) { dragKind = kind; dragFrom = from; dragging = true; dragAt = item.mapToItem(page, m.x, m.y); cables.requestPaint() }
  function moveDrag(item, m) { dragAt = item.mapToItem(page, m.x, m.y); cables.requestPaint() }
  function endDrag() {
    var prefix = dragKind === "src" ? "mixin:" : "out:"
    var best = "", bestD = Style.space(40)
    for (var k in dots) {
      if (k.indexOf(prefix) !== 0) continue
      var p = pt(k); if (!p) continue
      var d = Math.hypot(p.x - dragAt.x, p.y - dragAt.y)
      if (d < bestD) { bestD = d; best = k.slice(prefix.length) }
    }
    if (best) {
      if (dragKind === "src") { if (!cable(dragFrom, best)) cmd(["cable-set", dragFrom, best, "label=" + sourceLabel(dragFrom)]) }
      else cmd(["mix-set", dragFrom, "output=" + best])
    }
    dragging = false; dragKind = ""; dragFrom = ""
    cables.requestPaint()
  }

  // ---- layout ----
  readonly property real gutter: Style.space(56)
  readonly property real colW: (width - gutter * 2) / 3
  readonly property real headH: Style.space(32)
  readonly property real barH: Style.space(42)                // presets strip

  Canvas {
    id: cables
    anchors.fill: parent
    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      function bez(a, b, color, w, dash, alpha) {
        ctx.save()
        ctx.globalAlpha = alpha; ctx.strokeStyle = color; ctx.lineWidth = w
        if (dash) ctx.setLineDash(dash)
        var dx = Math.max(30, (b.x - a.x) * 0.5)
        ctx.beginPath(); ctx.moveTo(a.x, a.y)
        ctx.bezierCurveTo(a.x + dx, a.y, b.x - dx, b.y, b.x, b.y)
        ctx.stroke(); ctx.restore()
      }
      var act = page.pt("out:" + page.activeOut)
      for (var i = 0; i < page.apps.length; i++) {
        var s = page.apps[i]
        if (!s.live || page.cableSrcs.indexOf(s.key) >= 0) continue
        var a = page.pt("src:" + s.key)
        if (a && act) bez(a, act, page.fg, 1.2, [3, 5], 0.18)
      }
      for (var j = 0; j < page.snap.cables.length; j++) {
        var c = page.snap.cables[j], m = page.mixById(c.mix)
        var p1 = page.pt("src:" + c.src), p2 = page.pt("mixin:" + c.mix)
        if (p1 && p2 && m) bez(p1, p2, page.mixTint(m), 2.4, c.muted ? [4, 4] : null, c.muted ? 0.35 : 0.85)
      }
      for (var k = 0; k < page.mixes.length; k++) {
        var mx = page.mixes[k]
        var o1 = page.pt("mixout:" + mx.id)
        var tgt = mx.output === "soundhub_eq" ? ("" + (page.eq.target || "")) : mx.output
        var o2 = tgt ? page.pt("out:" + tgt) : null
        if (o1 && o2) bez(o1, o2, page.mixTint(mx), 2.4, mx.muted ? [4, 4] : null, mx.muted ? 0.35 : 0.85)
        var o3 = mx.monitor ? page.pt("out:" + mx.monitor) : null
        if (o1 && o3 && mx.monitor !== tgt) bez(o1, o3, page.mixTint(mx), 1.5, [2, 4], 0.6)
      }
      if (page.dragging) {
        var from = page.pt((page.dragKind === "src" ? "src:" : "mixout:") + page.dragFrom)
        if (from) bez(from, page.dragAt, page.accent, 2.4, [6, 4], 0.9)
      }
    }
  }

  // ---- shared pieces (inline components can't see `page`; pass what they need) ----
  component Dot: Rectangle {
    id: dot
    property var registry: null
    property string regKey: ""
    property color tint: "white"
    width: Style.space(12); height: width; radius: width / 2
    color: tint
    border.width: 2
    border.color: Color.background
    Component.onCompleted: if (registry && regKey) registry.reg(regKey, dot)
    Component.onDestruction: if (registry && regKey) registry.unreg(regKey, dot)
  }

  component Header: Item {
    id: hdr
    property string text: ""
    property color fg: "white"
    property string ff: ""
    height: Style.space(32)
    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: hdr.text
      color: Qt.darker(hdr.fg, 1.4)
      font.family: hdr.ff; font.pixelSize: Style.font.caption; font.bold: true
      font.letterSpacing: 1.3
    }
  }

  component Chip: Rectangle {
    id: chip
    property string label: ""
    property color tint: "white"
    property color ink: "black"
    property bool on: false
    property string ff: ""
    signal clicked()
    height: chipText.implicitHeight + Style.space(6)
    width: chipText.implicitWidth + Style.space(14)
    radius: height / 2
    color: on ? tint : "transparent"
    border.width: 1
    border.color: tint
    opacity: chipMouse.containsMouse && !on ? 0.8 : 1
    Text {
      id: chipText
      anchors.centerIn: parent
      text: chip.label
      color: chip.on ? chip.ink : chip.tint
      font.family: chip.ff; font.pixelSize: Style.font.caption - 1; font.bold: chip.on
    }
    MouseArea { id: chipMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: chip.clicked() }
  }

  // folder header: ▸/▾ collapse on click; in edit mode rename (click the name) and ×
  component FolderHead: Rectangle {
    id: fh
    property var owner: null
    property string kind: "out"
    property var folder: null
    property int count: 0
    property bool renaming: false
    width: parent ? parent.width : 0
    height: Style.space(28)
    radius: height / 2
    color: owner ? owner.fill(owner.fg, fhMouse.containsMouse ? 0.08 : 0.04) : "transparent"
    MouseArea {
      id: fhMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: if (fh.folder) fh.owner.cmd(["folder-set", fh.kind, fh.folder.id, "collapsed=" + (fh.folder.collapsed ? "0" : "1")])
    }
    Row {
      anchors.left: parent.left; anchors.leftMargin: Style.space(10)
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(6)
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: fh.folder && fh.folder.collapsed ? "\u{f0142}" : "\u{f0140}"     // chevron right / down
        color: fh.owner ? fh.owner.accent : "white"
        font.family: fh.owner ? fh.owner.ff : ""; font.pixelSize: Style.font.body
      }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: fh.folder && fh.folder.collapsed ? "\u{f024b}" : "\u{f0770}"     // folder / folder-open
        color: fh.owner ? fh.owner.accent : "white"
        font.family: fh.owner ? fh.owner.ff : ""; font.pixelSize: Style.font.body
      }
      Text {
        visible: !fh.renaming
        anchors.verticalCenter: parent.verticalCenter
        text: (fh.folder ? fh.folder.name : "") + "  ·  " + fh.count
        color: fh.owner ? fh.owner.fg : "white"
        font.family: fh.owner ? fh.owner.ff : ""; font.pixelSize: Style.font.caption; font.bold: true
        MouseArea {
          anchors.fill: parent
          enabled: fh.owner && fh.owner.editing
          cursorShape: Qt.IBeamCursor
          onClicked: { fh.renaming = true; fhEdit.text = fh.folder.name; fhEdit.forceActiveFocus(); fhEdit.selectAll() }
        }
      }
      TextInput {
        id: fhEdit
        visible: fh.renaming
        anchors.verticalCenter: parent.verticalCenter
        width: Style.space(140)
        color: fh.owner ? fh.owner.fg : "white"
        font.family: fh.owner ? fh.owner.ff : ""; font.pixelSize: Style.font.caption; font.bold: true
        maximumLength: 30
        onAccepted: { fh.owner.cmd(["folder-set", fh.kind, fh.folder.id, "name=" + text]); fh.renaming = false }
        onActiveFocusChanged: if (!activeFocus) fh.renaming = false
      }
    }
    Text {                                            // × delete folder (devices fall back to loose)
      visible: fh.owner && fh.owner.editing
      anchors.right: parent.right; anchors.rightMargin: Style.space(10)
      anchors.verticalCenter: parent.verticalCenter
      text: "\u{f0156}"
      color: fh.owner ? fh.owner.urgent : "red"
      font.family: fh.owner ? fh.owner.ff : ""; font.pixelSize: Style.font.body
      MouseArea { anchors.fill: parent; anchors.margins: -5; cursorShape: Qt.PointingHandCursor; onClicked: fh.owner.cmd(["folder-remove", fh.kind, fh.folder.id]) }
    }
  }

  // "+ folder" (edit mode)
  component AddFolder: Rectangle {
    id: af
    property var owner: null
    property string kind: "out"
    property bool adding: false
    visible: owner && owner.editing
    height: Style.space(24)
    width: adding ? Style.space(160) : afLbl.implicitWidth + Style.space(18)
    radius: height / 2
    color: "transparent"
    border.width: 1
    border.color: owner ? owner.accent : "white"
    Text {
      id: afLbl
      visible: !af.adding
      anchors.centerIn: parent
      text: "\u{f0257} " + (af.owner ? af.owner.t("mx.folderAdd") : "")
      color: af.owner ? af.owner.accent : "white"
      font.family: af.owner ? af.owner.ff : ""; font.pixelSize: Style.font.caption - 1
      MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: { af.adding = true; afEdit.text = ""; afEdit.forceActiveFocus() } }
    }
    TextInput {
      id: afEdit
      visible: af.adding
      anchors.fill: parent
      anchors.leftMargin: Style.space(10); anchors.rightMargin: Style.space(10)
      verticalAlignment: TextInput.AlignVCenter
      color: af.owner ? af.owner.fg : "white"
      font.family: af.owner ? af.owner.ff : ""; font.pixelSize: Style.font.caption
      maximumLength: 30
      onAccepted: { if (text.trim()) af.owner.cmd(["folder-add", af.kind, text.trim()]); af.adding = false }
      onActiveFocusChanged: if (!activeFocus) af.adding = false
      Text {
        visible: !afEdit.text
        anchors.verticalCenter: parent.verticalCenter
        text: af.owner ? af.owner.t("mx.folderNew") : ""
        color: af.owner ? Qt.darker(af.owner.fg, 1.8) : "gray"
        font: afEdit.font
      }
    }
  }

  // ======== PRESETS strip ========
  property bool switching: false
  Rectangle {
    x: 0; y: 0
    width: page.width; height: page.barH - Style.space(8)
    radius: page.radius
    color: page.fill(page.fg, 0.04)
    border.width: 1
    border.color: Qt.rgba(page.fg.r, page.fg.g, page.fg.b, 0.07)

    Row {
      anchors.left: parent.left; anchors.leftMargin: Style.space(10)
      anchors.right: editBtn.left; anchors.rightMargin: Style.space(6)
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(6)
      clip: true

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: (page.switching ? "\u{f0772}  " : "\u{f1542}  ") + page.t("mx.presets")
        color: Qt.darker(page.fg, 1.35)
        font.family: page.ff; font.pixelSize: Style.font.caption; font.bold: true
        font.letterSpacing: 1.2
      }

      Repeater {
        model: page.presets
        delegate: Rectangle {
          id: pc
          required property var modelData
          required property int index
          readonly property bool on: modelData.id === page.activePreset
          property bool renaming: false
          anchors.verticalCenter: parent.verticalCenter
          height: Style.space(26)
          width: (renaming ? Style.space(130) : pcText.implicitWidth + Style.space(22)) + (page.editing && page.presets.length > 1 ? Style.space(16) : 0)
          radius: height / 2
          color: on ? page.accent : page.fill(page.fg, pcMouse.containsMouse ? 0.10 : 0.05)
          Text {
            id: pcText
            visible: !pc.renaming
            x: Style.space(11)
            anchors.verticalCenter: parent.verticalCenter
            text: page.presetLabel(pc.modelData, pc.index) + (page.editing ? "  \u{f03eb}" : "")
            color: pc.on ? page.bg : page.fg
            font.family: page.ff; font.pixelSize: Style.font.caption; font.bold: pc.on
          }
          TextInput {
            id: pcEdit
            visible: pc.renaming
            x: Style.space(11); width: Style.space(110)
            anchors.verticalCenter: parent.verticalCenter
            color: pc.on ? page.bg : page.fg
            font.family: page.ff; font.pixelSize: Style.font.caption; font.bold: true
            maximumLength: 30
            onAccepted: { page.cmd(["preset-set", pc.modelData.id, "name=" + text]); pc.renaming = false }
            onActiveFocusChanged: if (!activeFocus) pc.renaming = false
          }
          MouseArea {
            id: pcMouse
            anchors.fill: parent
            anchors.rightMargin: page.editing && page.presets.length > 1 ? Style.space(18) : 0
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (page.editing) { pc.renaming = true; pcEdit.text = pc.modelData.name || page.presetLabel(pc.modelData, pc.index); pcEdit.forceActiveFocus(); pcEdit.selectAll() }
              else if (!pc.on && !page.switching) { page.switching = true; page.cmd(["preset-switch", pc.modelData.id]) }
            }
          }
          Text {                                      // × delete preset (edit mode)
            visible: page.editing && page.presets.length > 1
            anchors.right: parent.right; anchors.rightMargin: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            text: "\u{f0156}"
            color: pc.on ? page.bg : page.urgent
            font.family: page.ff; font.pixelSize: Style.font.caption
            MouseArea { anchors.fill: parent; anchors.margins: -5; cursorShape: Qt.PointingHandCursor; onClicked: page.cmd(["preset-remove", pc.modelData.id]) }
          }
        }
      }

      Rectangle {                                     // + preset (copies the current set-up)
        anchors.verticalCenter: parent.verticalCenter
        height: Style.space(26)
        width: npText.implicitWidth + Style.space(20)
        radius: height / 2
        color: "transparent"
        border.width: 1
        border.color: page.accent
        Text {
          id: npText
          anchors.centerIn: parent
          text: "\u{f0415} " + page.t("mx.presetAdd")
          color: page.accent
          font.family: page.ff; font.pixelSize: Style.font.caption
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: page.cmd(["preset-add", page.t("mx.presetN", page.presets.length + 1)]) }
      }
    }

    PanelActionButton {                               // ✎ edit presets, folders, device placement
      id: editBtn
      anchors.right: parent.right; anchors.rightMargin: Style.space(6)
      anchors.verticalCenter: parent.verticalCenter
      iconText: page.editing ? "\u{f012c}" : "\u{f03eb}"
      tooltipText: page.t("mx.editDevices")
      foreground: page.editing ? page.accent : Qt.darker(page.fg, 1.3)
      hoverColor: page.accent; fontFamily: page.ff
      onClicked: page.editing = !page.editing
    }
  }

  // ======== SOURCES ========
  Header { y: page.barH; x: 0; width: page.colW; text: page.t("mx.sources"); fg: page.fg; ff: page.ff }
  Flickable {
    x: 0; y: page.barH + page.headH
    width: page.colW; height: page.height - page.barH - page.headH
    contentHeight: srcCol.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    onContentYChanged: page.relayout()

    Column {
      id: srcCol
      width: parent.width
      spacing: Style.space(8)

      Text {
        visible: page.sourceList.length === 0
        width: parent.width; wrapMode: Text.Wrap
        text: page.t("snd.noApps")
        color: Qt.darker(page.fg, 1.5)
        font.family: page.ff; font.pixelSize: Style.font.caption
      }

      Component {
        id: srcCard
        Rectangle {
          id: sc
          required property var modelData
          readonly property var nodes: page.nodesByIds(modelData.nodeIds || [])
          readonly property var n0: nodes.length ? nodes[0] : null
          readonly property real vol: n0 && n0.audio ? n0.audio.volume : 0
          readonly property bool muted: n0 && n0.audio ? n0.audio.muted : false
          readonly property bool isMic: modelData.kind === "mic"
          readonly property string devName: isMic ? modelData.key.slice(4) : ""
          readonly property bool isDefaultMic: isMic && page.defMic !== null && devName === page.defMic.name
          readonly property var folder: isMic ? page.folderOf("in", devName) : null
          width: srcCol.width
          height: scCol.implicitHeight + Style.space(16)
          radius: page.radius
          color: isDefaultMic ? page.fill(page.accent, 0.07) : page.fill(page.fg, 0.045)
          border.width: 1
          border.color: isDefaultMic ? Qt.rgba(page.accent.r, page.accent.g, page.accent.b, 0.35) : Qt.rgba(page.fg.r, page.fg.g, page.fg.b, 0.07)
          opacity: modelData.live ? 1 : 0.5

          Column {
            id: scCol
            x: Style.space(10); y: Style.space(8)
            width: parent.width - Style.space(20)
            spacing: Style.space(6)

            Row {
              width: parent.width
              spacing: Style.space(8)
              Rectangle {
                width: Style.space(26); height: width; radius: width / 2
                anchors.verticalCenter: parent.verticalCenter
                color: Qt.rgba(page.accent.r, page.accent.g, page.accent.b, 0.15)
                Text {
                  anchors.centerIn: parent
                  text: page.appGlyph(sc.modelData)
                  color: page.accent
                  font.family: page.ff; font.pixelSize: Style.space(14)
                }
              }
              Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - Style.space(26) - Style.space(30) - (sc.isMic ? Style.space(30) : 0) - parent.spacing * 3
                text: sc.modelData.label
                color: page.fg
                font.family: page.ff; font.pixelSize: Style.font.body; font.bold: true
                elide: Text.ElideRight
              }
              PanelActionButton {                         // mic: use as input
                visible: sc.isMic && !page.editing
                anchors.verticalCenter: parent.verticalCenter
                iconText: sc.isDefaultMic ? "\u{f04ce}" : "\u{f04d2}"
                tooltipText: page.t("mx.useInput")
                foreground: sc.isDefaultMic && !page.editing ? page.accent : Qt.darker(page.fg, 1.3)
                hoverColor: page.accent; fontFamily: page.ff
                onClicked: {
                  var n = sc.n0; if (!n) return
                  Pipewire.preferredDefaultAudioSource = n
                  Quickshell.execDetached(["omarchy-audio-input-set-default", "" + n.id, "" + n.name])
                }
              }
              PanelActionButton {
                visible: sc.n0 !== null
                anchors.verticalCenter: parent.verticalCenter
                iconText: sc.muted ? "\u{f0581}" : Model.volumeGlyph(sc.vol, false)
                foreground: sc.muted ? page.urgent : Qt.darker(page.fg, 1.2)
                hoverColor: page.accent; fontFamily: page.ff
                onClicked: { var m = !sc.muted; for (var i = 0; i < sc.nodes.length; i++) if (sc.nodes[i].audio) sc.nodes[i].audio.muted = m }
              }
            }
            Chip {                                        // edit mode: this mic's tag (click to change)
              visible: page.editing && sc.isMic
              label: "\u{f024b} " + (sc.folder ? sc.folder.name : page.t("mx.folderNone"))
              tint: page.accent
              ink: page.bg
              on: sc.folder !== null
              ff: page.ff
              onClicked: page.cycleFolder("in", sc.devName)
            }
            Text {
              visible: sc.isMic && !sc.modelData.live
              text: "\u{f06a6}  " + page.t("mx.offline")
              color: Qt.darker(page.fg, 1.3)
              font.family: page.ff; font.pixelSize: Style.font.caption
            }
            Rectangle {                                   // "microphone in use" badge
              visible: sc.isDefaultMic
              height: micText.implicitHeight + Style.space(6)
              width: micText.implicitWidth + Style.space(14)
              radius: height / 2
              color: page.accent
              Text {
                id: micText
                anchors.centerIn: parent
                text: "\u{f036c}  " + page.t("mx.micHere")
                color: page.bg
                font.family: page.ff; font.pixelSize: Style.font.caption - 1; font.bold: true
              }
            }
            HubSlider {
              visible: sc.n0 !== null
              width: parent.width
              minimum: 0; maximum: 1
              value: sc.vol
              trackHeight: 3; knobSize: 10
              fillColor: page.accent
              fontFamily: page.ff
              onMoved: function(v) { for (var i = 0; i < sc.nodes.length; i++) if (sc.nodes[i].audio) sc.nodes[i].audio.volume = v }
            }
            Flow {                                        // send to mixes
              visible: page.mixes.length > 0
              width: parent.width
              spacing: Style.space(4)
              Repeater {
                model: page.mixes
                delegate: Chip {
                  required property var modelData
                  readonly property bool linked: page.cable(sc.modelData.key, modelData.id) !== null
                  label: (linked ? "\u{f012c} " : "+ ") + modelData.name
                  tint: page.mixTint(modelData)
                  ink: page.bg
                  ff: page.ff
                  on: linked
                  onClicked: page.toggleCable(sc.modelData.key, modelData.id, sc.modelData.label)
                }
              }
            }
          }

          Dot {
            registry: page
            regKey: "src:" + sc.modelData.key
            tint: page.cableSrcs.indexOf(sc.modelData.key) >= 0 ? page.accent : Qt.darker(page.fg, 1.5)
            anchors.right: parent.right; anchors.rightMargin: -width / 2
            y: Style.space(21) - height / 2
            MouseArea {
              id: srcDrag
              anchors.fill: parent; anchors.margins: -6
              cursorShape: Qt.CrossCursor
              preventStealing: true
              onPressed: function(m) { page.startDrag("src", sc.modelData.key, srcDrag, m) }
              onPositionChanged: function(m) { if (pressed) page.moveDrag(srcDrag, m) }
              onReleased: page.endDrag()
            }
          }
        }
      }

      Repeater { model: page.apps; delegate: srcCard }

      Item { width: 1; height: Style.space(4); visible: page.allMicNames.length > 0 }
      Text {
        visible: page.allMicNames.length > 0
        text: page.t("mx.mics")
        color: Qt.darker(page.fg, 1.4)
        font.family: page.ff; font.pixelSize: Style.font.caption; font.bold: true
        font.letterSpacing: 1.3
      }
      AddFolder { owner: page; kind: "in" }

      Repeater {                                    // loose mics, then each folder
        model: page.sections("in", page.sortedMics, function(m) { return m.key.slice(4) })
        delegate: Column {
          id: isec
          required property var modelData
          width: srcCol.width
          spacing: Style.space(8)
          visible: modelData.folder !== null || modelData.items.length > 0
          FolderHead { owner: page; kind: "in"; folder: isec.modelData.folder; count: isec.modelData.items.length; visible: isec.modelData.folder !== null }
          Repeater {
            model: isec.modelData.items.filter(function(m) {
              return !isec.modelData.folder || !isec.modelData.folder.collapsed
                     || (page.defMic && m.key === "mic:" + page.defMic.name) || page.cableSrcs.indexOf(m.key) >= 0
            })
            delegate: srcCard
          }
        }
      }
    }
  }

  // ======== MIXES ========
  Header { y: page.barH; x: page.colW + page.gutter; width: page.colW; text: page.t("mx.mixes"); fg: page.fg; ff: page.ff }
  Rectangle {                                         // "+ Mix"
    x: page.colW + page.gutter + page.colW - width
    y: page.barH + (page.headH - height) / 2
    width: addText.implicitWidth + Style.space(18)
    height: addText.implicitHeight + Style.space(8)
    radius: height / 2
    color: addMouse.containsMouse ? page.accent : Qt.rgba(page.accent.r, page.accent.g, page.accent.b, 0.16)
    Text {
      id: addText
      anchors.centerIn: parent
      text: "\u{f0415}  " + page.t("mx.newMix")
      color: addMouse.containsMouse ? page.bg : page.accent
      font.family: page.ff; font.pixelSize: Style.font.caption; font.bold: true
    }
    MouseArea {
      id: addMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: page.cmd(["mix-add", page.t("mx.mixN", page.mixes.length + 1), page.defaultSink])
    }
  }

  Flickable {
    x: page.colW + page.gutter; y: page.barH + page.headH
    width: page.colW; height: page.height - page.barH - page.headH
    contentHeight: mixCol.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    onContentYChanged: page.relayout()

    Column {
      id: mixCol
      width: parent.width
      spacing: Style.space(10)

      Rectangle {
        visible: page.mixes.length === 0
        width: parent.width
        height: Style.space(150)
        radius: page.radius
        color: page.fill(page.fg, 0.02)
        border.width: 1
        border.color: Qt.rgba(page.fg.r, page.fg.g, page.fg.b, 0.12)
        Text {
          anchors.centerIn: parent
          width: parent.width - Style.space(24)
          horizontalAlignment: Text.AlignHCenter
          wrapMode: Text.Wrap
          text: page.t("mx.empty")
          color: Qt.darker(page.fg, 1.4)
          font.family: page.ff; font.pixelSize: Style.font.caption
        }
      }

      Repeater {
        model: page.mixes
        delegate: Rectangle {
          id: mc
          required property var modelData
          readonly property color tint: page.mixTint(modelData)
          readonly property var inputs: page.snap.cables.filter(function(c) { return c.mix === mc.modelData.id })
          property bool renaming: false
          width: mixCol.width
          height: mcCol.implicitHeight + Style.space(18)
          radius: page.radius
          color: page.fill(tint, 0.08)
          border.width: 1
          border.color: Qt.rgba(tint.r, tint.g, tint.b, 0.45)

          Rectangle {
            width: Style.space(4); height: parent.height - Style.space(16)
            x: Style.space(6); anchors.verticalCenter: parent.verticalCenter
            radius: width / 2
            color: mc.tint
          }

          Column {
            id: mcCol
            x: Style.space(16); y: Style.space(9)
            width: parent.width - Style.space(26)
            spacing: Style.space(8)

            // header: name · listen · mute · delete
            Row {
              width: parent.width
              spacing: Style.space(2)
              Item {
                width: parent.width - Style.space(28) * 3
                height: Style.space(26)
                Text {
                  visible: !mc.renaming
                  anchors.verticalCenter: parent.verticalCenter
                  width: parent.width
                  text: mc.modelData.name + "  \u{f03eb}"
                  color: page.fg
                  font.family: page.ff; font.pixelSize: Style.font.body + 1; font.bold: true
                  elide: Text.ElideRight
                  MouseArea { anchors.fill: parent; cursorShape: Qt.IBeamCursor; onClicked: { mc.renaming = true; nameEdit.forceActiveFocus(); nameEdit.selectAll() } }
                }
                TextInput {
                  id: nameEdit
                  visible: mc.renaming
                  anchors.verticalCenter: parent.verticalCenter
                  width: parent.width
                  text: mc.modelData.name
                  color: page.fg
                  selectionColor: mc.tint
                  font.family: page.ff; font.pixelSize: Style.font.body + 1; font.bold: true
                  onAccepted: { page.cmd(["mix-set", mc.modelData.id, "name=" + text]); mc.renaming = false }
                  onActiveFocusChanged: if (!activeFocus) mc.renaming = false
                }
              }
              PanelActionButton {
                iconText: "\u{f07c5}"
                tooltipText: page.t("mx.monitor")
                foreground: mc.modelData.monitor ? mc.tint : Qt.darker(page.fg, 1.4)
                hoverColor: mc.tint; fontFamily: page.ff
                onClicked: page.cmd(["mix-set", mc.modelData.id, "monitor=" + (mc.modelData.monitor ? "" : page.activeOut)])
              }
              PanelActionButton {
                iconText: mc.modelData.muted ? "\u{f0581}" : "\u{f057e}"
                tooltipText: page.t("snd.mute")
                foreground: mc.modelData.muted ? page.urgent : Qt.darker(page.fg, 1.4)
                hoverColor: mc.tint; fontFamily: page.ff
                onClicked: page.cmd(["mix-set", mc.modelData.id, "muted=" + (mc.modelData.muted ? "0" : "1")])
              }
              PanelActionButton {
                iconText: "\u{f01b4}"
                tooltipText: page.t("mx.remove")
                foreground: Qt.darker(page.fg, 1.4)
                hoverColor: page.urgent; fontFamily: page.ff
                onClicked: page.cmd(["mix-remove", mc.modelData.id])
              }
            }

            // mix level
            HubSlider {
              width: parent.width
              minimum: 0; maximum: 1
              value: mc.modelData.volume
              fillColor: mc.tint
              fontFamily: page.ff
              onReleased: function(v) { page.cmd(["mix-set", mc.modelData.id, "volume=" + v.toFixed(3)]) }
            }

            // where it goes
            Dropdown {
              width: parent.width
              showLabel: false
              options: [{ value: "", label: "\u{f1720}  " + page.t("mx.virtual") }]
                .concat(page.eqOn ? [{ value: "soundhub_eq", label: "\u{f0ea2}  " + page.t("mx.viaEq", page.outLabel(page.eq.target)) }] : [])
                .concat(page.devices.map(function(o) {
                  return { value: o.name, label: Model.sinkGlyph(page.nodeByName(o.name)) + "  " + o.label
                                                 + (o.live === false ? "  · " + page.t("mx.offline") : "") }
                }))
              value: mc.modelData.output || ""
              foreground: page.fg; accent: mc.tint; fontFamily: page.ff
              onChanged: function(v) { if (v !== (mc.modelData.output || "")) page.cmd(["mix-set", mc.modelData.id, "output=" + v]) }
            }

            Flow {                                          // modifiers on the mix
              width: parent.width
              spacing: Style.space(6)
              Chip {
                readonly property bool eqOn: !!(mc.modelData.eq && mc.modelData.eq.enabled)
                label: "\u{f0ea2}  " + page.t("mx.modEq") + (eqOn ? "  ✓" : "")
                tint: mc.tint
                ink: page.bg
                on: eqOn
                ff: page.ff
                onClicked: page.cmd(["mix-eq", mc.modelData.id, "enabled=" + (eqOn ? "0" : "1")])
              }
              Chip {
                label: "\u{f0493}  " + page.t("mx.modEqEdit")
                tint: Qt.darker(page.fg, 1.3)
                ink: page.bg
                on: false
                ff: page.ff
                onClicked: if (host && typeof host.openEqFor === "function") host.openEqFor(mc.modelData.id)
              }
            }

            Chip {                                          // EQ on, but this mix skips it
              visible: page.eqOn && !!mc.modelData.output && mc.modelData.output !== "soundhub_eq"
                       && !(mc.modelData.eq && mc.modelData.eq.enabled)
              label: "\u{f0026}  " + page.t("mx.bypassEq")
              tint: page.urgent
              ink: page.bg
              on: true
              ff: page.ff
              onClicked: page.cmd(["mix-set", mc.modelData.id, "output=soundhub_eq"])
            }

            // inputs: per-source level, mute, remove
            Text {
              visible: mc.inputs.length === 0
              width: parent.width; wrapMode: Text.Wrap
              text: page.t("mx.noInputs")
              color: Qt.darker(page.fg, 1.6)
              font.family: page.ff; font.pixelSize: Style.font.caption
            }
            Repeater {
              model: mc.inputs
              delegate: Row {
                id: inRow
                required property var modelData
                readonly property real gain: modelData.gain === undefined ? 1 : modelData.gain
                width: mcCol.width
                spacing: Style.space(4)
                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  width: Style.space(78)
                  text: page.sourceLabel(inRow.modelData.src)
                  color: inRow.modelData.muted ? Qt.darker(page.fg, 1.8) : page.fg
                  font.family: page.ff; font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                }
                HubSlider {
                  anchors.verticalCenter: parent.verticalCenter
                  width: parent.width - Style.space(78) - Style.space(26) * 2 - parent.spacing * 3
                  minimum: 0; maximum: 1.5; step: 0.05
                  value: inRow.gain
                  trackHeight: 3; knobSize: 10
                  enabled: !inRow.modelData.muted
                  opacity: enabled ? 1 : 0.4
                  fillColor: mc.tint
              fontFamily: page.ff
                  onReleased: function(v) { page.cmd(["cable-set", inRow.modelData.src, mc.modelData.id, "gain=" + v.toFixed(2)]) }
                }
                PanelActionButton {
                  anchors.verticalCenter: parent.verticalCenter
                  size: Style.space(26)
                  iconText: inRow.modelData.muted ? "\u{f0581}" : "\u{f057e}"
                  foreground: inRow.modelData.muted ? page.urgent : Qt.darker(page.fg, 1.4)
                  hoverColor: mc.tint; fontFamily: page.ff
                  onClicked: page.cmd(["cable-set", inRow.modelData.src, mc.modelData.id, "muted=" + (inRow.modelData.muted ? "0" : "1")])
                }
                PanelActionButton {
                  anchors.verticalCenter: parent.verticalCenter
                  size: Style.space(26)
                  iconText: "\u{f0156}"
                  tooltipText: page.t("mx.disconnect")
                  foreground: Qt.darker(page.fg, 1.4)
                  hoverColor: page.urgent; fontFamily: page.ff
                  onClicked: page.cmd(["cable-remove", inRow.modelData.src, mc.modelData.id])
                }
              }
            }
          }

          Dot {
            registry: page
            regKey: "mixin:" + mc.modelData.id
            tint: mc.tint
            anchors.left: parent.left; anchors.leftMargin: -width / 2
            y: Style.space(22) - height / 2
          }
          Dot {
            registry: page
            regKey: "mixout:" + mc.modelData.id
            tint: mc.tint
            anchors.right: parent.right; anchors.rightMargin: -width / 2
            y: Style.space(22) - height / 2
            MouseArea {
              id: mixDrag
              anchors.fill: parent; anchors.margins: -6
              cursorShape: Qt.CrossCursor
              preventStealing: true
              onPressed: function(m) { page.startDrag("mix", mc.modelData.id, mixDrag, m) }
              onPositionChanged: function(m) { if (pressed) page.moveDrag(mixDrag, m) }
              onReleased: page.endDrag()
            }
          }
        }
      }
    }
  }

  // ======== OUTPUTS ========
  Header { y: page.barH; x: (page.colW + page.gutter) * 2; width: page.colW; text: page.t("mx.outputs"); fg: page.fg; ff: page.ff }
  Flickable {
    x: (page.colW + page.gutter) * 2; y: page.barH + page.headH
    width: page.colW; height: page.height - page.barH - page.headH
    contentHeight: outCol.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    onContentYChanged: page.relayout()

    Column {
      id: outCol
      width: parent.width
      spacing: Style.space(8)

      AddFolder { owner: page; kind: "out" }

      Text {
        visible: page.editing
        width: parent.width; wrapMode: Text.Wrap
        text: page.t("mx.editHint")
        color: page.accent
        font.family: page.ff; font.pixelSize: Style.font.caption
      }

      Component {
        id: outCard
        Rectangle {
          id: oc
          required property var modelData
          readonly property var node: page.nodeByName(modelData.name)
          readonly property real vol: node && node.audio ? node.audio.volume : 0
          readonly property bool muted: node && node.audio ? node.audio.muted : false
          readonly property bool active: modelData.name === page.activeOut
          readonly property bool online: modelData.live !== false
          readonly property var folder: page.folderOf("out", modelData.name)
          width: outCol.width
          height: ocCol.implicitHeight + Style.space(16)
          radius: page.radius
          color: active ? page.fill(page.accent, 0.10) : page.fill(page.fg, 0.045)
          opacity: online ? 1 : 0.5
          border.width: active ? 2 : 1
          border.color: active ? page.accent : Qt.rgba(page.fg.r, page.fg.g, page.fg.b, 0.07)

          MouseArea {                                    // click the card = play sound here
            anchors.fill: parent
            enabled: !oc.active && !page.editing && oc.online
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: page.useDevice(oc.modelData.name)
          }

          Column {
            id: ocCol
            x: Style.space(12); y: Style.space(8)
            width: parent.width - Style.space(22)
            spacing: Style.space(6)

            Row {
              width: parent.width
              spacing: Style.space(8)
              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Model.sinkGlyph(oc.node)
                color: oc.active ? page.accent : Qt.darker(page.fg, 1.3)
                font.family: page.ff; font.pixelSize: Style.space(16)
              }
              Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - Style.space(16) - Style.space(30) - parent.spacing * 2
                text: oc.modelData.label
                color: page.fg
                font.family: page.ff; font.pixelSize: Style.font.body; font.bold: oc.active
                elide: Text.ElideRight
              }
              PanelActionButton {
                anchors.verticalCenter: parent.verticalCenter
                iconText: oc.muted ? "\u{f0581}" : Model.volumeGlyph(oc.vol, false)
                tooltipText: page.t("snd.mute")
                foreground: oc.muted ? page.urgent : Qt.darker(page.fg, 1.2)
                hoverColor: page.accent; fontFamily: page.ff
                onClicked: if (oc.node && oc.node.audio) oc.node.audio.muted = !oc.muted
              }
            }

            Chip {                                         // edit mode: this device's tag
              visible: page.editing
              label: "\u{f024b} " + (oc.folder ? oc.folder.name : page.t("mx.folderNone"))
              tint: page.accent
              ink: page.bg
              on: oc.folder !== null
              ff: page.ff
              onClicked: page.cycleFolder("out", oc.modelData.name)
            }
            Text {                                         // unplugged: kept so it isn't lost
              visible: !oc.online
              text: "\u{f06a6}  " + page.t("mx.offline")
              color: Qt.darker(page.fg, 1.3)
              font.family: page.ff; font.pixelSize: Style.font.caption
            }
            Row {                                          // "sound plays here" + EQ switch
              visible: oc.active
              spacing: Style.space(6)
              Rectangle {
                height: liveText.implicitHeight + Style.space(6)
                width: liveText.implicitWidth + Style.space(14)
                radius: height / 2
                color: page.accent
                Text {
                  id: liveText
                  anchors.centerIn: parent
                  text: "\u{f057e}  " + page.t("mx.activeHere")
                  color: page.bg
                  font.family: page.ff; font.pixelSize: Style.font.caption - 1; font.bold: true
                }
              }
              Chip {
                label: "\u{f0ea2}  " + (page.eqOn ? page.t("mx.eqOn") : page.t("mx.eqOff"))
                tint: page.accent
                ink: page.bg
                on: page.eqOn
                ff: page.ff
                onClicked: page.toggleEq()
              }
            }

            HubSlider {
              visible: oc.node !== null
              width: parent.width
              minimum: 0; maximum: 1
              value: oc.vol
              trackHeight: 3; knobSize: 10
              fillColor: page.accent
              fontFamily: page.ff
              onMoved: function(v) { if (oc.node && oc.node.audio) oc.node.audio.volume = v }
            }
          }

          Dot {
            registry: page
            regKey: "out:" + oc.modelData.name
            tint: oc.active ? page.accent : Qt.darker(page.fg, 1.5)
            anchors.left: parent.left; anchors.leftMargin: -width / 2
            y: Style.space(21) - height / 2
          }
        }
      }

      Repeater {                                    // loose devices, then each folder
        model: page.sections("out", page.devices, function(o) { return o.name })
        delegate: Column {
          id: osec
          required property var modelData
          width: outCol.width
          spacing: Style.space(8)
          visible: modelData.folder !== null || modelData.items.length > 0
          FolderHead { owner: page; kind: "out"; folder: osec.modelData.folder; count: osec.modelData.items.length; visible: osec.modelData.folder !== null }
          Repeater {
            model: osec.modelData.items.filter(function(o) {
              return !osec.modelData.folder || !osec.modelData.folder.collapsed || o.name === page.activeOut
            })
            delegate: outCard
          }
        }
      }
    }
  }
}
