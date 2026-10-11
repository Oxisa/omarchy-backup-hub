import QtQuick
import Quickshell.Services.Mpris
import Quickshell.Widgets
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Now playing: art (spinning record or square cover), track info, a
// pseudo-waveform seek bar and transport. Player selection and
// actions go through Omarchy's own media service, so SoundHub always agrees
// with the bar and the media keys about which player is "the" player.
Column {
  id: page
  property var host: null
  property string look: "vinyl"             // "vinyl": record + sleeve, "cover": square art
  spacing: Style.spacing.md

  readonly property var media: host ? host.media : null
  readonly property var player: media ? media.activePlayer : null
  readonly property var sources: media ? media.sourcePlayers : []
  readonly property bool hasTrack: player !== null && !!(player.trackTitle || player.trackArtist)
  readonly property bool playing: player !== null && !!player.isPlaying
  readonly property color fg: host ? host.fg : "white"
  readonly property color accent: host ? host.accent : "white"
  readonly property string ff: host ? host.ff : ""
  readonly property string artUrl: player ? (player.trackArtUrl || "") : ""

  // Browser players (YouTube Music in Brave/Chromium) briefly report length 0
  // or CanSeek=false right after a seek. Remember, per track, the last real
  // length and that seeking worked, so the bar doesn't lock up on that blip.
  readonly property string trackId: player ? (player.trackTitle || "") + "\u0001" + (player.trackArtist || "") : ""
  property real knownLength: 0
  property bool seekWorked: false
  onTrackIdChanged: { knownLength = 0; seekWorked = false }
  readonly property real liveLength: player && player.lengthSupported ? player.length : 0
  onLiveLengthChanged: if (liveLength > 0) knownLength = liveLength
  readonly property bool liveCanSeek: player !== null && !!player.canSeek && !!player.positionSupported
                                      && !!player.lengthSupported && liveLength > 0
  onLiveCanSeekChanged: if (liveCanSeek) seekWorked = true
  readonly property bool canSeek: player !== null && (liveCanSeek || (seekWorked && knownLength > 0))
  readonly property bool seeking: track.dragging
  readonly property real seekRatio: track.dragRatio
  property real position: player ? player.position : 0
  readonly property real length: liveLength > 0 ? liveLength : knownLength

  // Absolute SetPosition can be ignored by a player whose track id changed
  // under us; if the position didn't land, fall back to a relative seek.
  property real seekTarget: -1
  function seekTo(target) {
    if (!player) return
    seekTarget = target
    player.position = target
    position = target
    seekCheck.restart()
  }
  Timer {
    id: seekCheck
    interval: 700
    onTriggered: {
      var p = page.player
      if (!p || page.seekTarget < 0) return
      p.positionChanged()
      var off = page.seekTarget - p.position
      if (Math.abs(off) > 3 && typeof p.seek === "function") p.seek(off)
      page.position = page.seekTarget
      page.seekTarget = -1
    }
  }
  readonly property real progress: length > 0 ? Math.max(0, Math.min(1, (seeking ? seekRatio * length : position) / length)) : 0

  function act(name) {
    if (media) media.runAction(name, false, media.playerKey(player))
  }

  // Quickshell only pushes position on jumps: poke it while visible + playing.
  Timer {
    interval: 1000
    repeat: true
    running: page.visible && page.playing && !page.seeking
    triggeredOnStart: true
    onTriggered: if (page.player) { page.player.positionChanged(); page.position = page.player.position }
  }
  onPlayerChanged: position = player ? player.position : 0

  // ---- empty state ----
  Column {
    visible: !page.hasTrack
    width: parent.width
    spacing: Style.spacing.sm
    topPadding: Style.space(24)
    bottomPadding: Style.space(24)

    Vinyl {
      anchors.horizontalCenter: parent.horizontalCenter
      size: Style.space(120)
      showArm: false
      pressing: host ? String(host.opt("pressing", "theme")) : "theme"
      accent: page.accent; fg: page.fg; bg: host ? host.bgc : "black"
      opacity: 0.6
    }
    Text {
      width: parent.width
      horizontalAlignment: Text.AlignHCenter
      text: host ? host.t("np.nothing") : ""
      color: page.fg
      font.family: page.ff; font.pixelSize: Style.font.title; font.bold: true
    }
    Text {
      width: parent.width
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.Wrap
      text: host ? host.t("np.nothingHint") : ""
      color: Qt.darker(page.fg, 1.5)
      font.family: page.ff; font.pixelSize: Style.font.caption
    }
  }

  // ---- art: spinning record (look "vinyl") or a square cover (look "cover") ----
  Item {
    visible: page.hasTrack && page.look === "vinyl"
    width: parent.width
    height: Style.space(196)

    // centre the sleeve + record group in the column
    readonly property real artWidth: sleeve.width * 0.55 + vinyl.implicitWidth

    // sleeve: the album cover the record slides out of
    Rectangle {
      id: sleeve
      width: Style.space(176)
      height: width
      x: Math.max(0, (parent.width - parent.artWidth) / 2)
      anchors.verticalCenter: parent.verticalCenter
      radius: Math.min(Style.cornerRadius, 6)
      color: Qt.rgba(page.fg.r, page.fg.g, page.fg.b, 0.08)
      clip: true
      z: 2
      Image {
        anchors.fill: parent
        source: page.artUrl
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize: Qt.size(width * 2, height * 2)
      }
      Text {
        anchors.centerIn: parent
        visible: page.artUrl === ""
        text: "󰝚"
        color: Qt.darker(page.fg, 1.6)
        font.family: page.ff; font.pixelSize: Style.space(48)
      }
    }

    Vinyl {
      id: vinyl
      size: Style.space(172)
      anchors.verticalCenter: parent.verticalCenter
      // slides out of the sleeve while playing
      x: sleeve.x + (page.playing ? sleeve.width * 0.55 : sleeve.width * 0.18)
      Behavior on x { NumberAnimation { duration: 650; easing.type: Easing.OutCubic } }
      z: 1
      artUrl: page.artUrl
      playing: page.playing
      progress: page.progress
      pressing: host ? String(host.opt("pressing", "theme")) : "theme"
      accent: page.accent; fg: page.fg; bg: host ? host.bgc : "black"
    }
  }

  ClippingRectangle {
    visible: page.hasTrack && page.look === "cover"
    anchors.horizontalCenter: parent.horizontalCenter
    width: Math.min(parent.width - Style.space(40), Style.space(300))
    height: width
    radius: Math.max(6, Math.min(Style.cornerRadius, 12))
    color: Qt.rgba(page.fg.r, page.fg.g, page.fg.b, 0.08)
    Image {
      anchors.fill: parent
      source: page.artUrl
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      sourceSize: Qt.size(width * 2, height * 2)
      opacity: status === Image.Ready ? 1 : 0
      Behavior on opacity { NumberAnimation { duration: 250 } }
    }
    Text {
      anchors.centerIn: parent
      visible: page.artUrl === ""
      text: "󰝚"
      color: Qt.darker(page.fg, 1.6)
      font.family: page.ff; font.pixelSize: Style.space(64)
    }
  }

  // ---- track info ----
  Column {
    visible: page.hasTrack
    width: parent.width
    spacing: Style.space(3)
    Text {
      width: parent.width
      text: page.player ? (page.player.trackTitle || "") : ""
      color: page.fg
      font.family: page.ff; font.pixelSize: Style.font.title + 2; font.bold: true
      wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight
    }
    Text {
      width: parent.width
      text: (page.player ? (page.player.trackArtist || (host ? host.t("np.unknownArtist") : "")) : "")
            + (page.player && page.player.trackAlbum ? "  ·  " + page.player.trackAlbum : "")
      color: Qt.darker(page.fg, 1.3)
      font.family: page.ff; font.pixelSize: Style.font.body
      elide: Text.ElideRight
    }
    Text {
      width: parent.width
      visible: text !== ""
      text: page.media && page.player ? (host ? host.t("np.via", page.media.labelFor(page.player)) : "") : ""
      color: Qt.darker(page.fg, 1.8)
      font.family: page.ff; font.pixelSize: Style.font.caption
      elide: Text.ElideRight
    }
  }

  // ---- seek: progress in the chosen look (squiggle / wave / line) ----
  Item {
    visible: page.hasTrack
    width: parent.width
    height: Style.space(56)

    HubProgress {
      id: track
      anchors.left: parent.left; anchors.right: parent.right
      anchors.top: parent.top
      height: Style.space(34)
      progress: page.progress
      known: page.length > 0
      playing: page.playing
      canSeek: page.canSeek
      look: host ? String(host.opt("progressStyle", "squiggle")) : "squiggle"
      seed: page.trackId
      fg: page.fg; accent: page.accent
      onSeekTo: function(r) { if (page.player && page.canSeek) page.seekTo(r * page.length) }
    }
    Text {
      anchors.left: parent.left; anchors.bottom: parent.bottom
      text: Model.fmtTime(track.dragging ? track.dragRatio * page.length : page.position)
      color: Qt.darker(page.fg, 1.5)
      font.family: page.ff; font.pixelSize: Style.font.caption
    }
    Text {
      anchors.right: parent.right; anchors.bottom: parent.bottom
      text: page.length > 0 ? Model.fmtTime(page.length) : ""
      color: Qt.darker(page.fg, 1.5)
      font.family: page.ff; font.pixelSize: Style.font.caption
    }
  }

  // ---- transport: spread across the column ----
  Row {
    visible: page.hasTrack
    width: parent.width
    height: Style.space(48)
    readonly property real slot: width / 5

    Item {
      width: parent.slot; height: parent.height
      PanelActionButton {
        anchors.centerIn: parent
        iconText: "󰒝"
        tooltipText: host ? host.t("np.shuffle") : ""
        enabled: page.player !== null && !!page.player.shuffleSupported
        opacity: enabled ? 1 : 0.35
        foreground: page.player && page.player.shuffle ? page.accent : page.fg
        hoverColor: page.accent
        fontFamily: page.ff
        onClicked: page.player.shuffle = !page.player.shuffle
      }
    }
    Item {
      width: parent.slot; height: parent.height
      PanelActionButton {
        anchors.centerIn: parent
        iconText: "󰒮"
        tooltipText: host ? host.t("np.prev") : ""
        foreground: page.fg; hoverColor: page.accent; fontFamily: page.ff
        onClicked: page.act("previous")
      }
    }
    Item {
      width: parent.slot; height: parent.height
      Rectangle {
        anchors.centerIn: parent
        width: Style.space(46); height: width; radius: width / 2
        color: playMouse.containsMouse ? Qt.rgba(page.accent.r, page.accent.g, page.accent.b, 0.22)
                                       : Qt.rgba(page.fg.r, page.fg.g, page.fg.b, 0.08)
        Behavior on color { ColorAnimation { duration: 120 } }
        Text {
          anchors.centerIn: parent
          text: page.playing ? "󰏤" : "󰐊"
          color: playMouse.containsMouse ? page.accent : page.fg
          font.family: page.ff; font.pixelSize: Style.space(26)
        }
        MouseArea {
          id: playMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: page.act("playPause")
        }
      }
    }
    Item {
      width: parent.slot; height: parent.height
      PanelActionButton {
        anchors.centerIn: parent
        iconText: "󰒭"
        tooltipText: host ? host.t("np.next") : ""
        foreground: page.fg; hoverColor: page.accent; fontFamily: page.ff
        onClicked: page.act("next")
      }
    }
    Item {
      width: parent.slot; height: parent.height
      PanelActionButton {
        anchors.centerIn: parent
        readonly property int loop: page.player ? page.player.loopState : MprisLoopState.None
        iconText: loop === MprisLoopState.Track ? "󰑘" : "󰑖"
        tooltipText: host ? host.t("np.repeat") : ""
        enabled: page.player !== null && !!page.player.loopSupported
        opacity: enabled ? 1 : 0.35
        foreground: loop !== MprisLoopState.None ? page.accent : page.fg
        hoverColor: page.accent
        fontFamily: page.ff
        onClicked: {
          var p = page.player
          if (p.loopState === MprisLoopState.None) p.loopState = MprisLoopState.Playlist
          else if (p.loopState === MprisLoopState.Playlist) p.loopState = MprisLoopState.Track
          else p.loopState = MprisLoopState.None
        }
      }
    }
  }
}
