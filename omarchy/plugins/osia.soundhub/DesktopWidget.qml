import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Mpris
import Quickshell.Widgets
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Now playing on the desktop: a compact SoundHub card above the wallpaper
// (WlrLayer.Bottom, so windows cover it), placed at one of nine spots —
// corners, sides or centre — on one monitor. Art (record or cover, as chosen
// for the Now Playing tab), title, artist, a pseudo-waveform you can click to
// seek, and transport. Shown only while there is a track; fades in and out.
// Only the card takes clicks; the rest of the desktop stays click-through.
PanelWindow {
  id: win
  property var host: null                   // the bar widget: media, settings
  property string place: "br"              // tl t tr l c r bl b br
  property real bgOpacity: 0.85

  readonly property var media: host ? host.media : null
  readonly property var player: media ? media.activePlayer : null
  readonly property bool hasTrack: player !== null && !!(player.trackTitle || player.trackArtist)
  readonly property color fg: Color.foreground
  readonly property color accent: Color.accent
  readonly property color bgc: Color.background
  readonly property string ff: Style.font.family
  readonly property real margin: Style.space(28)

  color: "transparent"
  WlrLayershell.namespace: "osia-soundhub-desktop"
  WlrLayershell.layer: WlrLayer.Bottom
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  exclusionMode: ExclusionMode.Normal        // keep clear of the bar

  anchors {
    top: place[0] === "t"
    bottom: place[0] === "b"
    left: place === "l" || place.slice(-1) === "l"
    right: place === "r" || place.slice(-1) === "r"
  }
  margins { top: win.margin; bottom: win.margin; left: win.margin; right: win.margin }

  implicitWidth: card.width
  implicitHeight: card.height
  // only the card takes clicks, and only while it is shown
  Region { id: cardRegion; item: card }
  Region { id: noRegion }
  mask: win.hasTrack ? cardRegion : noRegion

  Rectangle {
    id: card
    width: Style.space(400)
    height: mini.implicitHeight + Style.space(28)
    radius: HubStyle.radius + Style.space(4)
    color: Qt.rgba(win.bgc.r, win.bgc.g, win.bgc.b, win.bgOpacity)
    border.width: 1
    border.color: HubStyle.tint(win.fg, 0.08)
    opacity: win.hasTrack ? 1 : 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }

    MiniPlayer {
      id: mini
      x: Style.space(14); y: Style.space(14)
      width: parent.width - Style.space(28)
      host: win.host
    }
  }
}
