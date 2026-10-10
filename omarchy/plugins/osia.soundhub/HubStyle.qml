pragma Singleton
import QtQuick
import qs.Commons

// SoundHub's look, in one place: soft borderless cards a shade above the
// panel, pill controls of one height, accent only on what is active.
// Sizes are fixed (not theme corner radius) so every tab reads the same.
QtObject {
  readonly property real radius: Style.space(14)        // cards
  readonly property real radiusSmall: Style.space(10)   // tiles inside cards
  readonly property real pad: Style.space(14)           // card padding
  readonly property real gap: Style.space(10)           // between cards
  readonly property real controlH: Style.space(30)      // chips, selects, buttons
  readonly property real surface: 0.05                  // card fill alpha over fg
  readonly property real surfaceHover: 0.085
  readonly property real control: 0.07                  // idle chip/select fill
  readonly property real controlHover: 0.12
  readonly property int anim: 160

  function tint(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }
}
