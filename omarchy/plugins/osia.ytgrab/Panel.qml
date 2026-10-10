import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Video Grabber panel: paste a URL, a preview loads (yt-dlp -J), pick picture
// quality (or none / GIF) and sound quality (or none), download with
// yt-dlp + ffmpeg. The bar widget (BarWidget.qml) owns the button; this owns
// the flow. Downloads keep running while the panel is closed.
Panel {
  id: root
  moduleName: "osia.ytgrab"
  ipcTarget: "osia.ytgrab"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  readonly property color fg: bar ? bar.barForeground : Color.foreground
  readonly property string ff: bar ? bar.fontFamily : Style.font.family
  readonly property color accent: Color.accent
  readonly property string home: Quickshell.env("HOME")

  readonly property string dlDir: {
    var d = String(setting("downloadDir", "") || "").trim()
    if (!d) return home + "/Videos/ytgrab"
    if (d.indexOf("~/") === 0) d = home + d.substr(1)
    return d
  }

  // settings-backed choices
  property string video: setting("video", "best")
  property string audio: setting("audio", "best")
  property string prevVideo: video

  // preview state
  property bool infoLoading: false
  property string previewTitle: ""
  property string previewMeta: ""
  property string previewThumb: ""

  // download state
  property bool running: false
  property bool indeterminate: true
  property real progress: 0
  property string phase: ""             // "" | "dl" | "gif"
  property string dlState: "idle"       // idle | running | done | error
  property string statusText: ""
  property string lastFile: ""
  property string errText: ""
  property bool cancelled: false
  property bool hasYtdlp: true
  property bool hasFfmpeg: true

  function persist(values) {
    var e = { id: moduleName }
    for (var k in settings) if (k !== "id") e[k] = settings[k]
    for (var key in values) e[key] = values[key]
    settings = e
    if (hostWidget && "settings" in hostWidget) hostWidget.settings = e
    if (bar && bar.shell && typeof bar.shell.updateEntryInline === "function")
      bar.shell.updateEntryInline(moduleName, e)
  }

  // ---- lifecycle ----
  function open() {
    controller.show()
    Qt.callLater(function() {
      if (!root.opened) return
      if (!String(urlField.text).trim()) root.pasteFromClipboard()
      urlField.forceActiveFocus()
    })
  }
  function close() { controller.hide() }
  function toggle() { root.opened ? close() : open() }
  function openFolder() { Quickshell.execDetached(["xdg-open", root.dlDir]) }

  // ---- clipboard ----
  function pasteFromClipboard() { if (!pasteProc.running) pasteProc.running = true }

  Process {
    id: pasteProc
    command: ["sh", "-c", "command -v wl-paste >/dev/null && wl-paste -n || xclip -o -selection clipboard 2>/dev/null"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var t = String(text || "").trim()
        if (Model.looksLikeUrl(t)) { urlField.text = t; root.onUrlEdited() }
      }
    }
    stderr: StdioCollector { waitForEnd: true }
  }

  // ---- preview (yt-dlp -J) ----
  Timer { id: infoDebounce; interval: 550; onTriggered: root.fetchInfo() }

  function onUrlEdited() {
    root.previewTitle = ""; root.previewMeta = ""; root.previewThumb = ""
    if (root.dlState !== "running") { root.dlState = "idle"; root.statusText = "" }
    infoDebounce.restart()
  }

  function fetchInfo() {
    var u = String(urlField.text || "").trim()
    if (!u || !Model.looksLikeUrl(u)) { root.infoLoading = false; return }
    if (infoProc.running) infoProc.running = false
    root.infoLoading = true
    infoProc.command = ["yt-dlp", "-J", "--no-playlist", "--no-warnings", "--skip-download", u]
    infoProc.running = true
  }

  Process {
    id: infoProc
    stdout: StdioCollector { id: infoOut; waitForEnd: true }
    stderr: StdioCollector { waitForEnd: true }
    onExited: function(code) {
      root.infoLoading = false
      if (code !== 0) return
      var info = Model.parseInfo(infoOut.text)
      if (!info.ok) return
      root.previewTitle = info.title
      root.previewThumb = info.thumb
      var bits = []
      if (info.duration > 0) bits.push(Model.fmtDuration(info.duration))
      if (info.uploader) bits.push(info.uploader)
      root.previewMeta = bits.join("   ·   ")
    }
  }

  // ---- deps probe ----
  Process {
    running: true
    command: ["sh", "-c", "command -v yt-dlp >/dev/null && echo y || echo n; command -v ffmpeg >/dev/null && echo y || echo n"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var l = String(text || "").trim().split(/\s+/)
        root.hasYtdlp = l[0] === "y"
        root.hasFfmpeg = l[1] === "y"
      }
    }
  }

  // ---- download ----
  function startDownload() {
    if (root.running) return
    var u = String(urlField.text || "").trim()
    if (!u) { root.statusText = "Вставь ссылку на видео."; root.dlState = "idle"; return }
    if (root.video === "none" && root.audio === "none") {
      root.statusText = "Выбери видео или звук."; root.dlState = "idle"; return
    }
    if (!root.hasYtdlp || (Model.isGif(root.video) && !root.hasFfmpeg)) {
      root.dlState = "error"; root.indeterminate = false
      root.statusText = "Нужно: " + (!root.hasYtdlp ? "yt-dlp " : "") +
        (Model.isGif(root.video) && !root.hasFfmpeg ? "ffmpeg" : "") +
        "  —  omarchy pkg add yt-dlp ffmpeg"
      return
    }

    var c = Model.buildCommand({ url: u, video: root.video, audio: root.audio, dir: root.dlDir })
    root.running = true; root.dlState = "running"
    root.indeterminate = true; root.progress = 0
    root.phase = "dl"; root.cancelled = false; root.lastFile = ""; root.errText = ""
    root.statusText = Model.isGif(root.video) ? "Загрузка исходника…" : "Загрузка…"
    dlProc.command = c.argv
    dlProc.running = true
  }

  function cancelDownload() {
    if (!root.running) return
    root.cancelled = true
    dlProc.running = false
  }

  function handleLine(line) {
    line = String(line || "").trim()
    if (!line) return
    var p = Model.parseProgress(line)
    if (!p) return
    if (p.kind === "dl") {
      root.indeterminate = false
      root.progress = p.percent
      if (root.phase !== "gif") root.statusText = "Загрузка…  " + Math.round(p.percent) + "%"
    } else if (p.kind === "gifstart" || p.kind === "gif") {
      root.phase = "gif"; root.indeterminate = true
      root.statusText = "Конвертация в GIF…"
    } else if (p.kind === "done") {
      root.lastFile = p.path
    } else if (p.kind === "error") {
      root.errText = p.text
    }
  }

  Process {
    id: dlProc
    stdout: SplitParser { onRead: function(d) { root.handleLine(d) } }
    stderr: SplitParser { onRead: function(d) { root.handleLine(d) } }
    onExited: function(code) {
      root.running = false
      if (root.cancelled) {
        root.cancelled = false; root.dlState = "idle"
        root.indeterminate = true; root.statusText = "Отменено."
        return
      }
      if (code !== 0) {
        root.dlState = "error"; root.indeterminate = false
        root.statusText = code === 127 ? "yt-dlp не установлен."
          : (Model.friendlyError(root.errText) || ("Ошибка (код " + code + ")."))
        root.errText = ""
        return
      }
      root.dlState = "done"; root.indeterminate = false; root.progress = 100
      root.statusText = "Готово — " + (root.lastFile ? Model.baseName(root.lastFile) : root.dlDir)
      root.notifyDone()
    }
  }

  function notifyDone() {
    var msg = root.lastFile ? Model.baseName(root.lastFile) : ("Сохранено в " + root.dlDir)
    Quickshell.execDetached(["sh", "-lc",
      "command -v omarchy-notification-send >/dev/null && omarchy-notification-send -g 󰇚 'Video Grabber' " +
      Model.shq(msg) + " || notify-send -a 'Video Grabber' 'Video Grabber' " + Model.shq(msg)])
  }

  // ---- surface ----
  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: urlField
    contentWidth: panel.fittedContentWidth(Style.space(400))
    contentHeight: panel.fittedContentHeight(contentCol.implicitHeight)

    Column {
      id: contentCol
      width: parent.width
      spacing: Style.spacing.md

      Text {
        width: parent.width
        text: "VIDEO GRABBER"
        color: Qt.darker(root.fg, 1.4)
        font.family: root.ff
        font.pixelSize: Style.font.caption
        font.bold: true
        font.letterSpacing: 1.4
      }

      // ---- url row ----
      Row {
        width: parent.width
        height: Style.spacing.controlHeight
        spacing: Style.spacing.md

        TextField {
          id: urlField
          width: parent.width - pasteBtn.width - parent.spacing
          height: parent.height
          foreground: root.fg
          accent: root.accent
          placeholderText: "Вставь ссылку на видео…"
          verticalPadding: 6
          onTextChanged: root.onUrlEdited()
          onAccepted: if (!root.running) root.startDownload()
        }

        PanelActionButton {
          id: pasteBtn
          width: parent.height
          height: parent.height
          iconText: "󰆒"
          tooltipText: "Вставить из буфера"
          foreground: root.fg
          hoverColor: root.accent
          fontFamily: root.ff
          onClicked: root.pasteFromClipboard()
        }
      }

      // ---- preview ----
      Rectangle {
        width: parent.width
        height: Style.space(168)
        radius: Style.cornerRadius
        color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.06)
        clip: true

        Image {
          id: thumb
          anchors.fill: parent
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          cache: true
          source: root.previewThumb
          visible: status === Image.Ready
        }

        Rectangle {
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          height: parent.height * 0.55
          visible: thumb.visible
          gradient: Gradient {
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.68) }
          }
        }

        Column {
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          anchors.margins: Style.spacing.md
          spacing: Style.space(2)
          visible: thumb.visible && root.previewTitle !== ""

          Text {
            width: parent.width
            text: root.previewTitle
            color: "white"
            font.family: root.ff
            font.pixelSize: Style.font.body
            font.bold: true
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
          }
          Text {
            width: parent.width
            text: root.previewMeta
            color: Qt.rgba(1, 1, 1, 0.8)
            font.family: root.ff
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
          }
        }

        Text {
          anchors.centerIn: parent
          visible: !thumb.visible
          text: root.infoLoading ? "Загрузка превью…" : "Превью появится здесь"
          color: Qt.darker(root.fg, 1.5)
          font.family: root.ff
          font.pixelSize: Style.font.caption
        }
      }

      // ---- quality row ----
      Row {
        width: parent.width
        spacing: Style.spacing.md

        Dropdown {
          id: videoDd
          width: (parent.width - parent.spacing) / 2
          label: "Картинка"
          options: Model.videoOptions()
          value: root.video
          foreground: root.fg
          accent: root.accent
          fontFamily: root.ff
          onChanged: function(v) {
            if (Model.isSeparator(v)) { videoDd.value = root.prevVideo; return }
            root.prevVideo = v
            root.video = v
            root.persist({ video: v })
          }
        }

        Dropdown {
          id: audioDd
          width: (parent.width - parent.spacing) / 2
          label: "Звук"
          options: Model.audioOptions()
          value: root.audio
          enabled: !Model.isGif(root.video)
          opacity: enabled ? 1.0 : 0.45
          foreground: root.fg
          accent: root.accent
          fontFamily: root.ff
          onChanged: function(v) { root.audio = v; root.persist({ audio: v }) }
        }
      }

      // ---- download button ----
      Button {
        width: parent.width
        height: Style.spacing.controlHeight
        bordered: true
        text: root.running
          ? "Отмена"
          : (Model.isGif(root.video) ? "Скачать GIF" : (root.video === "none" ? "Скачать звук" : "Скачать"))
        iconText: root.running ? "󰜺" : "󰇚"
        foreground: root.fg
        accent: root.accent
        fontFamily: root.ff
        onClicked: root.running ? root.cancelDownload() : root.startDownload()
      }

      // ---- progress ----
      Rectangle {
        width: parent.width
        height: Style.space(4)
        radius: 2
        visible: root.running || root.dlState === "done" || root.dlState === "error"
        color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.15)

        Rectangle {
          height: parent.height
          radius: 2
          width: root.indeterminate ? parent.width
               : Math.max(Style.space(2), parent.width * root.progress / 100)
          color: root.dlState === "error" ? (root.bar ? root.bar.urgent : "#e06c75") : root.accent

          SequentialAnimation on opacity {
            running: root.indeterminate && root.running
            loops: Animation.Infinite
            NumberAnimation { from: 0.25; to: 0.7; duration: 700 }
            NumberAnimation { from: 0.7; to: 0.25; duration: 700 }
          }
        }
      }

      Text {
        width: parent.width
        visible: root.statusText !== ""
        text: root.statusText
        color: root.dlState === "error" ? (root.bar ? root.bar.urgent : "#e06c75")
             : root.dlState === "done" ? root.accent
             : Qt.darker(root.fg, 1.3)
        font.family: root.ff
        font.pixelSize: Style.font.caption
        wrapMode: Text.Wrap
        maximumLineCount: 2
        elide: Text.ElideRight
      }
    }
  }
}
