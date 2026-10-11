import QtQuick
import Quickshell.Services.Mpris
import Quickshell.Widgets
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Compact now-playing card body: art (record or cover), title, artist ·
// album, a pseudo-waveform you can click to seek, time and transport.
// Shared by the desktop widget and TheNotch's hover peek; the caller draws
// the card around it. `host` gives media and settings (setting(key, d)).
Item {
  id: mp
  property var host: null
  readonly property var media: host ? host.media : null
  readonly property var player: media ? media.activePlayer : null
  readonly property bool hasTrack: player !== null && !!(player.trackTitle || player.trackArtist)
  readonly property bool playing: player !== null && !!player.isPlaying
  readonly property string look: host ? String(host.setting("npLook", "vinyl")) : "vinyl"
  property color fg: Color.foreground
  property color accent: Color.accent
  property color bgc: Color.background
  property string ff: Style.font.family
  readonly property string artUrl: player ? (player.trackArtUrl || "") : ""

  implicitWidth: Style.space(372)
  implicitHeight: row.implicitHeight

  // ---- position / length / seek (same fallbacks as the panel) ----
  property real pos: player ? player.position : 0
  readonly property real length: player && player.lengthSupported ? player.length : 0
  readonly property bool canSeek: player !== null && !!player.canSeek && length > 0
  readonly property real progress: length > 0 ? Math.max(0, Math.min(1, pos / length)) : 0
  Timer {
    interval: 1000; repeat: true; triggeredOnStart: true
    running: mp.playing && mp.visible
    onTriggered: if (mp.player) { mp.player.positionChanged(); mp.pos = mp.player.position }
  }
  onPlayerChanged: pos = player ? player.position : 0
  function act(name) { if (media) media.runAction(name, false, media.playerKey(player)) }

  Row {
    id: row
    width: parent.width
    spacing: Style.space(14)

    // art: a spinning record or the square cover
    Item {
      id: art
      width: Style.space(104); height: width
      anchors.verticalCenter: parent.verticalCenter
      Vinyl {
        visible: mp.look === "vinyl"
        anchors.centerIn: parent
        size: parent.width
        showArm: false
        artUrl: mp.artUrl
        playing: mp.playing
        progress: mp.progress
        pressing: host ? String(host.setting("pressing", "theme")) : "theme"
        accent: mp.accent; fg: mp.fg; bg: mp.bgc
      }
      ClippingRectangle {
        visible: mp.look !== "vinyl"
        anchors.fill: parent
        radius: HubStyle.radiusSmall
        color: HubStyle.tint(mp.fg, 0.08)
        Image {
          anchors.fill: parent
          source: mp.artUrl
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          sourceSize: Qt.size(width * 2, height * 2)
        }
        Text {
          anchors.centerIn: parent
          visible: mp.artUrl === ""
          text: "󰝚"
          color: Qt.darker(mp.fg, 1.6)
          font.family: mp.ff; font.pixelSize: Style.space(36)
        }
      }
    }

    Column {
      width: parent.width - art.width - parent.spacing
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(4)

      Text {
        width: parent.width
        text: mp.player ? (mp.player.trackTitle || "") : ""
        color: mp.fg
        font.family: mp.ff; font.pixelSize: Style.font.title; font.bold: true
        elide: Text.ElideRight
      }
      Text {
        width: parent.width
        text: (mp.player ? (mp.player.trackArtist || "") : "")
              + (mp.player && mp.player.trackAlbum ? "  ·  " + mp.player.trackAlbum : "")
        color: Qt.darker(mp.fg, 1.3)
        font.family: mp.ff; font.pixelSize: Style.font.caption + 1
        elide: Text.ElideRight
      }

      // progress in the chosen look, click/drag to seek
      HubProgress {
        id: wave
        width: parent.width
        height: Style.space(24)
        progress: mp.progress
        known: mp.length > 0
        playing: mp.playing
        canSeek: mp.canSeek
        look: mp.host ? String(mp.host.setting("progressStyle", "squiggle")) : "squiggle"
        seed: mp.player ? (mp.player.trackTitle || "") + "\u0001" + (mp.player.trackArtist || "") : ""
        fg: mp.fg; accent: mp.accent
        onSeekTo: function(r) { var t = r * mp.length; mp.player.position = t; mp.pos = t }
      }

      Item {
        width: parent.width
        height: Style.space(30)
        Text {
          anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
          text: Model.fmtTime(mp.pos) + (mp.length > 0 ? " / " + Model.fmtTime(mp.length) : "")
          color: Qt.darker(mp.fg, 1.6)
          font.family: mp.ff; font.pixelSize: Style.font.caption - 1
        }
        Row {
          anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(4)
          PanelActionButton {
            anchors.verticalCenter: parent.verticalCenter
            iconText: "󰒮"
            foreground: mp.fg; hoverColor: mp.accent; fontFamily: mp.ff
            onClicked: mp.act("previous")
          }
          Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(32); height: width; radius: width / 2
            color: playMouse.containsMouse ? HubStyle.tint(mp.accent, 0.25) : HubStyle.tint(mp.fg, 0.08)
            Text {
              anchors.centerIn: parent
              text: mp.playing ? "󰏤" : "󰐊"
              color: playMouse.containsMouse ? mp.accent : mp.fg
              font.family: mp.ff; font.pixelSize: Style.space(18)
            }
            MouseArea {
              id: playMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: mp.act("playPause")
            }
          }
          PanelActionButton {
            anchors.verticalCenter: parent.verticalCenter
            iconText: "󰒭"
            foreground: mp.fg; hoverColor: mp.accent; fontFamily: mp.ff
            onClicked: mp.act("next")
          }
        }
      }
    }
  }
}
