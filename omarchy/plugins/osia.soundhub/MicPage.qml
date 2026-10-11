import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.Commons
import "Model.js" as Model

// Microphone tab: the mic itself (device, level, mute, a quick test) and its
// processing (bin/soundhub-mic: noise suppression, high-pass, gate,
// compressor, voice EQ, gain, limiter) with presets. The processed mic is a
// virtual source, "SoundHub microphone", made the default while it is on, so
// calls and recorders pick it up by themselves.
Column {
  id: page
  property var host: null
  spacing: HubStyle.gap
  readonly property color fg: host ? host.fg : Color.foreground
  readonly property color accent: host ? host.accent : Color.accent
  readonly property color bgc: host ? host.bgc : Color.background
  readonly property string ff: host ? host.ff : Style.font.family
  readonly property bool ru: host ? host.lang === "ru" : true
  function t(a, b) { return ru ? a : b }

  // ------------------------------------------------------------ devices
  readonly property var nodes: Pipewire.nodes ? Pipewire.nodes.values : []
  readonly property var sources: nodes.filter(function(n) {
    return n && !n.isSink && !n.isStream && Model.isAudioSource(n) && !Model.isInternalNode(n)
  })
  // the physical mic: what the processing reads while on, else the default
  readonly property var defaultSrc: Pipewire.defaultAudioSource
  readonly property var mic: {
    if (st.enabled && st.target) for (var i = 0; i < sources.length; i++) if (String(sources[i].name) === st.target) return sources[i]
    return defaultSrc && !Model.isInternalNode(defaultSrc) ? defaultSrc : (sources.length ? sources[0] : null)
  }
  PwObjectTracker { objects: [page.mic, page.defaultSrc] }
  readonly property bool muted: mic && mic.audio ? mic.audio.muted : false
  function pick(name) {
    if (st.enabled) { cmd(["retarget", name]); return }
    for (var i = 0; i < sources.length; i++) if (String(sources[i].name) === name) {
      Pipewire.preferredDefaultAudioSource = sources[i]
      Quickshell.execDetached(["omarchy-audio-input-set-default", String(sources[i].id), String(sources[i].name)])
    }
  }

  // ------------------------------------------------------------ backend
  readonly property string bin: decodeURIComponent(Qt.resolvedUrl("bin/soundhub-mic").toString().replace(/^file:\/\//, ""))
  property var st: ({ enabled: false, noise: "webrtc", noiseStrength: 30, highpass: 80, gate: true, gateDb: -50, comp: true,
                      compDb: -22, ratio: 3, eq: [0, -2, 3, 2], gainDb: 0, limiter: true, preset: "voice", deepfilter: false })
  property bool busy: false
  property string error: ""
  property var queue: []
  Process {
    id: proc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try { var d = JSON.parse(text); page.st = d; page.error = d.ok ? "" : d.error } catch (e) {}
        page.busy = false
        page.next()
      }
    }
  }
  function next() {
    if (proc.running || !queue.length) return
    var c = queue[0]; queue = queue.slice(1)
    busy = true; proc.command = [bin].concat(c); proc.running = true
  }
  function cmd(args) { queue = queue.concat([args]); next() }
  function set(obj) { cmd(["set", JSON.stringify(obj)]) }
  Component.onCompleted: cmd(["status"])

  // ------------------------------------------------------------- testing
  property string testState: ""                  // "" | rec | play
  Process {
    id: test
    command: ["bash", "-c", "f=\"${XDG_RUNTIME_DIR:-/tmp}/soundhub-mictest.wav\"; echo rec; timeout 5 pw-record --target \"$1\" \"$f\"; echo play; pw-play \"$f\"; rm -f \"$f\"", "_",
              page.st.enabled ? "soundhub_mic" : (page.mic ? String(page.mic.name) : "")]
    stdout: SplitParser { onRead: function(l) { page.testState = l.trim() } }
    onExited: page.testState = ""
  }
  Process {
    id: monitor                                  // hear yourself (use headphones)
    command: ["pw-loopback", "--capture-props=target.object=" + (page.st.enabled ? "soundhub_mic" : (page.mic ? String(page.mic.name) : "")) + " node.passive=true",
              "--playback-props=media.role=Communication node.name=soundhub_mic_monitor"]
  }
  Component.onDestruction: monitor.running = false

  component Card: HubCard {
    width: page.width
    height: inner.implicitHeight + HubStyle.pad * 2
    fg: page.fg; accent: page.accent
    default property alias content: inner.data
    Column {
      id: inner
      x: HubStyle.pad; y: HubStyle.pad
      width: parent.width - HubStyle.pad * 2
      spacing: Style.space(10)
    }
  }

  // ---------------------------------------------------------- the mic
  Card {
    HubCaption { text: page.t("Микрофон", "Microphone"); icon: "\u{f036c}"; fg: page.fg; fontFamily: page.ff }
    HubSelect {
      width: parent.width
      showLabel: false
      options: page.sources.map(function(n) { return { value: String(n.name), label: Model.sourceGlyph(n) + "  " + Model.nodeLabel(n) } })
      value: page.mic ? String(page.mic.name) : ""
      foreground: page.fg; accent: page.accent; background: page.bgc; fontFamily: page.ff
      onChanged: function(v) { page.pick(v) }
    }
    Row {
      width: parent.width
      spacing: Style.space(10)
      HubChip {
        anchors.verticalCenter: parent.verticalCenter
        iconOnly: true
        icon: page.muted ? "\u{f036d}" : "\u{f036c}"
        label: page.t("Выключить звук", "Mute")
        on: page.muted
        fg: page.fg; accent: page.accent; ink: page.bgc; fontFamily: page.ff
        onClicked: if (page.mic && page.mic.audio) page.mic.audio.muted = !page.mic.audio.muted
      }
      Column {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - Style.space(56)
        spacing: Style.space(6)
        HubSlider {
          width: parent.width
          minimum: 0; maximum: 1.5; step: 0.01
          value: page.mic && page.mic.audio ? page.mic.audio.volume : 0
          fillColor: page.accent; fontFamily: page.ff
          onMoved: function(v) { if (page.mic && page.mic.audio) page.mic.audio.volume = v }
        }
        Rectangle {                                   // live level of what apps get
          width: parent.width; height: Style.space(4); radius: height / 2
          color: HubStyle.tint(page.fg, 0.10)
          Rectangle {
            height: parent.height; radius: height / 2
            width: parent.width * Math.min(1, peak.peak)
            color: peak.peak > 0.9 ? Color.urgent : page.accent
            Behavior on width { NumberAnimation { duration: 60 } }
          }
        }
      }
    }
    PwNodePeakMonitor {
      id: peak
      node: page.st.enabled ? page.processed : page.mic
      enabled: page.visible
    }
    Flow {
      width: parent.width
      spacing: Style.space(6)
      HubChip {
        icon: page.testState === "rec" ? "\u{f044b}" : page.testState === "play" ? "\u{f040a}" : "\u{f036c}"
        label: page.testState === "rec" ? page.t("Говорите… 5 с", "Speak… 5 s") : page.testState === "play" ? page.t("Слушаем", "Playing back")
               : page.t("Проверить: записать и прослушать", "Test: record and play back")
        on: page.testState !== ""
        fg: page.fg; accent: page.accent; ink: page.bgc; fontFamily: page.ff
        onClicked: if (!test.running) test.running = true
      }
      HubChip {
        icon: "\u{f02cb}"
        label: page.t("Слышать себя", "Hear yourself")
        on: monitor.running
        fg: page.fg; accent: page.accent; ink: page.bgc; fontFamily: page.ff
        onClicked: monitor.running = !monitor.running
      }
    }
  }
  readonly property var processed: {
    for (var i = 0; i < nodes.length; i++) if (nodes[i] && String(nodes[i].name) === "soundhub_mic" && !nodes[i].isStream) return nodes[i]
    return null
  }
  PwObjectTracker { objects: [page.processed] }

  // ---------------------------------------------------------- processing
  Card {
    HubRow {
      title: page.t("Обработка голоса", "Voice processing")
      hint: page.error !== "" ? page.error
            : page.st.enabled ? page.t("Приложения получают «SoundHub microphone»", "Apps get “SoundHub microphone”")
            : page.t("Шумоподавление, выравнивание громкости, эквалайзер — как у стримеров", "Noise suppression, levelling, EQ — a streamer's chain")
      fg: page.fg; fontFamily: page.ff
      HubSwitch {
        checked: !!page.st.enabled
        fg: page.fg; accent: page.accent; ink: page.bgc
        onToggled: page.cmd(page.st.enabled ? ["disable"] : ["enable"].concat(page.mic ? ["--target", String(page.mic.name)] : []))
      }
    }
    Flow {
      width: parent.width
      spacing: Style.space(6)
      Repeater {
        model: [{ id: "voice", label: page.t("Голос", "Voice") }, { id: "call", label: page.t("Звонок", "Call") },
                { id: "stream", label: page.t("Стрим", "Stream") }, { id: "noisy", label: page.t("Шумно", "Noisy room") },
                { id: "natural", label: page.t("Как есть", "Natural") }]
        delegate: HubChip {
          required property var modelData
          label: modelData.label
          on: page.st.preset === modelData.id
          subtle: true
          h: Style.space(26)
          fg: page.fg; accent: page.accent; fontFamily: page.ff
          onClicked: page.cmd(["preset", modelData.id])
        }
      }
    }
    HubRow {
      title: page.t("Шумоподавление", "Noise suppression"); fg: page.fg; fontFamily: page.ff
      HubSelect {
        width: Style.space(190); showLabel: false
        options: [{ value: "off", label: page.t("Выкл", "Off") }, { value: "webrtc", label: page.t("WebRTC (встроено)", "WebRTC (built in)") }]
                 .concat(page.st.deepfilter ? [{ value: "deepfilter", label: page.t("DeepFilterNet (ИИ)", "DeepFilterNet (AI)") }] : [])
        value: String(page.st.noise)
        foreground: page.fg; accent: page.accent; background: page.bgc; fontFamily: page.ff
        onChanged: function(v) { page.set({ noise: v }) }
      }
    }
    HubRow {
      visible: !page.st.deepfilter
      title: page.t("DeepFilterNet — лучшее ИИ-шумоподавление", "DeepFilterNet — the best AI noise suppression")
      hint: page.t("Пакет deepfilternet-plugin-pipewire-bin (AUR, сборка автора). Ставится в терминале", "Package deepfilternet-plugin-pipewire-bin (AUR, the author's build). Installs in a terminal")
      fg: page.fg; fontFamily: page.ff
      HubChip {
        icon: "\u{f01da}"; label: page.t("Установить", "Install")
        fg: page.fg; accent: page.accent; ink: page.bgc; fontFamily: page.ff
        onClicked: { Quickshell.execDetached(["omarchy-launch-floating-terminal-with-presentation", "yay -S --needed deepfilternet-plugin-pipewire-bin"]); recheck.restart() }
        Timer { id: recheck; interval: 20000; repeat: true; onTriggered: { page.cmd(["status"]); if (page.st.deepfilter) stop() } }
      }
    }
    HubRow {
      visible: page.st.noise === "deepfilter"
      title: page.t("Сила подавления", "Strength"); fg: page.fg; fontFamily: page.ff
      HubSlider {
        width: Style.space(190); minimum: 10; maximum: 100; step: 5
        value: Number(page.st.noiseStrength); format: function(v) { return Math.round(v) + " dB" }
        fillColor: page.accent; fontFamily: page.ff
        onReleased: function(v) { page.set({ noiseStrength: Math.round(v) }) }
      }
    }
    HubRow {
      title: page.t("Срез низов", "High-pass"); hint: page.t("Убирает гул, стук и ветер", "Removes rumble, thumps and wind"); fg: page.fg; fontFamily: page.ff
      HubSelect {
        width: Style.space(190); showLabel: false
        options: [0, 70, 80, 100, 120].map(function(f) { return { value: String(f), label: f ? f + page.t(" Гц", " Hz") : page.t("Выкл", "Off") } })
        value: String(page.st.highpass)
        foreground: page.fg; accent: page.accent; background: page.bgc; fontFamily: page.ff
        onChanged: function(v) { page.set({ highpass: parseInt(v, 10) }) }
      }
    }
    HubRow {
      title: page.t("Шумовой гейт", "Noise gate"); hint: page.t("Глушит тишину между фразами", "Silences the gaps between phrases"); fg: page.fg; fontFamily: page.ff
      Row {
        spacing: Style.space(8)
        HubSlider {
          anchors.verticalCenter: parent.verticalCenter
          visible: !!page.st.gate
          width: Style.space(130); minimum: -70; maximum: -25; step: 1
          value: Number(page.st.gateDb); format: function(v) { return Math.round(v) + " dB" }
          fillColor: page.accent; fontFamily: page.ff
          onReleased: function(v) { page.set({ gateDb: Math.round(v) }) }
        }
        HubSwitch { anchors.verticalCenter: parent.verticalCenter; checked: !!page.st.gate; fg: page.fg; accent: page.accent; ink: page.bgc; onToggled: page.set({ gate: !page.st.gate }) }
      }
    }
    HubRow {
      title: page.t("Компрессор", "Compressor"); hint: page.t("Выравнивает тихое и громкое", "Evens out quiet and loud"); fg: page.fg; fontFamily: page.ff
      HubSwitch { checked: !!page.st.comp; fg: page.fg; accent: page.accent; ink: page.bgc; onToggled: page.set({ comp: !page.st.comp }) }
    }
    HubCaption { text: page.t("Эквалайзер голоса", "Voice EQ"); icon: "󰺢"; fg: page.fg; fontFamily: page.ff }
    Repeater {
      model: [{ i: 0, label: page.t("Низ · 120 Гц", "Low · 120 Hz") }, { i: 1, label: page.t("Бубнение · 300 Гц", "Mud · 300 Hz") },
              { i: 2, label: page.t("Разборчивость · 3,5 кГц", "Presence · 3.5 kHz") }, { i: 3, label: page.t("Воздух · 10 кГц", "Air · 10 kHz") }]
      delegate: HubRow {
        required property var modelData
        title: modelData.label; fg: page.fg; fontFamily: page.ff
        HubSlider {
          width: Style.space(190); minimum: -12; maximum: 12; step: 0.5
          value: page.st.eq ? Number(page.st.eq[modelData.i]) : 0
          format: function(v) { return (v > 0 ? "+" : "") + v.toFixed(1) + " dB" }
          fillColor: page.accent; fontFamily: page.ff
          onReleased: function(v) { var e = page.st.eq.slice(); e[modelData.i] = v; page.set({ eq: e }) }
        }
      }
    }
    HubRow {
      title: page.t("Усиление", "Gain"); hint: page.t("Выше 0 дБ — громче, лимитер не даст перегрузить", "Above 0 dB is louder; the limiter stops clipping"); fg: page.fg; fontFamily: page.ff
      HubSlider {
        width: Style.space(190); minimum: -10; maximum: 20; step: 0.5
        value: Number(page.st.gainDb); format: function(v) { return (v > 0 ? "+" : "") + v.toFixed(1) + " dB" }
        fillColor: page.accent; fontFamily: page.ff
        onReleased: function(v) { page.set({ gainDb: v }) }
      }
    }
    HubRow {
      title: page.t("Лимитер", "Limiter"); fg: page.fg; fontFamily: page.ff
      HubSwitch { checked: !!page.st.limiter; fg: page.fg; accent: page.accent; ink: page.bgc; onToggled: page.set({ limiter: !page.st.limiter }) }
    }
  }
}
