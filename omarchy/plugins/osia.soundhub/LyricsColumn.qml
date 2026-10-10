import QtQuick
import QtQuick.Effects
import Quickshell.Io
import qs.Commons
import "Model.js" as Model

// Lyrics for the playing track (LRCLIB via bin/soundhub-lyrics, cached).
// Synced lyrics follow playback: the current line is highlighted and kept in
// view; a click on a line seeks there. Plain lyrics scroll freely. The live
// spectrum sits underneath. `hasLyrics` tells the page whether to show this
// column at all.
Item {
  id: col

  property var host: null
  property var player: null
  property bool active: true              // Settings → lyrics on/off
  signal seekRequested(real seconds)      // click on a line; the player column seeks

  readonly property color fg: host ? host.fg : "white"
  readonly property color accent: host ? host.accent : "white"
  readonly property string ff: host ? host.ff : ""

  property var synced: []                 // [[seconds, "line"], ...]
  property string plain: ""
  property bool loading: false
  readonly property bool hasLyrics: synced.length > 0 || plain !== ""

  readonly property string bin: String(Qt.resolvedUrl("bin/soundhub-lyrics")).replace("file://", "")
  readonly property string trackKey: player ? (player.trackTitle || "") + "\u0001" + (player.trackArtist || "") : ""
  property string loadedKey: ""

  onTrackKeyChanged: { synced = []; plain = ""; fetchTimer.restart() }
  Component.onCompleted: fetchTimer.restart()

  // metadata often lands in pieces (title first, then artist/length)
  Timer {
    id: fetchTimer
    interval: 450
    onTriggered: {
      if (!col.active || !col.player || !col.player.trackTitle || col.trackKey === col.loadedKey) return
      if (proc.running) proc.running = false
      col.loading = true
      var args = [col.bin, "--title", col.player.trackTitle || "", "--artist", col.player.trackArtist || ""]
      if (col.player.trackAlbum) args.push("--album", col.player.trackAlbum)
      if (col.player.lengthSupported && col.player.length > 0) args.push("--duration", String(Math.round(col.player.length)))
      proc.key = col.trackKey
      proc.command = args
      proc.running = true
    }
  }

  onActiveChanged: if (active) fetchTimer.restart()
  Timer { id: retry; interval: 20000; onTriggered: fetchTimer.restart() }

  Process {
    id: proc
    property string key: ""
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        col.loading = false
        if (proc.key !== col.trackKey) return          // a newer track arrived meanwhile
        try {
          var r = JSON.parse(text)
          if (!r.ok) { retry.restart(); return }        // LRCLIB busy: try again later
          col.loadedKey = proc.key
          if (!r.found || r.instrumental) { col.synced = []; col.plain = ""; return }
          var lines = r.synced || []
          col.synced = lines
          col.plain = lines.length ? "" : String(r.plain || "")
        } catch (e) { col.synced = []; col.plain = "" }
      }
    }
  }

  // ---- playback position, smoothed between Quickshell's sparse updates ----
  property real basePos: 0
  property double baseAt: 0
  property real pos: 0
  readonly property bool playing: player !== null && !!player.isPlaying
  function resync() { basePos = player ? player.position : 0; baseAt = Date.now(); pos = basePos }
  Connections {
    target: col.player
    ignoreUnknownSignals: true
    function onPositionChanged() { col.resync() }
    function onIsPlayingChanged() { col.resync() }
  }
  onPlayerChanged: resync()
  Timer {
    interval: 200
    repeat: true
    running: col.visible && col.synced.length > 0
    onTriggered: col.pos = col.playing ? col.basePos + (Date.now() - col.baseAt) / 1000 : col.basePos
  }

  readonly property int current: {
    var s = synced, p = pos + 0.25, idx = -1
    for (var i = 0; i < s.length; i++) { if (s[i][0] <= p) idx = i; else break }
    return idx
  }

  // ---- view: one soft card, lines centred, edges fading out ----
  readonly property real spectrumH: Style.space(44)

  Rectangle {
    id: card
    anchors.fill: parent
    radius: Math.max(6, Math.min(Style.cornerRadius, 12))
    color: Qt.rgba(col.fg.r, col.fg.g, col.fg.b, 0.035)
    border.width: 1
    border.color: Qt.rgba(col.fg.r, col.fg.g, col.fg.b, 0.06)
  }

  Row {
    id: header
    anchors.top: parent.top
    anchors.topMargin: Style.spacing.md
    anchors.horizontalCenter: parent.horizontalCenter
    spacing: Style.spacing.sm
    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: "󰍩  " + (col.host ? col.host.t("ly.title") : "LYRICS")
      color: Qt.darker(col.fg, 1.35)
      font.family: col.ff; font.pixelSize: Style.font.caption; font.bold: true
      font.letterSpacing: 1.4
    }
    Rectangle {                               // "synced" chip
      visible: col.synced.length > 0
      anchors.verticalCenter: parent.verticalCenter
      width: chip.implicitWidth + Style.space(12)
      height: chip.implicitHeight + Style.space(4)
      radius: height / 2
      color: Qt.rgba(col.accent.r, col.accent.g, col.accent.b, 0.16)
      Text {
        id: chip
        anchors.centerIn: parent
        text: col.host ? col.host.t("ly.synced") : "synced"
        color: col.accent
        font.family: col.ff; font.pixelSize: Style.font.caption - 1
      }
    }
  }

  Item {
    id: textArea
    anchors.top: header.bottom
    anchors.topMargin: Style.spacing.sm
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: spectrum.top
    anchors.bottomMargin: Style.spacing.sm
    anchors.leftMargin: Style.spacing.lg
    anchors.rightMargin: Style.spacing.lg

    // soft fade at the top and bottom edges
    layer.enabled: true
    layer.effect: MultiEffect {
      maskEnabled: true
      maskSource: fade
      maskThresholdMin: 0.0
      maskSpreadAtMin: 1.0
    }

    ListView {
      id: list
      anchors.fill: parent
      visible: col.synced.length > 0
      clip: true
      model: col.synced
      spacing: Style.space(10)
      currentIndex: Math.max(0, col.current)
      highlightRangeMode: ListView.StrictlyEnforceRange
      preferredHighlightBegin: height * 0.36
      preferredHighlightEnd: height * 0.36 + Style.space(40)
      highlightMoveDuration: 420
      boundsBehavior: Flickable.StopAtBounds
      interactive: false

      delegate: Text {
        id: line
        required property var modelData
        required property int index
        readonly property bool now: index === col.current
        readonly property int dist: Math.abs(index - col.current)
        width: list.width
        horizontalAlignment: Text.AlignHCenter
        text: String(modelData[1]).trim() !== "" ? modelData[1] : "♪"
        wrapMode: Text.Wrap
        color: now ? col.accent : col.fg
        opacity: now ? 1 : Math.max(0.28, 0.75 - dist * 0.12)
        font.family: col.ff
        font.pixelSize: now ? Style.font.title + 3 : Style.font.body + 1
        font.bold: now
        Behavior on opacity { NumberAnimation { duration: 260 } }
        Behavior on font.pixelSize { NumberAnimation { duration: 200 } }
        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: { col.seekRequested(line.modelData[0]); col.basePos = line.modelData[0]; col.baseAt = Date.now() }
        }
      }
    }

    Flickable {
      anchors.fill: parent
      visible: col.synced.length === 0 && col.plain !== ""
      clip: true
      contentHeight: plainText.implicitHeight + Style.space(40)
      boundsBehavior: Flickable.StopAtBounds
      Text {
        id: plainText
        y: Style.space(20)
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: col.plain
        wrapMode: Text.Wrap
        lineHeight: 1.35
        color: col.fg
        opacity: 0.85
        font.family: col.ff; font.pixelSize: Style.font.body + 1
      }
    }
  }

  Rectangle {
    id: fade
    width: textArea.width
    height: textArea.height
    visible: false
    layer.enabled: true
    gradient: Gradient {
      GradientStop { position: 0.00; color: Qt.rgba(1, 1, 1, 0) }
      GradientStop { position: 0.16; color: Qt.rgba(1, 1, 1, 1) }
      GradientStop { position: 0.84; color: Qt.rgba(1, 1, 1, 1) }
      GradientStop { position: 1.00; color: Qt.rgba(1, 1, 1, 0) }
    }
  }

  Spectrum {
    id: spectrum
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.margins: Style.spacing.md
    height: col.spectrumH
    levels: col.host && col.host.cava ? col.host.cava.levels : []
    style: col.host ? String(col.host.opt("spectrumStyle", "bars")) : "bars"
    color: Qt.rgba(col.accent.r, col.accent.g, col.accent.b, 0.55)
    colorTop: col.accent
  }
}
