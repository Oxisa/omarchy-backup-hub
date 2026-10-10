import QtQuick
import qs.Commons

// A settings row inside a card: title (+ optional hint) on the left, a
// control on the right (`data` children go there).
Item {
  id: row
  property string title: ""
  property string hint: ""
  property color fg: "white"
  property string fontFamily: ""
  property real controlWidth: -1            // -1: the control's own width
  default property alias control: slot.data

  width: parent ? parent.width : 0
  implicitHeight: Math.max(texts.implicitHeight, slot.childrenRect.height) + Style.space(4)

  Column {
    id: texts
    anchors.left: parent.left
    anchors.right: slot.left
    anchors.rightMargin: Style.space(12)
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.space(2)
    Text {
      width: parent.width
      text: row.title
      color: row.fg
      font.family: row.fontFamily; font.pixelSize: Style.font.body
      elide: Text.ElideRight
    }
    Text {
      width: parent.width
      visible: row.hint !== ""
      text: row.hint
      color: Qt.darker(row.fg, 1.6)
      font.family: row.fontFamily; font.pixelSize: Style.font.caption - 1
      wrapMode: Text.Wrap
    }
  }
  Item {
    id: slot
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    width: row.controlWidth >= 0 ? row.controlWidth : childrenRect.width
    height: childrenRect.height
  }
}
