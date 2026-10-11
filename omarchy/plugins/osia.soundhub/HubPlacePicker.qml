import QtQuick
import qs.Commons

// 3×3 position picker drawn like a little screen: corners, sides, centre.
// `value` is one of tl t tr l c r bl b br (or anything else: nothing lit).
Rectangle {
  id: picker
  property string value: ""
  property color fg: "white"
  property color accent: "white"
  signal picked(string place)

  width: Style.space(96); height: Style.space(62)
  radius: Style.space(8)
  color: HubStyle.tint(fg, HubStyle.control)
  Grid {
    anchors.centerIn: parent
    columns: 3
    spacing: Style.space(4)
    Repeater {
      model: ["tl", "t", "tr", "l", "c", "r", "bl", "b", "br"]
      delegate: Rectangle {
        id: cell
        required property string modelData
        readonly property bool on: picker.value === modelData
        width: Style.space(26); height: Style.space(16)
        radius: Style.space(4)
        color: on ? picker.accent : HubStyle.tint(picker.fg, cellMouse.containsMouse ? 0.22 : 0.10)
        Behavior on color { ColorAnimation { duration: HubStyle.anim } }
        MouseArea {
          id: cellMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: picker.picked(cell.modelData)
        }
      }
    }
  }
}
