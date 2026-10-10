import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.Commons
import "Model.js" as Model

// Now playing. A top strip: the players (app icons; click to pick one) on the
// left, and on the right the two page switches — look (vinyl / cover) and
// lyrics. Under it the player column (PlayerColumn.qml) and, when lyrics are
// on and the track has them, a lyrics card beside it (the panel widens).
Column {
  id: page
  property var host: null
  spacing: Style.spacing.md

  readonly property bool lyricsOn: host ? host.opt("lyrics", true) === true : true
  readonly property string look: host ? String(host.opt("npLook", "vinyl")) : "vinyl"
  readonly property bool wide: lyricsOn && lyrics.hasLyrics && player.hasTrack
  readonly property real gap: Style.spacing.lg
  readonly property var media: host ? host.media : null
  readonly property var sources: media ? media.sourcePlayers : []
  readonly property color fg: host ? host.fg : "white"
  readonly property color accent: host ? host.accent : "white"
  readonly property string ff: host ? host.ff : ""
  function t(k, a) { return host ? host.t(k, a) : k }

  onWideChanged: if (host) host.wide = wide
  Component.onDestruction: if (host) host.wide = false

  // icon for a player: its desktop entry's icon, else none (letter fallback)
  function iconFor(p) {
    var id = p ? String(p.desktopEntry || "") : ""
    if (!id) return ""
    var e = DesktopEntries.byId(id)
    var icon = e && e.icon ? String(e.icon) : id
    if (icon.charAt(0) === "/") return "file://" + icon
    return Quickshell.iconPath(icon, true) || ""
  }

  // ======== top strip ========
  Item {
    width: parent.width
    height: HubStyle.controlH

    Row {
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(6)
      Repeater {
        model: page.sources
        delegate: Rectangle {
          id: chip
          required property var modelData
          readonly property bool current: page.media && player.player && page.media.playerKey(player.player) === page.media.playerKey(modelData)
          readonly property string icon: page.iconFor(modelData)
          width: HubStyle.controlH; height: width; radius: width / 2
          color: current ? HubStyle.tint(page.accent, 0.22)
               : HubStyle.tint(page.fg, chipMouse.containsMouse ? HubStyle.controlHover : HubStyle.control)
          border.width: current ? 1.5 : 0
          border.color: page.accent
          Behavior on color { ColorAnimation { duration: 140 } }
          IconImage {
            anchors.centerIn: parent
            visible: chip.icon !== ""
            implicitSize: Style.space(18)
            source: chip.icon
          }
          Text {
            anchors.centerIn: parent
            visible: chip.icon === ""
            text: (page.media ? page.media.labelFor(chip.modelData) : "?").charAt(0).toUpperCase()
            color: chip.current ? page.accent : page.fg
            font.family: page.ff; font.pixelSize: Style.font.body; font.bold: true
          }
          Rectangle {                                 // playing dot
            visible: !!chip.modelData.isPlaying
            width: Style.space(7); height: width; radius: width / 2
            anchors.right: parent.right; anchors.bottom: parent.bottom
            color: page.accent
            border.width: 1.5; border.color: host ? host.bgc : "black"
          }
          MouseArea {
            id: chipMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: if (page.media) page.media.selectPlayer(page.media.playerKey(chip.modelData))
          }
        }
      }
    }

    Row {
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(6)

      // look: vinyl | cover — a two-icon segmented pill
      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        height: HubStyle.controlH
        width: lookRow.implicitWidth + Style.space(6)
        radius: height / 2
        color: HubStyle.tint(page.fg, HubStyle.control)
        Row {
          id: lookRow
          anchors.centerIn: parent
          spacing: Style.space(2)
          Repeater {
            model: [{ id: "vinyl", glyph: "\u{f0025}", label: page.t("np.lookVinyl") },
                    { id: "cover", glyph: "\u{f02e9}", label: page.t("np.lookCover") }]
            delegate: HubChip {
              required property var modelData
              h: HubStyle.controlH - Style.space(6)
              iconOnly: true
              icon: modelData.glyph
              label: modelData.label
              on: page.look === modelData.id
              fg: page.fg; accent: page.accent; ink: host ? host.bgc : "black"; fontFamily: page.ff
              color: on ? page.accent : HubStyle.tint(page.fg, hovered ? HubStyle.control : 0)
              onClicked: if (host && !on) host.persist({ npLook: modelData.id })
            }
          }
        }
      }

      HubChip {
        anchors.verticalCenter: parent.verticalCenter
        iconOnly: true
        icon: "\u{f0a16}"
        label: page.t("np.lyrics")
        on: page.lyricsOn
        subtle: true
        fg: page.fg; accent: page.accent; fontFamily: page.ff
        onClicked: if (host) host.persist({ lyrics: !page.lyricsOn })
      }
    }
  }

  // ======== player + lyrics ========
  Item {
    width: parent.width
    height: player.implicitHeight

    PlayerColumn {
      id: player
      host: page.host
      look: page.look
      width: page.wide ? Style.space(370) : parent.width
    }

    LyricsColumn {
      id: lyrics
      host: page.host
      player: player.player
      active: page.lyricsOn
      onSeekRequested: function(t) { if (player.canSeek) player.seekTo(t) }
      visible: page.wide
      x: player.width + page.gap
      width: Math.max(0, parent.width - x)
      height: player.height
    }
  }
}
