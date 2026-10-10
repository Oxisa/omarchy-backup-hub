import QtQuick

// A soft card: rounded, borderless, a shade above the panel. `hoverable`
// lifts it a little under the mouse; `selected` gives it an accent wash.
Rectangle {
  id: card
  property color fg: "white"
  property color accent: "white"
  property bool hoverable: false
  property bool selected: false
  readonly property alias hovered: hover.hovered

  radius: HubStyle.radius
  color: selected ? HubStyle.tint(accent, 0.14)
       : HubStyle.tint(fg, hoverable && hover.hovered ? HubStyle.surfaceHover : HubStyle.surface)
  border.width: selected ? 1 : 0
  border.color: HubStyle.tint(accent, 0.45)
  Behavior on color { ColorAnimation { duration: HubStyle.anim } }

  HoverHandler { id: hover; enabled: card.hoverable }
}
