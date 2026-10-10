import QtQuick
import Quickshell.Services.Mpris
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Now playing: album sleeve + spinning record, track info, seek, transport,
// player volume, live spectrum and the source picker. Player selection and
// actions go through Omarchy's own media service, so SoundHub always agrees
// with the bar and the media keys about which player is "the" player.
Column {
  id: page
  property var host: null
  property bool showSpectrum: true          // false when the spectrum sits under the lyrics
  property bool stacked: false              // two-column page: art centred, info below it
  spacing: Style.spacing.md

  readonly property var media: host ? host.media : null
  readonly property var player: media ? media.activePlayer : null
  readonly property var sources: media ? media.sourcePlayers : []
  readonly property bool hasTrack: player !== null && !!(player.trackTitle || player.trackArtist)
  readonly property bool playing: player !== null && !!player.isPlaying
  readonly property color fg: host ? host.fg : "white"
  readonly property color accent: host ? host.accent : "white"
  readonly property string ff: host ? host.ff : ""

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
  property bool seeking: false
  property real seekRatio: 0
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

  // ---- record + info ----
  Item {
    visible: page.hasTrack
    width: parent.width
    height: Style.space(196)

    // stacked: centre the sleeve + record group in the column
    readonly property real artWidth: sleeve.width * 0.55 + vinyl.implicitWidth

    // sleeve: the album cover the record slides out of
    Rectangle {
      id: sleeve
      width: Style.space(176)
      height: width
      x: page.stacked ? Math.max(0, (parent.width - parent.artWidth) / 2) : 0
      anchors.verticalCenter: parent.verticalCenter
      radius: Math.min(Style.cornerRadius, 6)
      color: Qt.rgba(page.fg.r, page.fg.g, page.fg.b, 0.08)
      clip: true
      z: 2
      Image {
        anchors.fill: parent
        source: page.player ? (page.player.trackArtUrl || "") : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize: Qt.size(width * 2, height * 2)
      }
      Text {
        anchors.centerIn: parent
        visible: !page.player || !page.player.trackArtUrl
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
      artUrl: page.player ? (page.player.trackArtUrl || "") : ""
      playing: page.playing
      progress: page.progress
      pressing: host ? String(host.opt("pressing", "theme")) : "theme"
      accent: page.accent; fg: page.fg; bg: host ? host.bgc : "black"
    }

    Column {
      visible: !page.stacked
      anchors.left: vinyl.right
      anchors.leftMargin: Style.spacing.md
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(4)

      Text {
        width: parent.width
        text: page.player ? (page.player.trackTitle || "") : ""
        color: page.fg
        font.family: page.ff; font.pixelSize: Style.font.title; font.bold: true
        wrapMode: Text.Wrap; maximumLineCount: 3; elide: Text.ElideRight
      }
      Text {
        width: parent.width
        text: page.player ? (page.player.trackArtist || (host ? host.t("np.unknownArtist") : "")) : ""
        color: page.accent
        font.family: page.ff; font.pixelSize: Style.font.body
        elide: Text.ElideRight
      }
      Text {
        width: parent.width
        visible: text !== ""
        text: page.player ? (page.player.trackAlbum || "") : ""
        color: Qt.darker(page.fg, 1.5)
        font.family: page.ff; font.pixelSize: Style.font.caption
        elide: Text.ElideRight
      }
    }
  }

  // ---- stacked: track info centred under the art ----
  Column {
    visible: page.hasTrack && page.stacked
    width: parent.width
    spacing: Style.space(3)
    Text {
      width: parent.width
      horizontalAlignment: Text.AlignHCenter
      text: page.player ? (page.player.trackTitle || "") : ""
      color: page.fg
      font.family: page.ff; font.pixelSize: Style.font.title + 2; font.bold: true
      wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight
    }
    Text {
      width: parent.width
      horizontalAlignment: Text.AlignHCenter
      text: (page.player ? (page.player.trackArtist || (host ? host.t("np.unknownArtist") : "")) : "")
            + (page.player && page.player.trackAlbum ? "  ·  " + page.player.trackAlbum : "")
      color: page.accent
      font.family: page.ff; font.pixelSize: Style.font.body
      elide: Text.ElideRight
    }
  }

  // ---- seek ----
  Item {
    visible: page.hasTrack
    width: parent.width
    height: Style.space(28)

    Rectangle {
      id: track
      anchors.left: parent.left; anchors.right: parent.right
      anchors.top: parent.top; anchors.topMargin: Style.space(4)
      height: Style.space(4)
      radius: height / 2
      color: Qt.rgba(page.fg.r, page.fg.g, page.fg.b, page.canSeek ? 0.18 : 0.08)
      Rectangle {
        width: parent.width * page.progress
        height: parent.height
        radius: height / 2
        color: page.accent
      }
      Rectangle {
        visible: page.canSeek && (seekMouse.containsMouse || page.seeking)
        width: Style.space(12); height: width; radius: width / 2
        x: parent.width * page.progress - width / 2
        anchors.verticalCenter: parent.verticalCenter
        color: page.accent
      }
    }
    MouseArea {
      id: seekMouse
      anchors.fill: track
      anchors.margins: -Style.space(8)
      enabled: page.canSeek
      hoverEnabled: true
      cursorShape: page.canSeek ? Qt.PointingHandCursor : Qt.ArrowCursor
      function ratioAt(x) { return Math.max(0, Math.min(1, (x - Style.space(8)) / track.width)) }
      onPressed: function(e) { page.seeking = true; page.seekRatio = ratioAt(e.x) }
      onPositionChanged: function(e) { if (page.seeking) page.seekRatio = ratioAt(e.x) }
      onReleased: {
        if (page.player && page.canSeek) page.seekTo(page.seekRatio * page.length)
        page.seeking = false
      }
    }
    Text {
      anchors.left: parent.left; anchors.bottom: parent.bottom
      text: Model.fmtTime(page.seeking ? page.seekRatio * page.length : page.position)
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

  // ---- transport ----
  Item {
    visible: page.hasTrack
    width: parent.width
    height: Style.space(44)

    Row {
      anchors.centerIn: parent
      spacing: Style.space(14)

      PanelActionButton {
        anchors.verticalCenter: parent.verticalCenter
        iconText: "󰒝"
        tooltipText: host ? host.t("np.shuffle") : ""
        enabled: page.player !== null && !!page.player.shuffleSupported
        opacity: enabled ? 1 : 0.35
        foreground: page.player && page.player.shuffle ? page.accent : page.fg
        hoverColor: page.accent
        fontFamily: page.ff
        onClicked: page.player.shuffle = !page.player.shuffle
      }
      PanelActionButton {
        anchors.verticalCenter: parent.verticalCenter
        iconText: "󰒮"
        tooltipText: host ? host.t("np.prev") : ""
        foreground: page.fg; hoverColor: page.accent; fontFamily: page.ff
        onClicked: page.act("previous")
      }
      Rectangle {
        width: Style.space(44); height: width; radius: width / 2
        color: page.accent
        Text {
          anchors.centerIn: parent
          text: page.playing ? "󰏤" : "󰐊"
          color: host ? host.bgc : "black"
          font.family: page.ff; font.pixelSize: Style.space(22)
        }
        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: page.act("playPause")
        }
      }
      PanelActionButton {
        anchors.verticalCenter: parent.verticalCenter
        iconText: "󰒭"
        tooltipText: host ? host.t("np.next") : ""
        foreground: page.fg; hoverColor: page.accent; fontFamily: page.ff
        onClicked: page.act("next")
      }
      PanelActionButton {
        anchors.verticalCenter: parent.verticalCenter
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

  // ---- player volume ----
  Row {
    visible: page.hasTrack && page.player !== null && !!page.player.volumeSupported
    width: parent.width
    spacing: Style.spacing.sm
    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: Model.volumeGlyph(page.player ? page.player.volume : 0, false)
      color: page.fg
      font.family: page.ff; font.pixelSize: Style.font.icon
    }
    HubSlider {
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width - Style.space(40)
      minimum: 0; maximum: 1
      value: page.player ? page.player.volume : 0
      fillColor: page.accent
      onMoved: function(v) { if (page.player) page.player.volume = v }
    }
  }

  // ---- spectrum ----
  Spectrum {
    visible: page.hasTrack && page.showSpectrum
    width: parent.width
    height: Style.space(40)
    levels: host && host.cava ? host.cava.levels : []
    style: host ? String(host.opt("spectrumStyle", "bars")) : "bars"
    color: Qt.rgba(page.accent.r, page.accent.g, page.accent.b, 0.55)
    colorTop: page.accent
  }

  // ---- source picker ----
  Dropdown {
    visible: page.sources.length > 1
    width: parent.width
    label: host ? host.t("np.source") : ""
    options: page.sources.map(function(p) {
      return { value: page.media.playerKey(p), label: page.media.labelFor(p) + (p.isPlaying ? "  ▶" : "") }
    })
    value: page.media && page.player ? page.media.playerKey(page.player) : ""
    foreground: page.fg
    accent: page.accent
    fontFamily: page.ff
    onChanged: function(v) { if (page.media) page.media.selectPlayer(v) }
  }
}
