import QtQuick
import qs.Commons

// Focus: ambient sounds to mix (rain, café, waves…).
//   header card  big play/stop, status, master volume, clear
//   tiles        click = add/remove a sound; wheel = its volume; selected
//                tiles show a slim volume bar. Icons breathe while playing.
// State lives in the bar widget (FocusState), so the mix keeps playing with
// the panel closed.
Column {
  id: page
  property var host: null
  spacing: HubStyle.gap

  readonly property var ambient: host ? host.ambient : null
  readonly property color fg: host ? host.fg : "white"
  readonly property color accent: host ? host.accent : "white"
  readonly property string ff: host ? host.ff : ""
  readonly property int selectedCount: ambient ? (ambient.selected, ambient.selectedCount()) : 0
  readonly property bool playing: ambient ? ambient.playing && selectedCount > 0 : false
  readonly property real radius: Math.max(6, Math.min(Style.cornerRadius, 12))
  function t(k, a) { return host ? host.t(k, a) : k }

  // ======== header card ========
  HubCard {
    width: parent.width
    height: headerRow.implicitHeight + HubStyle.pad * 2
    fg: page.fg; accent: page.accent

    Row {
      id: headerRow
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.margins: HubStyle.pad
      spacing: HubStyle.pad

      // play / stop with a pulsing ring while the mix plays
      Item {
        width: Style.space(48); height: width
        anchors.verticalCenter: parent.verticalCenter

        Rectangle {
          anchors.centerIn: parent
          width: parent.width; height: width; radius: width / 2
          color: "transparent"
          border.width: 2
          border.color: page.accent
          opacity: 0
          SequentialAnimation on scale {
            running: page.playing
            loops: Animation.Infinite
            NumberAnimation { from: 1.0; to: 1.3; duration: 1600; easing.type: Easing.OutQuad }
          }
          SequentialAnimation on opacity {
            running: page.playing
            loops: Animation.Infinite
            NumberAnimation { from: 0.55; to: 0.0; duration: 1600; easing.type: Easing.OutQuad }
          }
        }
        Rectangle {
          anchors.fill: parent
          radius: width / 2
          color: page.playing ? page.accent : Qt.rgba(page.fg.r, page.fg.g, page.fg.b, 0.10)
          Behavior on color { ColorAnimation { duration: 200 } }
          Text {
            anchors.centerIn: parent
            text: page.playing ? "󰏤" : "󰐊"
            color: page.playing ? (host ? host.bgc : "black") : page.fg
            font.family: page.ff; font.pixelSize: Style.space(21)
          }
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: if (page.ambient) (page.ambient.playing ? page.ambient.stopAll() : page.ambient.playAll())
          }
        }
      }

      Column {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - Style.space(48) - clearBtn.width - parent.spacing * 2
        spacing: Style.space(6)

        Text {
          width: parent.width
          elide: Text.ElideRight
          text: page.playing ? page.t("focus.mixing", page.selectedCount)
              : page.selectedCount > 0 ? page.t("focus.paused", page.selectedCount)
              : page.t("focus.pick")
          color: page.fg
          font.family: page.ff; font.pixelSize: Style.font.title; font.bold: true
        }
        Row {
          width: parent.width
          spacing: Style.spacing.sm
          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "󰕾"
            color: Qt.darker(page.fg, 1.3)
            font.family: page.ff; font.pixelSize: Style.font.body
          }
          HubSlider {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - Style.space(24)
            minimum: 0; maximum: 100; step: 1
            format: function(v) { return Math.round(v) + "%" }
            value: page.ambient ? page.ambient.master : 0
            fillColor: page.accent
            fontFamily: page.ff
            onMoved: function(v) { if (page.ambient) page.ambient.previewMaster(v) }
            onReleased: function(v) { if (page.ambient) page.ambient.commitMaster(v) }
          }
        }
      }

      HubChip {
        id: clearBtn
        anchors.verticalCenter: parent.verticalCenter
        iconOnly: true
        icon: "󰆴"
        label: page.t("focus.clear")
        enabled: page.selectedCount > 0
        fg: page.fg; accent: page.accent; fontFamily: page.ff
        onClicked: if (page.ambient) page.ambient.clearAll()
      }
    }
  }

  // ======== sound tiles ========
  Grid {
    id: grid
    width: parent.width
    columns: 4
    spacing: Style.space(8)
    readonly property real tileW: (width - spacing * (columns - 1)) / columns

    Repeater {
      model: page.ambient ? page.ambient.catalog : []
      delegate: Rectangle {
        id: tile
        required property var modelData
        required property int index
        readonly property string sid: modelData.id
        readonly property bool on: page.ambient ? (page.ambient.selected, page.ambient.isSelected(sid)) : false
        readonly property int vol: page.ambient ? (page.ambient.volumes, page.ambient.volumeOf(sid)) : 0

        width: grid.tileW
        height: Style.space(84)
        radius: HubStyle.radius
        color: on ? HubStyle.tint(page.accent, 0.14)
             : HubStyle.tint(page.fg, tileMouse.containsMouse ? HubStyle.surfaceHover : HubStyle.surface)
        border.width: on ? 1 : 0
        border.color: HubStyle.tint(page.accent, 0.45)
        Behavior on color { ColorAnimation { duration: 160 } }

        MouseArea {
          id: tileMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: if (page.ambient) page.ambient.toggleSound(tile.sid)
          onWheel: function(w) {
            if (page.ambient) page.ambient.commitVolume(tile.sid, tile.vol + (w.angleDelta.y > 0 ? 5 : -5))
          }
        }

        Column {
          anchors.horizontalCenter: parent.horizontalCenter
          y: tile.on ? Style.space(8) : (parent.height - implicitHeight) / 2
          Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
          spacing: Style.space(6)

          Rectangle {                         // icon disc
            anchors.horizontalCenter: parent.horizontalCenter
            width: Style.space(34); height: width; radius: width / 2
            color: tile.on ? page.accent : Qt.rgba(page.fg.r, page.fg.g, page.fg.b, 0.08)
            Behavior on color { ColorAnimation { duration: 180 } }
            SequentialAnimation on scale {
              running: tile.on && page.playing
              loops: Animation.Infinite
              alwaysRunToEnd: true
              NumberAnimation { from: 1.0; to: 1.08; duration: 1400 + tile.index * 70; easing.type: Easing.InOutSine }
              NumberAnimation { from: 1.08; to: 1.0; duration: 1400 + tile.index * 70; easing.type: Easing.InOutSine }
            }
            Text {
              anchors.centerIn: parent
              text: tile.modelData.glyph
              color: tile.on ? (host ? host.bgc : "black") : page.fg
              font.family: page.ff; font.pixelSize: Style.space(18)
            }
          }
          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            width: tile.width - Style.space(10)
            horizontalAlignment: Text.AlignHCenter
            text: page.t("focus." + tile.sid)
            color: tile.on ? page.fg : Qt.darker(page.fg, 1.25)
            font.family: page.ff; font.pixelSize: Style.font.caption
            font.bold: tile.on
            elide: Text.ElideRight
          }
        }

        // slim volume bar on selected tiles; value shown on hover
        HubSlider {
          visible: tile.on
          anchors.bottom: parent.bottom
          anchors.bottomMargin: Style.space(6)
          anchors.horizontalCenter: parent.horizontalCenter
          width: parent.width - Style.space(16)
          minimum: 0; maximum: 100; step: 1
          showValue: false
          value: tile.vol
          trackHeight: 3
          knobSize: 10
          fillColor: page.accent
          fontFamily: page.ff
          onMoved: function(v) { if (page.ambient) page.ambient.previewVolume(tile.sid, v) }
          onReleased: function(v) { if (page.ambient) page.ambient.commitVolume(tile.sid, v) }
        }
        Text {
          visible: tile.on && tileMouse.containsMouse
          anchors.top: parent.top
          anchors.right: parent.right
          anchors.margins: Style.space(6)
          text: tile.vol + "%"
          color: page.accent
          font.family: page.ff; font.pixelSize: Style.font.caption - 1
        }
      }
    }
  }

  Text {
    width: parent.width
    horizontalAlignment: Text.AlignHCenter
    wrapMode: Text.Wrap
    text: page.t("focus.credit")
    color: Qt.darker(page.fg, 2.0)
    font.family: page.ff; font.pixelSize: Style.font.caption - 2
  }
}
