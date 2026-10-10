import QtQuick
import Quickshell.Services.Mpris

// Player selection for SoundHub. Delegates to Omarchy's media service when the
// shell hands it to us (so we agree with the bar and media keys); otherwise
// talks to MPRIS directly with the same small API: activePlayer,
// sourcePlayers, playerKey(), labelFor(), runAction(), selectPlayer().
QtObject {
  id: root

  property var service: null
  property string preferredKey: ""

  readonly property var players: Mpris.players ? Mpris.players.values : []

  function hasMeta(p) { return !!p && !!(p.trackTitle || p.trackArtist) }

  readonly property var ownSources: {
    var list = []
    for (var i = 0; i < players.length; i++) if (hasMeta(players[i])) list.push(players[i])
    list.sort(function(a, b) {
      if (!!a.isPlaying !== !!b.isPlaying) return a.isPlaying ? -1 : 1
      return labelFor(a).localeCompare(labelFor(b))
    })
    return list
  }

  readonly property var ownActive: {
    var list = ownSources
    for (var i = 0; i < list.length; i++) if (playerKey(list[i]) === preferredKey) return list[i]
    return list.length ? list[0] : null
  }

  readonly property var activePlayer: service ? service.activePlayer : ownActive
  readonly property var sourcePlayers: service ? service.sourcePlayers : ownSources

  function playerKey(p) {
    if (service) return service.playerKey(p)
    return p ? String(p.dbusName || p.identity || "") : ""
  }

  function labelFor(p) {
    if (service) return service.labelFor(p)
    return p ? String(p.identity || p.desktopEntry || p.dbusName || "?") : ""
  }

  function selectPlayer(key) {
    if (service) service.selectPlayer(key)
    else preferredKey = key
  }

  function runAction(action, feedback, key) {
    if (service) { service.runAction(action, feedback, key); return }
    var p = activePlayer
    if (!p) return
    if (action === "playPause") p.togglePlaying()
    else if (action === "next" && p.canGoNext) p.next()
    else if (action === "previous" && p.canGoPrevious) p.previous()
  }
}
