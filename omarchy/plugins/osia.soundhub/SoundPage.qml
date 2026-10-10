import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Sound: what Omarchy's own audio panel does — output and input device,
// their volume and mute, and per-application volume — in SoundHub's look.
// Same safety rules as the stock panel: lists feed Repeaters through debounced
// snapshots (PipeWire can remove nodes mid-signal), and the output volume acts
// on the physical sink behind any DSP sink (our EQ, a speaker tuning).
Column {
  id: page
  property var host: null
  spacing: Style.spacing.md

  readonly property color fg: host ? host.fg : "white"
  readonly property color accent: host ? host.accent : "white"
  readonly property string ff: host ? host.ff : ""

  readonly property var nodes: Pipewire.nodes ? Pipewire.nodes.values : []
  readonly property var sink: Pipewire.defaultAudioSink
  readonly property var source: Pipewire.defaultAudioSource

  readonly property var liveSinks: nodes.filter(function(n) {
    return n && n.isSink && !n.isStream && !Model.isInternalNode(n)
  })
  readonly property var liveSources: nodes.filter(function(n) {
    return n && !n.isSink && !n.isStream && Model.isAudioSource(n) && !Model.isInternalNode(n)
  })
  readonly property var liveStreams: nodes.filter(function(n) {
    return n && Model.isPlaybackStream(n) && !Model.isInternalNode(n) && n.audio
  })

  property var sinks: []
  property var sources: []
  property var streams: []
  function snapshot() { sinks = liveSinks.slice(); sources = liveSources.slice(); streams = liveStreams.slice() }
  onLiveSinksChanged: snap.restart()
  onLiveSourcesChanged: snap.restart()
  onLiveStreamsChanged: snap.restart()
  Timer { id: snap; interval: 120; onTriggered: page.snapshot() }
  Component.onCompleted: snapshot()

  PwObjectTracker { objects: page.liveSinks }
  PwObjectTracker { objects: page.liveSources }
  PwObjectTracker { objects: page.liveStreams }

  // ---- output volume lives on the physical sink behind any DSP sink ----
  property string volumeSinkName: ""
  readonly property var volumeSink: {
    if (!volumeSinkName || !sink) return sink
    for (var i = 0; i < nodes.length; i++) {
      var n = nodes[i]
      if (n && n.isSink && !n.isStream && String(n.name) === volumeSinkName && n.audio) return n
    }
    return sink
  }
  // The device shown as "selected": the physical one when a DSP sink fronts it.
  readonly property var shownSink: volumeSink || sink
  onSinkChanged: resolve.restart()
  Timer { id: resolve; interval: 200; onTriggered: if (!volumeProc.running) volumeProc.running = true }
  Process {
    id: volumeProc
    command: ["omarchy-audio-output-sink"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: page.volumeSinkName = String(text).trim() }
  }
  Timer { interval: 5000; running: page.visible; repeat: true; triggeredOnStart: true; onTriggered: resolve.restart() }

  PwObjectTracker { objects: [page.sink, page.source, page.volumeSink] }

  function setOutput(node) {
    if (!node) return
    if (host && typeof host.selectOutput === "function" && host.selectOutput(node)) return
    Pipewire.preferredDefaultAudioSink = node
    Quickshell.execDetached(["omarchy-audio-output-set-default", String(node.id), String(node.name)])
  }
  function setInput(node) {
    if (!node) return
    Pipewire.preferredDefaultAudioSource = node
    Quickshell.execDetached(["omarchy-audio-input-set-default", String(node.id), String(node.name)])
  }

  // ======== OUTPUT ========
  PanelSectionHeader {
    width: parent.width
    text: host ? host.t("snd.output") : ""
    foreground: page.fg; fontFamily: page.ff
    font.letterSpacing: 1.2
  }

  Dropdown {
    width: parent.width
    showLabel: false
    options: page.sinks.map(function(n) { return { value: String(n.name), label: Model.sinkGlyph(n) + "  " + Model.nodeLabel(n) } })
    value: page.shownSink ? String(page.shownSink.name) : ""
    foreground: page.fg; accent: page.accent; fontFamily: page.ff
    onChanged: function(v) {
      for (var i = 0; i < page.sinks.length; i++) if (String(page.sinks[i].name) === v) page.setOutput(page.sinks[i])
    }
  }

  Row {
    width: parent.width
    spacing: Style.spacing.sm
    readonly property bool muted: page.volumeSink && page.volumeSink.audio ? page.volumeSink.audio.muted : false
    readonly property real vol: page.volumeSink && page.volumeSink.audio ? page.volumeSink.audio.volume : 0
    PanelActionButton {
      anchors.verticalCenter: parent.verticalCenter
      iconText: Model.volumeGlyph(parent.vol, parent.muted)
      tooltipText: host ? host.t("snd.mute") : ""
      foreground: parent.muted ? (host ? host.urgent : "red") : page.fg
      hoverColor: page.accent; fontFamily: page.ff
      onClicked: if (page.volumeSink && page.volumeSink.audio) page.volumeSink.audio.muted = !page.volumeSink.audio.muted
    }
    PanelSlider {
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width - Style.space(84)
      bar: host ? host.bar : null
      minimum: 0; maximum: 1
      value: parent.vol
      fillColor: page.accent; knobColor: page.accent
      onMoved: function(v) { if (page.volumeSink && page.volumeSink.audio) page.volumeSink.audio.volume = v }
    }
    Text {
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(40)
      horizontalAlignment: Text.AlignRight
      text: Math.round(parent.vol * 100) + "%"
      color: Qt.darker(page.fg, 1.3)
      font.family: page.ff; font.pixelSize: Style.font.caption
    }
  }

  PanelSeparator { width: parent.width; foreground: page.fg }

  // ======== INPUT ========
  PanelSectionHeader {
    width: parent.width
    text: host ? host.t("snd.input") : ""
    foreground: page.fg; fontFamily: page.ff
    font.letterSpacing: 1.2
  }

  Text {
    visible: page.sources.length === 0
    text: host ? host.t("snd.noInput") : ""
    color: Qt.darker(page.fg, 1.5)
    font.family: page.ff; font.pixelSize: Style.font.caption
  }

  Dropdown {
    visible: page.sources.length > 0
    width: parent.width
    showLabel: false
    options: page.sources.map(function(n) { return { value: String(n.name), label: Model.sourceGlyph(n) + "  " + Model.nodeLabel(n) } })
    value: page.source ? String(page.source.name) : ""
    foreground: page.fg; accent: page.accent; fontFamily: page.ff
    onChanged: function(v) {
      for (var i = 0; i < page.sources.length; i++) if (String(page.sources[i].name) === v) page.setInput(page.sources[i])
    }
  }

  Row {
    visible: page.source !== null && !!page.source.audio
    width: parent.width
    spacing: Style.spacing.sm
    readonly property bool muted: page.source && page.source.audio ? page.source.audio.muted : false
    readonly property real vol: page.source && page.source.audio ? page.source.audio.volume : 0
    PanelActionButton {
      anchors.verticalCenter: parent.verticalCenter
      iconText: parent.muted ? "󰍭" : "󰍬"
      tooltipText: host ? host.t("snd.mute") : ""
      foreground: parent.muted ? (host ? host.urgent : "red") : page.fg
      hoverColor: page.accent; fontFamily: page.ff
      onClicked: if (page.source && page.source.audio) page.source.audio.muted = !page.source.audio.muted
    }
    Column {
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width - Style.space(84)
      spacing: Style.space(4)
      PanelSlider {
        width: parent.width
        bar: host ? host.bar : null
        minimum: 0; maximum: 1
        value: parent.parent.vol
        fillColor: page.accent; knobColor: page.accent
        onMoved: function(v) { if (page.source && page.source.audio) page.source.audio.volume = v }
      }
      // live input level
      Rectangle {
        width: parent.width
        height: Style.space(3)
        radius: height / 2
        color: Qt.rgba(page.fg.r, page.fg.g, page.fg.b, 0.10)
        Rectangle {
          height: parent.height; radius: height / 2
          width: parent.width * Math.min(1, peak.peak)
          color: page.accent
          Behavior on width { NumberAnimation { duration: 60 } }
        }
      }
    }
    Text {
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(40)
      horizontalAlignment: Text.AlignRight
      text: Math.round(parent.vol * 100) + "%"
      color: Qt.darker(page.fg, 1.3)
      font.family: page.ff; font.pixelSize: Style.font.caption
    }
  }

  PwNodePeakMonitor {
    id: peak
    node: page.source
    enabled: page.visible && !!page.source
  }

  PanelSeparator { width: parent.width; foreground: page.fg }

  // ======== APPLICATIONS ========
  PanelSectionHeader {
    width: parent.width
    text: host ? host.t("snd.apps") : ""
    foreground: page.fg; fontFamily: page.ff
    font.letterSpacing: 1.2
  }

  Text {
    visible: page.streams.length === 0
    width: parent.width
    wrapMode: Text.Wrap
    text: host ? host.t("snd.noApps") : ""
    color: Qt.darker(page.fg, 1.5)
    font.family: page.ff; font.pixelSize: Style.font.caption
  }

  Repeater {
    model: page.streams
    delegate: Row {
      id: streamRow
      required property var modelData
      width: page.width
      spacing: Style.spacing.sm
      readonly property bool muted: modelData && modelData.audio ? modelData.audio.muted : false
      readonly property real vol: modelData && modelData.audio ? modelData.audio.volume : 0

      PanelActionButton {
        anchors.verticalCenter: parent.verticalCenter
        iconText: Model.volumeGlyph(streamRow.vol, streamRow.muted)
        foreground: streamRow.muted ? (host ? host.urgent : "red") : page.fg
        hoverColor: page.accent; fontFamily: page.ff
        onClicked: if (streamRow.modelData && streamRow.modelData.audio) streamRow.modelData.audio.muted = !streamRow.modelData.audio.muted
      }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        width: Style.space(120)
        text: Model.streamLabel(streamRow.modelData)
        color: page.fg
        font.family: page.ff; font.pixelSize: Style.font.body
        elide: Text.ElideRight
      }
      PanelSlider {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - Style.space(212)
        bar: host ? host.bar : null
        minimum: 0; maximum: 1
        value: streamRow.vol
        fillColor: page.accent; knobColor: page.accent
        onMoved: function(v) { if (streamRow.modelData && streamRow.modelData.audio) streamRow.modelData.audio.volume = v }
      }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        width: Style.space(40)
        horizontalAlignment: Text.AlignRight
        text: Math.round(streamRow.vol * 100) + "%"
        color: Qt.darker(page.fg, 1.3)
        font.family: page.ff; font.pixelSize: Style.font.caption
      }
    }
  }
}
