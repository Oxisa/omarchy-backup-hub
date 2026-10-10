import QtQuick
import qs.Commons

// Pill on/off switch; the caller owns `checked` and flips it on toggled().
Rectangle {
  id: sw
  property bool checked: false
  property color fg: "white"
  property color accent: "white"
  property color ink: "black"
  signal toggled()

  width: Style.space(40); height: Style.space(22)
  radius: height / 2
  color: checked ? accent : HubStyle.tint(fg, mouse.containsMouse ? 0.22 : 0.16)
  Behavior on color { ColorAnimation { duration: HubStyle.anim } }
  Rectangle {
    width: parent.height - Style.space(6); height: width; radius: width / 2
    anchors.verticalCenter: parent.verticalCenter
    x: sw.checked ? parent.width - width - Style.space(3) : Style.space(3)
    Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    color: sw.checked ? sw.ink : sw.fg
  }
  MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: sw.toggled() }
}
