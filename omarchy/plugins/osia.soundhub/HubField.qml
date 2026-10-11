import QtQuick
import qs.Commons

// Pill text field in SoundHub's style: soft fill, accent ring while focused,
// optional leading icon, placeholder.
//   accepted()  Enter   editingFinished()  Enter or focus lost   textEdited()  typed
Rectangle {
  id: field
  property alias text: input.text
  property alias input: input
  property string placeholderText: ""
  property string icon: ""
  property color fg: "white"
  property color accent: "white"
  property string fontFamily: ""
  signal accepted()
  signal editingFinished()
  signal textEdited()                // typed by the user (not set from code)
  signal shiftAccepted()             // Shift+Enter
  function forceActiveFocus() { input.forceActiveFocus() }
  function selectAll() { input.selectAll() }

  height: HubStyle.controlH
  radius: height / 2
  color: HubStyle.tint(fg, input.activeFocus ? HubStyle.controlHover : hover.hovered ? HubStyle.controlHover : HubStyle.control)
  border.width: input.activeFocus ? 1 : 0
  border.color: HubStyle.tint(accent, 0.6)
  Behavior on color { ColorAnimation { duration: HubStyle.anim } }
  HoverHandler { id: hover; cursorShape: Qt.IBeamCursor }

  Text {
    id: lead
    visible: field.icon !== ""
    anchors.left: parent.left; anchors.leftMargin: Style.space(12)
    anchors.verticalCenter: parent.verticalCenter
    text: field.icon
    color: input.activeFocus ? field.accent : Qt.darker(field.fg, 1.4)
    font.family: field.fontFamily; font.pixelSize: Style.font.caption + 1
  }
  TextInput {
    id: input
    anchors.left: lead.visible ? lead.right : parent.left
    anchors.leftMargin: lead.visible ? Style.space(8) : Style.space(14)
    anchors.right: parent.right; anchors.rightMargin: Style.space(14)
    anchors.verticalCenter: parent.verticalCenter
    color: field.fg
    selectionColor: HubStyle.tint(field.accent, 0.45)
    selectedTextColor: field.fg
    clip: true
    font.family: field.fontFamily; font.pixelSize: Style.font.caption + 1
    onAccepted: { field.accepted(); field.editingFinished() }
    onTextEdited: field.textEdited()
    Keys.onReturnPressed: function(e) {
      if (e.modifiers & Qt.ShiftModifier) { field.shiftAccepted(); e.accepted = true } else e.accepted = false
    }
    onActiveFocusChanged: if (!activeFocus) field.editingFinished()
    Text {
      visible: !input.text && !input.activeFocus
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width
      text: field.placeholderText
      color: Qt.darker(field.fg, 1.8)
      font: input.font
      elide: Text.ElideRight
    }
  }
}
