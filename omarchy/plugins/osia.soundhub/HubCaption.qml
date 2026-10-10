import QtQuick
import qs.Commons

// Small-caps section caption, with an optional item on the right
// (`data` children are placed there).
Item {
  id: root
  property string text: ""
  property string icon: ""
  property color fg: "white"
  property string fontFamily: ""
  default property alias trailing: right.data

  width: parent ? parent.width : 0
  implicitHeight: Math.max(label.implicitHeight, right.childrenRect.height)

  Text {
    id: label
    anchors.left: parent.left
    anchors.leftMargin: Style.space(4)
    anchors.verticalCenter: parent.verticalCenter
    text: (root.icon ? root.icon + "  " : "") + root.text.toUpperCase()
    color: Qt.darker(root.fg, 1.55)
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption - 1
    font.bold: true
    font.letterSpacing: 1.3
  }
  Item {
    id: right
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    width: childrenRect.width
    height: childrenRect.height
  }
}
