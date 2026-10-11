import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "I18n.js" as I18n

// SoundHub panel: browser-style tabs over one page at a time. Only the open
// page is instantiated (Loader), so closed tabs cost nothing — the Sound page
// in particular binds PipeWire objects only while it is shown.
Panel {
  id: root
  moduleName: "osia.soundhub"
  ipcTarget: "osia.soundhub"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property var cava: null                 // shared Cava from the bar widget
  readonly property var barIdentity: hostWidget || root

  property var media: null                // shared Media shim from the bar widget
  property var ambient: null              // shared FocusState from the bar widget

  readonly property color fg: bar ? bar.barForeground : Color.foreground
  readonly property color bgc: Color.background
  readonly property string ff: bar ? bar.fontFamily : Style.font.family
  readonly property color accent: Color.accent
  readonly property color urgent: bar ? bar.urgent : Color.urgent

  property int tab: 0
  property string eqScope: "global"      // EQ tab edits the global EQ or one mix's own
  function openEqFor(mixId) { eqScope = mixId || "global"; tab = 2 }
  property int shownTab: 0                // the page on screen; follows `tab` through a short fade
  onTabChanged: if (tab !== shownTab) swap.restart()
  SequentialAnimation {
    id: swap
    NumberAnimation { target: pageHost; property: "opacity"; to: 0; duration: 100; easing.type: Easing.InQuad }
    ScriptAction { script: { root.shownTab = root.tab; slide.y = Style.space(10) } }
    ParallelAnimation {
      NumberAnimation { target: pageHost; property: "opacity"; to: 1; duration: 220; easing.type: Easing.OutCubic }
      NumberAnimation { target: slide; property: "y"; to: 0; duration: 260; easing.type: Easing.OutCubic }
    }
  }
  property bool wide: false               // Now Playing with lyrics: two columns
  // each tab gets the width it needs (the panel resizes while the page is faded out)
  function pageWidth(i) {
    switch (i) {
      case 0: return wide ? 840 : 400      // now playing (+ lyrics)
      case 1: return 920                   // mixer: three columns
      case 2: return 500                   // equalizer
      case 5: return 520                   // microphone
      default: return 440                  // focus, settings
    }
  }

  function opt(key, fallback) {
    return settings && settings[key] !== undefined && settings[key] !== null ? settings[key] : fallback
  }
  readonly property string lang: String(opt("lang", "en") || "en")
  function t(key, args) { return I18n.t(root.lang, key, args) }

  function persist(values) {
    var e = { id: moduleName }
    for (var k in settings) if (k !== "id") e[k] = settings[k]
    for (var key in values) e[key] = values[key]
    settings = e
    if (hostWidget && "settings" in hostWidget) hostWidget.settings = e
    if (bar && bar.shell && typeof bar.shell.updateEntryInline === "function")
      bar.shell.updateEntryInline(moduleName, e)
  }

  // ---- equalizer backend (shared by the EQ page and output switching) ----
  readonly property string eqBin: String(Qt.resolvedUrl("bin/soundhub-eq")).replace("file://", "")
  property var eq: ({ enabled: false, bands: [0, 0, 0, 0, 0, 0], autoPreamp: true, preamp: 0,
                      effectivePreamp: 0, preset: "flat", target: "" })
  property bool eqBusy: false
  property string eqError: ""
  property var eqQueue: []

  function eqRun(args) {
    if (eqProc.running) { eqQueue = eqQueue.concat([args]); return }
    eqBusy = true
    eqProc.command = [eqBin].concat(args)
    eqProc.running = true
  }

  Process {
    id: eqProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var r = JSON.parse(text)
          root.eq = r
          root.eqError = r.ok ? "" : String(r.error || "")
        } catch (e) { root.eqError = String(text).slice(0, 160) }
      }
    }
    stderr: StdioCollector { waitForEnd: true; onStreamFinished: if (text) root.eqError = String(text).slice(0, 160) }
    onExited: {
      root.eqBusy = false
      if (root.eqQueue.length) {
        var next = root.eqQueue[0]
        root.eqQueue = root.eqQueue.slice(1)
        root.eqRun(next)
      }
    }
  }

  // With the EQ on, "switch output" means "send the EQ to that device";
  // making the device the default would bypass the EQ. Returns true if handled.
  function selectOutput(node) {
    if (!eq.enabled || !node) return false
    eqRun(["retarget", String(node.name)])
    return true
  }

  onOpenedChanged: if (opened) eqRun(["status"])

  function open() { controller.show() }
  function close() { controller.hide() }
  function toggle() { root.opened ? close() : open() }
  function openTab(i) { if (!root.opened) { swap.stop(); root.shownTab = i } root.tab = i; open() }

  readonly property var tabs: [
    { icon: "󰝚", key: "tab.playing", file: "NowPlaying.qml" },
    { icon: "\u{f1542}", key: "tab.mixer", file: "MixerPage.qml" },
    { icon: "󰺢", key: "tab.eq",      file: "EqPage.qml" },
    { icon: "󱅻", key: "tab.focus",   file: "FocusPage.qml" },
    { icon: "󰒓", key: "tab.settings", file: "SettingsPage.qml" },
    { icon: "\u{f036c}", key: "tab.mic",  file: "MicPage.qml" }
  ]

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    contentWidth: panel.fittedContentWidth(Style.space(root.pageWidth(root.shownTab)))
    contentHeight: panel.fittedContentHeight(contentCol.implicitHeight)

    Column {
      id: contentCol
      width: parent.width
      spacing: Style.space(12)

      // ---- tabs: a segmented control with a sliding highlight ----
      // When the labels don't all fit, inactive tabs shrink to their icon
      // (hover shows the name) and only the active one keeps its label.
      Rectangle {
        id: strip
        width: parent.width
        height: HubStyle.controlH + Style.space(8)
        radius: height / 2
        color: HubStyle.tint(root.fg, HubStyle.surface)

        readonly property real pad: Style.space(3)
        readonly property real iconW: Style.space(40)
        // natural width of every tab with its label
        property var fullW: []
        readonly property real fullSum: { var t = 0; for (var i = 0; i < fullW.length; i++) t += fullW[i]; return t }
        readonly property bool compact: fullSum > width - pad * 2
        function tabW(i) {
          var f = fullW[i] || iconW
          if (!compact) return (width - pad * 2) * f / Math.max(1, fullSum)    // spread to fill
          var active = Math.min(fullW[root.tab] || iconW, width - pad * 2 - iconW * (root.tabs.length - 1))
          if (i === root.tab) return active
          return Math.max(iconW, (width - pad * 2 - active) / Math.max(1, root.tabs.length - 1))
        }
        function tabX(i) { var x = pad; for (var k = 0; k < i; k++) x += tabW(k); return x }

        // hidden measurers for the natural widths
        Row {
          visible: false
          Repeater {
            model: root.tabs
            delegate: Text {
              required property var modelData
              required property int index
              text: modelData.icon + "  " + root.t(modelData.key)
              font.family: root.ff; font.pixelSize: Style.font.body; font.bold: true
              onImplicitWidthChanged: { var w = strip.fullW.slice(); w[index] = implicitWidth + Style.space(30); strip.fullW = w }
              Component.onCompleted: { var w = strip.fullW.slice(); w[index] = implicitWidth + Style.space(30); strip.fullW = w }
            }
          }
        }

        Rectangle {                                       // the sliding highlight
          x: strip.tabX(root.tab)
          y: strip.pad
          width: strip.tabW(root.tab)
          height: strip.height - strip.pad * 2
          radius: height / 2
          color: root.accent
          Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
          Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        }

        Repeater {
          model: root.tabs
          delegate: Item {
            id: tabItem
            required property var modelData
            required property int index
            readonly property bool current: root.tab === index
            readonly property bool iconOnly: strip.compact && !current
            x: strip.tabX(index)
            y: strip.pad
            width: strip.tabW(index)
            height: strip.height - strip.pad * 2
            Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
            Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

            Rectangle {                                   // hover wash on inactive tabs
              anchors.fill: parent
              radius: height / 2
              color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.07)
              opacity: tabMouse.containsMouse && !tabItem.current ? 1 : 0
              Behavior on opacity { NumberAnimation { duration: 140 } }
            }
            Row {
              anchors.centerIn: parent
              spacing: Style.space(7)
              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: tabItem.modelData.icon
                color: tabItem.current ? Color.background : Qt.darker(root.fg, 1.25)
                font.family: root.ff; font.pixelSize: Style.font.body + 1
                Behavior on color { ColorAnimation { duration: 200 } }
              }
              Text {
                visible: !tabItem.iconOnly
                anchors.verticalCenter: parent.verticalCenter
                text: root.t(tabItem.modelData.key)
                color: tabItem.current ? Color.background : Qt.darker(root.fg, 1.25)
                font.family: root.ff; font.pixelSize: Style.font.body
                font.bold: tabItem.current
                Behavior on color { ColorAnimation { duration: 200 } }
              }
            }
            MouseArea {
              id: tabMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.tab = tabItem.index
            }
            PanelToolTip {
              visible: tabItem.iconOnly && tabMouse.containsMouse
              text: root.t(tabItem.modelData.key)
            }
          }
        }
      }

      // ---- pages ----
      // Each page is created the first time it is shown and then kept while
      // the panel is open, so switching never rebuilds a heavy page. Switching
      // fades the current page out, swaps (the panel resizes while nothing is
      // visible — resizing a layer surface every frame is what made it jerk),
      // then fades/slides the new one in.
      Item {
        id: pageHost
        width: parent.width
        readonly property var current: pages.count > root.shownTab ? pages.itemAt(root.shownTab) : null
        height: current && current.item ? current.item.implicitHeight : 0
        transform: Translate { id: slide; y: 0 }

        Repeater {
          id: pages
          model: root.tabs
          delegate: Loader {
            id: pl
            required property var modelData
            required property int index
            property bool visited: false
            width: pageHost.width
            visible: root.shownTab === index
            active: root.opened && (visited || root.shownTab === index)
            Connections {
              target: root
              function onShownTabChanged() { if (root.shownTab === pl.index && root.opened) pl.visited = true }
              function onOpenedChanged() { pl.visited = root.opened && root.shownTab === pl.index }
            }
            source: Qt.resolvedUrl(modelData.file)
            onLoaded: item.host = root
          }
        }
      }
    }
  }
}
