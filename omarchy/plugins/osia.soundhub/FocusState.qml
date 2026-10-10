import QtQuick
import Quickshell
import Quickshell.Io

// Focus: Blanket-style ambient mixer, adapted from OmaFocus by xshubhamg (MIT).
// One `mpv --loop-file=inf` per active sound, reconciled by bin/soundhub-focus.
// Lives in the bar widget, so sounds keep playing with the panel closed.
// Selection and volumes persist; audio never starts on its own.
QtObject {
  id: state

  readonly property string pluginDir: decodeURIComponent(
    Qt.resolvedUrl("./").toString().replace(/^file:\/\//, "").replace(/\/$/, ""))
  readonly property string backend: pluginDir + "/bin/soundhub-focus"
  readonly property string stateFile: Quickshell.env("HOME") + "/.local/state/omarchy/soundhub-focus.json"

  // static catalog (never mutated, so Repeaters never rebuild mid-drag)
  readonly property var catalog: [
    { id: "rain",         glyph: "\u{f0596}" },
    { id: "storm",        glyph: "\u{f067e}" },
    { id: "wind",         glyph: "\u{f059d}" },
    { id: "waves",        glyph: "\u{f078d}" },
    { id: "stream",       glyph: "\u{f058c}" },
    { id: "birds",        glyph: "\u{f15c6}" },
    { id: "summer-night", glyph: "\u{f0594}" },
    { id: "train",        glyph: "\u{f052c}" },
    { id: "boat",         glyph: "\u{f0ec8}" },
    { id: "city",         glyph: "\u{f0146}" },
    { id: "coffee-shop",  glyph: "\u{f0176}" },
    { id: "fireplace",    glyph: "\u{f0238}" },
    { id: "white-noise",  glyph: "\u{f057e}" },
    { id: "pink-noise",   glyph: "\u{f095b}" }
  ]

  readonly property var defaultVolumes: ({
    "rain": 70, "storm": 60, "wind": 55, "waves": 65, "stream": 60, "birds": 55,
    "summer-night": 50, "train": 45, "boat": 45, "city": 50, "coffee-shop": 65,
    "fireplace": 60, "white-noise": 40, "pink-noise": 40
  })

  property var volumes: ({})
  property var selected: ({})
  property int master: 80
  property bool playing: false

  function volumeOf(id) {
    var v = volumes[id]
    if (v === undefined) v = defaultVolumes[id] !== undefined ? defaultVolumes[id] : 60
    return Math.max(0, Math.min(100, Math.round(Number(v) || 0)))
  }
  function isSelected(id) { return selected[id] === true }
  function selectedCount() {
    var n = 0
    for (var i = 0; i < catalog.length; ++i) if (isSelected(catalog[i].id)) ++n
    return n
  }
  function effectiveVolume(id) { return Math.max(0, Math.min(100, Math.round(volumeOf(id) * master / 100))) }

  function clone(o) { var r = {}; for (var k in o) r[k] = o[k]; return r }

  function toggleSound(id) {
    var next = !isSelected(id)
    var s = clone(selected); s[id] = next; selected = s
    if (next && volumeOf(id) <= 0) { var v = clone(volumes); v[id] = defaultVolumes[id] || 60; volumes = v }
    if (next) playing = true
    else if (selectedCount() === 0) playing = false
    save(); sync()
  }
  function previewVolume(id, v) { var c = clone(volumes); c[id] = Math.max(0, Math.min(100, Math.round(v))); volumes = c }
  function commitVolume(id, v) {
    previewVolume(id, v)
    if (volumes[id] > 0 && !isSelected(id)) { var s = clone(selected); s[id] = true; selected = s; playing = true }
    save(); sync()
  }
  function previewMaster(v) { master = Math.max(0, Math.min(100, Math.round(v))) }
  function commitMaster(v) { previewMaster(v); save(); sync() }
  function playAll() {
    if (selectedCount() === 0) { var s = clone(selected); s["rain"] = true; selected = s }
    playing = true; save(); sync()
  }
  function stopAll() { playing = false; save(); sync() }
  function clearAll() { selected = ({}); playing = false; save(); sync() }

  function shq(v) { return "'" + String(v).replace(/'/g, "'\\''") + "'" }

  // ---- backend ----
  property bool pendingSync: false
  function sync() {
    if (engineProc.running) { pendingSync = true; return }
    if (!playing || selectedCount() === 0) {
      engineProc.command = ["timeout", "20", backend, "stop"]
    } else {
      var args = ["timeout", "20", backend, "sync"]
      for (var i = 0; i < catalog.length; ++i) {
        var id = catalog[i].id
        if (isSelected(id)) args.push(id + ":" + effectiveVolume(id))
      }
      engineProc.command = args
    }
    engineProc.running = true
  }
  property Process engineProc: Process {
    onExited: if (state.pendingSync) { state.pendingSync = false; state.sync() }
  }

  // ---- persistence: atomic write, refuses symlinks ----
  function save() {
    var payload = JSON.stringify({ volumes: volumes, selected: selected, master: master })
    writeProc.command = ["timeout", "10", "bash", "-c",
      "set -u; F=" + shq(stateFile) + "; D=$(dirname \"$F\"); mkdir -p \"$D\"; " +
      "[ -L \"$F\" ] && exit 3; [ -L \"$D\" ] && exit 3; " +
      "T=$(mktemp \"$D/.soundhub-focus.XXXXXX\") || exit 1; " +
      "printf '%s' " + shq(payload) + " > \"$T\"; chmod 600 \"$T\"; mv -f \"$T\" \"$F\""]
    writeProc.running = true
  }
  property Process writeProc: Process {}

  property Process readProc: Process {
    command: ["timeout", "10", "bash", "-c",
      "F=" + state.shq(state.stateFile) + "; [ -L \"$F\" ] && { echo '{}'; exit 0; }; cat \"$F\" 2>/dev/null || echo '{}'"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var d = JSON.parse(text)
          if (d.volumes) state.volumes = d.volumes
          if (d.selected) {
            var clean = {}
            for (var i = 0; i < state.catalog.length; ++i) if (d.selected[state.catalog[i].id] === true) clean[state.catalog[i].id] = true
            state.selected = clean
          }
          if (isFinite(Number(d.master))) state.master = Math.max(0, Math.min(100, Math.round(Number(d.master))))
          state.playing = false                   // never autoplay
        } catch (e) {}
      }
    }
  }

  Component.onCompleted: {
    engineProc.command = ["timeout", "20", backend, "stop"]  // fresh shell: no stale audio
    engineProc.running = true
    readProc.running = true
  }
}
