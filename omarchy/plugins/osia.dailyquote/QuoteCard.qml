import QtQuick
import "settings.js" as Settings

// The quote card itself — background, the original, its translation and the
// author, horizontal or written vertically (VerticalText) — with no window
// of its own. The overlay (Service.qml) and TheNotch's widget layer both use it.
Item {
  id: qc
  property var quote: null
  property var cfg: Settings.parse("")
  property real s: 1                         // size factor (the overlay's "Size")
  property real screenW: 1920                // limits for line length / column height
  property real screenH: 1080
  property bool editing: false               // a white frame while it's being moved
  readonly property bool vertical: cfg.orientation === "vertical"
  readonly property var shown: Settings.view(quote, cfg)

  implicitWidth: card.width
  implicitHeight: card.height
  width: card.width
  height: card.height

  FontLoader { id: gothic; source: Qt.resolvedUrl("fonts/UnifrakturMaguntia-Book.ttf") }

  Rectangle {
    id: card
    width: (qc.vertical ? vblock.width : column.width) + Math.round(36 * qc.s)
    height: (qc.vertical ? vblock.height : column.height) + Math.round(26 * qc.s)
    radius: 14
    color: Qt.rgba(0, 0, 0, qc.cfg.backgroundOpacity)
    border.width: qc.editing ? 2 : 0
    border.color: Qt.rgba(1, 1, 1, 0.8)
  }

  // vertical layout: original on the right, translation to its left,
  // the author in the last column
  Row {
    id: vblock
    visible: qc.vertical
    anchors.centerIn: card
    layoutDirection: Qt.RightToLeft
    spacing: Math.round(18 * qc.s)
    readonly property real tall: Math.min(qc.screenH * 0.62, 760)
    VerticalText {
      text: qc.shown.top
      fontFamily: Settings.fontFor(qc.shown.topLang, gothic.name)
      pixelSize: Math.round(30 * qc.s)
      maxHeight: vblock.tall
      color: "#ffffff"
      styleColor: Qt.rgba(0, 0, 0, 0.65)
    }
    VerticalText {
      visible: qc.shown.bottom !== ""
      text: qc.shown.bottom
      fontFamily: "Noto Serif"
      italic: true
      pixelSize: Math.round(16 * qc.s)
      maxHeight: vblock.tall
      color: Qt.rgba(1, 1, 1, 0.86)
      styleColor: Qt.rgba(0, 0, 0, 0.65)
    }
    VerticalText {
      visible: !!(qc.quote && qc.quote.author)
      text: qc.quote && qc.quote.author ? qc.quote.author : ""
      fontFamily: "Noto Serif"
      pixelSize: Math.round(12 * qc.s)
      maxHeight: vblock.tall
      color: Qt.rgba(1, 1, 1, 0.6)
      styleColor: Qt.rgba(0, 0, 0, 0.65)
    }
  }

  Column {
    id: column
    anchors.centerIn: card
    readonly property real maxTextWidth: Math.min(qc.screenW * 0.72, 980)
    visible: !qc.vertical
    spacing: Math.round(10 * qc.s)

    Text {                                     // English, blackletter
      width: Math.min(implicitWidth, column.maxTextWidth)
      anchors.horizontalCenter: parent.horizontalCenter
      textFormat: Text.PlainText
      text: qc.shown.top
      color: "#ffffff"
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.WordWrap
      font.family: Settings.fontFor(qc.shown.topLang, gothic.name)
      font.pixelSize: Math.round(34 * qc.s)
      style: Text.Raised
      styleColor: Qt.rgba(0, 0, 0, 0.65)
    }

    Text {                                     // Russian translation
      width: Math.min(implicitWidth, column.maxTextWidth)
      anchors.horizontalCenter: parent.horizontalCenter
      textFormat: Text.PlainText
      visible: text !== ""
      text: qc.shown.bottom
      color: Qt.rgba(1, 1, 1, 0.86)
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.WordWrap
      font.family: "Noto Serif"
      font.italic: true
      font.pixelSize: Math.round(17 * qc.s)
      style: Text.Raised
      styleColor: Qt.rgba(0, 0, 0, 0.65)
    }

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      textFormat: Text.PlainText
      text: qc.quote && qc.quote.author ? "— " + qc.quote.author : ""
      color: Qt.rgba(1, 1, 1, 0.6)
      font.family: "Noto Serif"
      font.pixelSize: Math.round(12 * qc.s)
      font.letterSpacing: 1
      style: Text.Raised
      styleColor: Qt.rgba(0, 0, 0, 0.65)
    }
  }
}
