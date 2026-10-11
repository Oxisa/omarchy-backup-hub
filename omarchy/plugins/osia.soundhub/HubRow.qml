import QtQuick
import qs.Commons

// A settings row inside a card: (optional icon,) title and an optional hint
// on the left, a control on the right (`data` children go there). The row
// lights up under the pointer, with an accent mark on the left, so it's
// always clear which setting the control next to it changes.
Item {
  id: row
  property string title: ""
  property string hint: ""
  property string icon: ""
  property color fg: "white"
  property color accent: Color.accent
  property string fontFamily: ""
  property real controlWidth: -1            // -1: the control's own width
  default property alias control: slot.data

  width: parent ? parent.width : 0
  implicitHeight: Math.max(texts.implicitHeight, slot.childrenRect.height) + Style.space(14)

  HoverHandler { id: hover }
  Rectangle {                               // the highlight, a little wider than the row
    anchors.fill: parent
    anchors.leftMargin: -Style.space(8); anchors.rightMargin: -Style.space(8)
    radius: Style.space(10)
    color: Qt.rgba(row.fg.r, row.fg.g, row.fg.b, hover.hovered ? 0.06 : 0)
    Behavior on color { ColorAnimation { duration: 120 } }
    Rectangle {
      anchors.left: parent.left; anchors.leftMargin: Style.space(2)
      anchors.verticalCenter: parent.verticalCenter
      width: 3; height: parent.height - Style.space(16); radius: 1.5
      color: row.accent
      opacity: hover.hovered ? 1 : 0
      Behavior on opacity { NumberAnimation { duration: 120 } }
    }
  }

  Text {
    id: glyph
    visible: row.icon !== ""
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    width: visible ? Style.space(26) : 0
    text: row.icon
    color: hover.hovered ? row.accent : Qt.darker(row.fg, 1.3)
    font.family: row.fontFamily; font.pixelSize: Style.font.body + 2
  }
  Column {
    id: texts
    anchors.left: glyph.right
    anchors.leftMargin: row.icon !== "" ? Style.space(8) : 0
    anchors.right: slot.left
    anchors.rightMargin: Style.space(12)
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.space(2)
    Text {
      width: parent.width
      text: row.title
      color: hover.hovered ? Qt.lighter(row.fg, 1.08) : row.fg
      font.family: row.fontFamily; font.pixelSize: Style.font.body
      font.bold: hover.hovered
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
