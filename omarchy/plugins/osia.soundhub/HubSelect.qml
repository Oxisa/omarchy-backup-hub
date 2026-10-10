import QtQuick
import QtQuick.Controls
import qs.Commons

// Pill dropdown in SoundHub's style. Same API as Omarchy's Dropdown
// (label, value, options as strings or {value,label}, changed(value)),
// so pages swap one for the other. The list opens as a soft card below.
Item {
  id: root
  property string label: ""
  property string value: ""
  property var options: []
  property bool showLabel: true
  property string icon: ""
  property color foreground: "white"
  property color accent: "white"
  property color background: "black"
  property string fontFamily: ""
  signal changed(string value)

  function optionValue(o) { return (o && typeof o === "object") ? String(o.value) : String(o) }
  function optionLabel(o) { return (o && typeof o === "object") ? String(o.label) : String(o) }
  function currentLabel() {
    for (var i = 0; i < options.length; i++) if (optionValue(options[i]) === value) return optionLabel(options[i])
    return value
  }

  readonly property bool labelShown: showLabel && label !== ""
  implicitWidth: Style.space(180)
  implicitHeight: (labelShown ? cap.implicitHeight + Style.space(6) : 0) + HubStyle.controlH

  Text {
    id: cap
    visible: root.labelShown
    x: Style.space(4)
    text: root.label
    color: Qt.darker(root.foreground, 1.45)
    font.family: root.fontFamily; font.pixelSize: Style.font.caption
  }

  Rectangle {
    id: trigger
    y: root.labelShown ? cap.implicitHeight + Style.space(6) : 0
    width: parent.width
    height: HubStyle.controlH
    radius: height / 2
    color: HubStyle.tint(root.foreground, popup.opened ? HubStyle.controlHover + 0.03
                                         : mouse.containsMouse ? HubStyle.controlHover : HubStyle.control)
    Behavior on color { ColorAnimation { duration: HubStyle.anim } }

    Text {
      anchors.left: parent.left; anchors.leftMargin: Style.space(14)
      anchors.right: chevron.left; anchors.rightMargin: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
      text: (root.icon ? root.icon + "  " : "") + root.currentLabel()
      color: root.foreground
      font.family: root.fontFamily; font.pixelSize: Style.font.caption + 1
      elide: Text.ElideRight
    }
    Text {
      id: chevron
      anchors.right: parent.right; anchors.rightMargin: Style.space(12)
      anchors.verticalCenter: parent.verticalCenter
      text: "󰅀"
      rotation: popup.opened ? 180 : 0
      Behavior on rotation { NumberAnimation { duration: HubStyle.anim } }
      color: Qt.darker(root.foreground, 1.3)
      font.family: root.fontFamily; font.pixelSize: Style.font.caption + 1
    }
    MouseArea {
      id: mouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: popup.opened ? popup.close() : popup.open()
    }

    Popup {
      id: popup
      y: trigger.height + Style.space(6)
      width: Math.max(trigger.width, Style.space(160))
      padding: Style.space(5)
      implicitHeight: Math.min(list.contentHeight, Style.space(34) * 8) + padding * 2
      focus: true
      background: Rectangle {
        radius: HubStyle.radiusSmall + Style.space(4)
        color: Qt.tint(root.background, HubStyle.tint(root.foreground, 0.06))
        border.width: 1
        border.color: HubStyle.tint(root.foreground, 0.10)
      }
      enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 120 } }
      exit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 90 } }

      contentItem: ListView {
        id: list
        clip: true
        spacing: Style.space(2)
        boundsBehavior: Flickable.StopAtBounds
        model: root.options
        implicitHeight: contentHeight
        Keys.onEscapePressed: popup.close()
        delegate: Rectangle {
          id: opt
          required property var modelData
          readonly property bool current: root.optionValue(modelData) === root.value
          width: list.width
          height: Style.space(32)
          radius: HubStyle.radiusSmall
          color: current ? HubStyle.tint(root.accent, 0.18)
               : optMouse.containsMouse ? HubStyle.tint(root.foreground, 0.08) : "transparent"
          Text {
            anchors.left: parent.left; anchors.leftMargin: Style.space(12)
            anchors.right: check.left; anchors.rightMargin: Style.space(6)
            anchors.verticalCenter: parent.verticalCenter
            text: root.optionLabel(opt.modelData)
            color: opt.current ? root.accent : root.foreground
            font.family: root.fontFamily; font.pixelSize: Style.font.caption + 1; font.bold: opt.current
            elide: Text.ElideRight
          }
          Text {
            id: check
            anchors.right: parent.right; anchors.rightMargin: Style.space(12)
            anchors.verticalCenter: parent.verticalCenter
            visible: opt.current
            text: "󰄬"
            color: root.accent
            font.family: root.fontFamily; font.pixelSize: Style.font.caption + 1
          }
          MouseArea {
            id: optMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              var v = root.optionValue(opt.modelData)
              popup.close()
              if (v !== root.value) { root.value = v; root.changed(v) }
            }
          }
        }
      }
    }
  }
}
