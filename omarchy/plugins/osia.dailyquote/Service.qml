import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "settings.js" as Settings

// A quote on the desktop background, just above the wallpaper
// (WlrLayer.Bottom) so it never covers the bar, panels or windows: the
// original (any language) large — blackletter for Latin script — and under
// it the translation into the language chosen in the settings,
// then the author. Click-through, except while `editMode` (toggled from the
// bar widget) lets you drag the card; a click elsewhere ends that.
//
// The quote itself comes from bin/dailyquote, which keeps the current one on
// disk and only fetches a new one when it is older than the chosen interval,
// so restarting the shell doesn't skip quotes.
// Overlay design and drag/position handling are adapted from
// io.github.r4y-br.quran-motivation by Rayen Iben Romdhane (MIT).
Item {
  id: root

  readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/omarchy/dailyquote"
  readonly property string settingsPath: stateDir + "/settings.json"
  readonly property string quoteBin: String(Qt.resolvedUrl("bin/dailyquote")).replace("file://", "")

  property var cfg: Settings.parse("")
  property var quote: null
  // top / bottom lines, honouring the languages switched off in the settings
  readonly property var shown: Settings.view(quote, cfg)
  property bool editMode: false

  FontLoader { id: gothic; source: Qt.resolvedUrl("fonts/UnifrakturMaguntia-Book.ttf") }

  // ---- settings (shared with the bar widget) ----
  FileView {
    id: settingsFile
    path: root.settingsPath
    watchChanges: true
    printErrors: false
    onLoaded: root.cfg = Settings.parse(text())
    onLoadFailed: root.cfg = Settings.parse("")
    onFileChanged: reload()
  }

  function commitPosition(nx, ny) {
    var c = Object.assign({}, cfg)
    c.posX = Math.max(0, Math.min(1, nx))
    c.posY = Math.max(0, Math.min(1, ny))
    cfg = c
    Quickshell.execDetached(["mkdir", "-p", stateDir])
    settingsFile.setText(JSON.stringify(c))
  }

  // ---- the quote ----
  function refresh(force) {
    if (quoteProc.running) return
    quoteProc.command = force ? [quoteBin, "next", cfg.lang] : [quoteBin, "get", String(cfg.intervalMinutes), cfg.lang]
    quoteProc.running = true
  }
  Process {
    id: quoteProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try { var q = JSON.parse(text); if (q && (q.text || q.en)) root.quote = q } catch (e) {}
      }
    }
  }
  Component.onCompleted: refresh(false)
  onCfgChanged: refresh(false)
  Timer { interval: 60000; running: true; repeat: true; onTriggered: root.refresh(false) }

  IpcHandler {
    target: "osia.dailyquote"
    function next(): void { root.refresh(true) }
    function edit(): void { root.editMode = !root.editMode }
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: panel
      required property var modelData

      screen: modelData
      anchors { top: true; bottom: true; left: true; right: true }
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore

      WlrLayershell.namespace: "osia-dailyquote"
      WlrLayershell.layer: WlrLayer.Bottom
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      mask: Region {
        width: root.editMode ? panel.width : 0
        height: root.editMode ? panel.height : 0
      }

      readonly property bool shown: root.cfg.visible && root.quote !== null
      readonly property real s: root.cfg.scale

      MouseArea {
        anchors.fill: parent
        enabled: root.editMode
        onClicked: root.editMode = false
      }

      Rectangle {
        visible: root.editMode
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 16
        width: hint.implicitWidth + 24
        height: hint.implicitHeight + 14
        radius: 8
        color: Qt.rgba(0, 0, 0, 0.6)
        Text {
          id: hint
          anchors.centerIn: parent
          textFormat: Text.PlainText
          text: Settings.t(root.cfg.lang, "hint")
          color: "#ffffff"
          font.pixelSize: 13
        }
      }

      Item {
        id: content
        visible: opacity > 0
        opacity: panel.shown ? 1 : 0
        // vertical: written like Chinese / Japanese — upright characters in
        // columns, top to bottom, right to left (VerticalText.qml)
        readonly property bool vertical: root.cfg.orientation === "vertical"
        width: qc.width
        height: qc.height
        z: 1
        Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

        function applyStoredPosition() {
          // keep a margin from the screen edges (and from a bar or notch)
          var m = 40
          x = Math.max(m, Math.min(panel.width - width - m, root.cfg.posX * panel.width - width / 2))
          y = Math.max(m + 20, Math.min(panel.height - height - m, root.cfg.posY * panel.height - height / 2))
        }
        Component.onCompleted: applyStoredPosition()
        onWidthChanged: if (!dragArea.drag.active) applyStoredPosition()
        onHeightChanged: if (!dragArea.drag.active) applyStoredPosition()
        Connections {
          target: root
          function onCfgChanged() { if (!dragArea.drag.active) content.applyStoredPosition() }
        }

        Item {
          id: face
          anchors.centerIn: parent
          width: qc.width
          height: qc.height

        QuoteCard {
          id: qc
          quote: root.quote
          cfg: root.cfg
          s: panel.s
          screenW: panel.width
          screenH: panel.height
          editing: root.editMode
        }

        MouseArea {
          id: dragArea
          anchors.fill: qc
          enabled: root.editMode
          cursorShape: Qt.SizeAllCursor
          drag.target: content
          drag.axis: Drag.XAndYAxis
          drag.minimumX: 0
          drag.maximumX: panel.width - content.width
          drag.minimumY: 0
          drag.maximumY: panel.height - content.height
          onReleased: root.commitPosition((content.x + content.width / 2) / panel.width,
                                          (content.y + content.height / 2) / panel.height)
        }
        }
      }
    }
  }
}
