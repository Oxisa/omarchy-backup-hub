import QtQuick
import qs.Commons

// Now playing: the player column (PlayerColumn.qml) and, when the track has
// lyrics (and lyrics are on in Settings), a lyrics card beside it with the
// spectrum underneath. In that mode the player column stacks vertically:
// art centred, title under it. Without lyrics the page is the single player
// column exactly as before. `host.wide` widens the panel for two columns.
Item {
  id: page
  property var host: null

  readonly property bool lyricsOn: host ? host.opt("lyrics", true) === true : true
  readonly property bool wide: lyricsOn && lyrics.hasLyrics && player.hasTrack
  readonly property real gap: Style.spacing.lg

  implicitHeight: player.implicitHeight
  onWideChanged: if (host) host.wide = wide
  Component.onDestruction: if (host) host.wide = false

  PlayerColumn {
    id: player
    host: page.host
    width: page.wide ? Style.space(360) : page.width
    stacked: page.wide
    showSpectrum: !page.wide
  }

  LyricsColumn {
    id: lyrics
    host: page.host
    player: player.player
    active: page.lyricsOn
    onSeekRequested: function(t) { if (player.canSeek) player.seekTo(t) }
    visible: page.wide
    x: player.width + page.gap
    width: Math.max(0, page.width - x)
    height: player.height
  }
}
