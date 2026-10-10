import QtQuick
import qs.Commons
import qs.Ui

// Pill button/chip. `on` fills it with the accent; `subtle` keeps an on chip
// as an accent wash instead (for toggles that sit among other chips).
// `iconOnly` hides the label and shows it as a tooltip.
Rectangle {
  id: chip
  property string icon: ""
  property string label: ""
  property bool on: false
  property bool subtle: false
  property bool iconOnly: false
  property bool danger: false
  property color fg: "white"
  property color accent: "white"
  property color ink: "black"              // text colour on a filled chip
  property string fontFamily: ""
  property real h: HubStyle.controlH
  signal clicked()

  readonly property bool hovered: mouse.containsMouse
  readonly property color tone: danger ? "#e06c75" : accent

  height: h
  width: iconOnly ? h : row.implicitWidth + Style.space(22)
  radius: height / 2
  color: on ? (subtle ? HubStyle.tint(tone, hovered ? 0.30 : 0.22) : tone)
            : HubStyle.tint(fg, hovered ? HubStyle.controlHover : HubStyle.control)
  border.width: on && subtle ? 1 : 0
  border.color: HubStyle.tint(tone, 0.6)
  opacity: enabled ? 1 : 0.4
  Behavior on color { ColorAnimation { duration: HubStyle.anim } }

  Row {
    id: row
    anchors.centerIn: parent
    spacing: Style.space(7)
    Text {
      visible: chip.icon !== ""
      anchors.verticalCenter: parent.verticalCenter
      text: chip.icon
      color: chip.on && !chip.subtle ? chip.ink : chip.on ? chip.tone : chip.fg
      font.family: chip.fontFamily; font.pixelSize: Style.font.body
    }
    Text {
      visible: !chip.iconOnly && chip.label !== ""
      anchors.verticalCenter: parent.verticalCenter
      text: chip.label
      color: chip.on && !chip.subtle ? chip.ink : chip.on ? chip.tone : chip.fg
      font.family: chip.fontFamily; font.pixelSize: Style.font.caption; font.bold: chip.on
    }
  }
  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    enabled: chip.enabled
    cursorShape: Qt.PointingHandCursor
    onClicked: chip.clicked()
  }
  PanelToolTip {
    visible: chip.iconOnly && chip.label !== "" && mouse.containsMouse
    text: chip.label
  }
}
