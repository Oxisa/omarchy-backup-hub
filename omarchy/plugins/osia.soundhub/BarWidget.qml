import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.Commons
import qs.Ui

// SoundHub in the bar: a live spectrum (flat line while silent).
//   left click   open / close the SoundHub panel
//   wheel        previous / next spectrum style
//   middle click next style
//   right click  next colour palette
// Hover names the current style and palette.
// The widget owns the shared pieces — one cava capture and the media shim —
// and hands them to the panel.
BarWidget {
  id: root
  moduleName: "osia.soundhub"

  readonly property var media: mediaShim
  readonly property var player: media.activePlayer
  readonly property bool playing: player !== null && !!player.isPlaying
  // Real audio, independent of MPRIS: browsers often report another tab's
  // state (YouTube Music playing while MPRIS says "Paused"). Any app playback
  // stream counts; our own plumbing (EQ, mixes, sends) doesn't.
  readonly property bool audioActive: {
    var n = Pipewire.nodes ? Pipewire.nodes.values : []
    for (var i = 0; i < n.length; i++) {
      var x = n[i]
      if (!x || !x.isStream || !x.isSink) continue
      var nm = String(x.name || "")
      if (nm.indexOf("soundhub_") === 0 || nm.indexOf("omarchy_") === 0 || nm.indexOf("cava") === 0) continue
      return true
    }
    return false
  }

  readonly property var styles: ["bars", "dots", "beads", "glow", "spikes", "steps", "wave"]
  readonly property var palettes: ["accent", "foreground", "muted", "gradient", "spectrum", "cover"]
  readonly property string barStyle: String(setting("barStyle", "bars"))
  readonly property string barPalette: String(setting("barPalette", "accent"))
  readonly property string barMode: String(setting("barMode", "bottom"))

  function persistBar(values) {
    var e = { id: moduleName }
    for (var k in settings) if (k !== "id") e[k] = settings[k]
    for (var key in values) e[key] = values[key]
    settings = e
    if (bar && bar.shell && typeof bar.shell.updateEntryInline === "function") bar.shell.updateEntryInline(moduleName, e)
  }
  function cycle(list, current, delta) {
    var i = list.indexOf(current)
    return list[((i < 0 ? 0 : i) + delta + list.length) % list.length]
  }
  function cycleStyle(d) { persistBar({ barStyle: cycle(styles, barStyle, d) }) }
  function cyclePalette(d) { persistBar({ barPalette: cycle(palettes, barPalette, d) }) }

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  function open()   { if (panelLoader.item) panelLoader.item.open() }
  function close()  { if (panelLoader.item) panelLoader.item.close() }
  function togglePanel() { if (panelLoader.item) panelLoader.item.toggle() }
  function openTab(i) { if (panelLoader.item) panelLoader.item.openTab(i) }

  // popout coordination, as in the built-in widgets
  readonly property real openPanelIndicatorWidth: Style.bar.iconCanvas
  readonly property real openPanelIndicatorHeight: Math.max(Style.space(10), Math.round(Style.bar.iconSlot * 0.55))
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch() }

  Media {
    id: mediaShim
    service: root.bar && root.bar.shell && typeof root.bar.shell.firstPartyServiceFor === "function"
             ? root.bar.shell.firstPartyServiceFor("omarchy.media") : null
  }

  // One shell-wide capture (CavaHub); this bar asks for it while audio plays.
  readonly property var cava: CavaHub
  readonly property string cavaKey: "bar-" + Math.random().toString(36).slice(2)
  readonly property bool wantSpectrum: root.playing || root.audioActive
  onWantSpectrumChanged: CavaHub.want(cavaKey, wantSpectrum)
  Component.onCompleted: CavaHub.want(cavaKey, wantSpectrum)
  Component.onDestruction: CavaHub.want(cavaKey, false)

  // Keep the EQ on its device: when an output appears (Bluetooth reconnect,
  // USB plugged back), let the backend move the EQ back to its target.
  readonly property int sinkCount: {
    var n = Pipewire.nodes ? Pipewire.nodes.values : [], c = 0
    for (var i = 0; i < n.length; i++) if (n[i] && n[i].isSink && !n[i].isStream) c++
    return c
  }
  onSinkCountChanged: ensureTimer.restart()
  Timer {
    id: ensureTimer
    interval: 1500
    onTriggered: Quickshell.execDetached([String(Qt.resolvedUrl("bin/soundhub-eq")).replace("file://", ""), "ensure"])
  }

  // ambient focus mixer: lives here so it keeps playing with the panel closed
  FocusState { id: focusState }

  function injectPanel() {
    var t = panelLoader.item
    if (!t) return
    if ("bar" in t) t.bar = root.bar
    if ("settings" in t) t.settings = root.settings
    if ("anchorItem" in t) t.anchorItem = button
    if ("hostWidget" in t) t.hostWidget = root
    if ("cava" in t) t.cava = cava
    if ("media" in t) t.media = mediaShim
    if ("ambient" in t) t.ambient = focusState
  }
  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: { root.injectPanel(); Qt.callLater(root.injectPanel) }
  }

  // track-change notice (opt-in)
  property string lastTrack: ""
  readonly property string trackSig: player ? (player.trackTitle || "") + "\u0001" + (player.trackArtist || "") : ""
  onTrackSigChanged: {
    if (!trackSig || trackSig === lastTrack) return
    var first = lastTrack === ""
    lastTrack = trackSig
    if (first || !playing || setting("notify", false) !== true) return
    Quickshell.execDetached(["omarchy-notification-send", "-g", "󰝚",
                             player.trackTitle || "", player.trackArtist || ""])
  }

  IpcHandler {
    target: "osia.soundhub"
    function toggle(): void { root.togglePanel() }
    function open(): void { root.open() }
    function close(): void { root.close() }
    function playing(): void { root.openTab(0) }
    function sound(): void { root.openTab(1) }
    function mixer(): void { root.openTab(1) }
    function equalizer(): void { root.openTab(2) }
    function focus(): void { root.openTab(3) }
    function settings(): void { root.openTab(4) }
    function cycleStyle(): void { root.cycleStyle(1) }
    function previousStyle(): void { root.cycleStyle(-1) }
    function cycleColor(): void { root.cyclePalette(1) }
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  CoverColors {
    id: cover
    source: root.barPalette === "cover" && root.player ? (root.player.trackArtUrl || "") : ""
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    hasVisualContent: true
    tooltipText: "SoundHub · " + root.barStyle + " · " + root.barPalette
    implicitWidth: Style.space(148)

    Spectrum {
      anchors.centerIn: parent
      width: parent.width - Style.space(8)
      height: Math.round(Style.bar.iconFont * 1.05)
      levels: cava.levels.slice(0, 28)
      style: root.barStyle
      mode: root.barMode
      palette: root.barPalette
      accent: Color.accent
      fg: button.foreground
      coverColors: cover.colors
      gap: 1
      minLevel: 0.06
      opacity: root.playing || root.audioActive ? 1 : 0.45
    }

    onPressed: function(b) {
      if (b === Qt.MiddleButton) root.cycleStyle(1)
      else if (b === Qt.RightButton) root.cyclePalette(1)
      else root.togglePanel()
    }
  }

  WheelHandler {
    target: null
    onWheel: function(e) { root.cycleStyle(e.angleDelta.y > 0 ? 1 : -1) }
  }
}
