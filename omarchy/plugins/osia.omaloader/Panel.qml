import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Omaloader panel, two browser-style tabs:
//   Downloader — paste a URL, a preview loads (yt-dlp -J), pick picture quality
//                (or none / GIF) and sound quality (or none), download with
//                yt-dlp + ffmpeg.
//   Настройки  — download options and a proxy manager. The proxy applies only to
//                this plugin's own yt-dlp / curl calls, never system-wide.
// The bar widget (BarWidget.qml) owns the button; this owns the flow.
// Downloads keep running while the panel is closed.
Panel {
  id: root
  moduleName: "osia.omaloader"
  ipcTarget: "osia.omaloader"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  readonly property color fg: bar ? bar.barForeground : Color.foreground
  readonly property string ff: bar ? bar.fontFamily : Style.font.family
  readonly property color accent: Color.accent
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property string home: Quickshell.env("HOME")
  readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"

  property int tab: 0                   // 0 downloader | 1 settings

  // Reads straight from `settings`, so bindings follow persist().
  function opt(key, fallback) {
    return settings && settings[key] !== undefined && settings[key] !== null ? settings[key] : fallback
  }

  readonly property string dlDir: {
    var d = String(opt("downloadDir", "") || "").trim()
    if (!d) return home + "/Videos/Omaloader"
    if (d.indexOf("~/") === 0) d = home + d.substr(1)
    return d
  }

  // settings-backed choices
  property string video: setting("video", "best")
  property string audio: setting("audio", "best")
  property string prevVideo: video

  // proxy manager state
  readonly property var proxies: Array.isArray(opt("proxies", null)) ? opt("proxies", []) : []
  readonly property string activeProxy: {
    var u = String(opt("activeProxy", "") || "")
    for (var i = 0; i < proxies.length; i++) if (proxies[i].url === u) return u
    return ""
  }
  property var proxyStatus: ({})        // url -> { ok, text }
  property string testingUrl: ""
  property string proxyFormError: ""

  // preview state
  property bool infoLoading: false
  property string previewTitle: ""
  property string previewMeta: ""
  property string previewThumb: ""      // file:// of the locally fetched thumbnail
  property int thumbSeq: 0
  property string thumbFile: ""

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

  // Everything the settings tab feeds into yt-dlp.
  function collectOpts() {
    return {
      proxy: root.activeProxy,
      cookies: String(opt("cookies", "") || ""),
      rate: String(opt("rate", "") || ""),
      fragments: opt("fragments", true) === true,
      playlist: opt("playlist", false) === true,
      container: String(opt("container", "auto") || "auto"),
      audioFormat: String(opt("audioFormat", "m4a") || "m4a"),
      embedThumb: opt("embedThumb", false) === true,
      embedSubs: opt("embedSubs", false) === true,
      subLangs: String(opt("subLangs", "ru,en") || "ru,en"),
      sponsor: opt("sponsor", false) === true
    }
  }

  // ---- lifecycle ----
  function open() {
    controller.show()
    Qt.callLater(function() {
      if (!root.opened) return
      if (root.tab !== 0) return
      if (root.opt("autoPaste", false) === true && !String(urlField.text).trim()) root.pasteFromClipboard()
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
        if (Model.looksLikeUrl(t)) { root.tab = 0; urlField.text = t; root.onUrlEdited() }
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
    infoProc.command = Model.infoCommand(u, root.collectOpts())
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
      var bits = []
      if (info.duration > 0) bits.push(Model.fmtDuration(info.duration))
      if (info.uploader) bits.push(info.uploader)
      root.previewMeta = bits.join("   ·   ")
      if (info.thumb) root.fetchThumb(info.thumb)
    }
  }

  // Thumbnail goes through the plugin's proxy too: curl it to a local file.
  function fetchThumb(url) {
    if (thumbProc.running) thumbProc.running = false
    root.thumbSeq += 1
    var dest = root.runtimeDir + "/osia-omaloader-thumb-" + root.thumbSeq + ".img"
    thumbProc.dest = dest
    thumbProc.command = Model.thumbCommand(url, root.activeProxy, dest)
    thumbProc.running = true
  }

  Process {
    id: thumbProc
    property string dest: ""
    onExited: function(code) {
      if (code !== 0) return
      var old = root.thumbFile
      root.thumbFile = dest
      root.previewThumb = "file://" + dest
      if (old && old !== dest) Quickshell.execDetached(["rm", "-f", old])
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

    var c = Model.buildCommand({ url: u, video: root.video, audio: root.audio,
                                 dir: root.dlDir, opts: root.collectOpts() })
    root.running = true; root.dlState = "running"
    root.indeterminate = true; root.progress = 0
    root.phase = "dl"; root.cancelled = false; root.lastFile = ""; root.errText = ""
    root.statusText = (Model.isGif(root.video) ? "Загрузка исходника…" : "Загрузка…") +
      (root.activeProxy ? "  (через прокси)" : "")
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
      if (root.opt("notify", true) === true) root.notifyDone()
      if (root.opt("openAfter", false) === true) root.openFolder()
    }
  }

  function notifyDone() {
    var msg = root.lastFile ? Model.baseName(root.lastFile) : ("Сохранено в " + root.dlDir)
    Quickshell.execDetached(["sh", "-lc",
      "command -v omarchy-notification-send >/dev/null && omarchy-notification-send -g 󰇚 'Omaloader' " +
      Model.shq(msg) + " || notify-send -a 'Omaloader' 'Omaloader' " + Model.shq(msg)])
  }

  // ---- proxy manager ----
  function addProxy(name, url) {
    name = String(name || "").trim()
    url = String(url || "").trim()
    if (!Model.validProxy(url)) {
      root.proxyFormError = "Адрес вида socks5://host:port или http://user:pass@host:port"
      return false
    }
    for (var i = 0; i < root.proxies.length; i++) {
      if (root.proxies[i].url === url) { root.proxyFormError = "Такой прокси уже есть."; return false }
    }
    var list = root.proxies.slice()
    list.push({ name: name || Model.maskProxy(url).replace(/^[a-z0-9]+:\/\//i, ""), url: url })
    var values = { proxies: list }
    if (!root.activeProxy) values.activeProxy = url       // first one becomes active
    root.persist(values)
    root.proxyFormError = ""
    return true
  }

  function removeProxy(url) {
    var list = root.proxies.filter(function(p) { return p.url !== url })
    var values = { proxies: list }
    if (root.activeProxy === url) values.activeProxy = ""
    root.persist(values)
    var st = Object.assign({}, root.proxyStatus); delete st[url]; root.proxyStatus = st
  }

  function testProxy(url) {
    if (testProc.running) return
    root.testingUrl = url
    var st = Object.assign({}, root.proxyStatus); st[url] = { ok: true, text: "Проверка…" }; root.proxyStatus = st
    testProc.command = Model.proxyTestCommand(url)
    testProc.running = true
  }

  Process {
    id: testProc
    stdout: StdioCollector { id: testOut; waitForEnd: true }
    stderr: StdioCollector { waitForEnd: true }
    onExited: function(code) {
      var st = Object.assign({}, root.proxyStatus)
      st[root.testingUrl] = Model.parseProxyTest(testOut.text, code)
      root.proxyStatus = st
      root.testingUrl = ""
    }
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

      // ---- browser-style tab strip ----
      Item {
        width: parent.width
        height: Style.spacing.controlHeight

        Rectangle {                     // strip baseline
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          height: 1
          color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.15)
        }

        Row {
          anchors.left: parent.left
          anchors.bottom: parent.bottom
          height: parent.height
          spacing: Style.space(2)

          Repeater {
            model: [
              { icon: "󰇚", label: "Downloader" },
              { icon: "󰒓", label: "Настройки" }
            ]

            delegate: Rectangle {
              id: tabItem
              required property var modelData
              required property int index
              readonly property bool current: root.tab === index

              width: tabRow.implicitWidth + Style.space(28)
              height: parent.height
              topLeftRadius: Math.min(Style.cornerRadius, 8)
              topRightRadius: Math.min(Style.cornerRadius, 8)
              color: current ? Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.10)
                   : tabMouse.containsMouse ? Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.05)
                   : "transparent"

              Rectangle {               // active tab accent edge
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: 2
                topLeftRadius: parent.topLeftRadius
                topRightRadius: parent.topRightRadius
                color: root.accent
                visible: tabItem.current
              }

              Row {
                id: tabRow
                anchors.centerIn: parent
                spacing: Style.space(6)
                Text {
                  text: tabItem.modelData.icon
                  color: tabItem.current ? root.accent : Qt.darker(root.fg, 1.4)
                  font.family: root.ff
                  font.pixelSize: Style.font.body
                }
                Text {
                  text: tabItem.modelData.label
                  color: tabItem.current ? root.fg : Qt.darker(root.fg, 1.4)
                  font.family: root.ff
                  font.pixelSize: Style.font.body
                  font.bold: tabItem.current
                }
              }

              MouseArea {
                id: tabMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.tab = tabItem.index
                  if (tabItem.index === 0) urlField.forceActiveFocus()
                }
              }
            }
          }
        }

        // busy dot on the strip while a download runs and settings are open
        Rectangle {
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          width: Style.space(6); height: width; radius: width / 2
          color: root.accent
          visible: root.running && root.tab !== 0
        }
      }

      // ---- tab pages; settings scrolls inside the downloader page's height ----
      Item {
        width: parent.width
        height: grabCol.implicitHeight

        // ======== tab 0: downloader ========
        Column {
          id: grabCol
          width: parent.width
          spacing: Style.spacing.md
          visible: root.tab === 0

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
              cache: false
              source: root.previewThumb
              visible: status === Image.Ready && root.previewThumb !== ""
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
              text: root.infoLoading ? "Загрузка превью…"
                  : (root.previewTitle !== "" ? root.previewTitle : "Превью появится здесь")
              width: parent.width - Style.spacing.md * 2
              horizontalAlignment: Text.AlignHCenter
              elide: Text.ElideRight
              color: Qt.darker(root.fg, 1.5)
              font.family: root.ff
              font.pixelSize: Style.font.caption
            }

            Text {                      // proxy badge
              anchors.top: parent.top
              anchors.right: parent.right
              anchors.margins: Style.spacing.sm
              visible: root.activeProxy !== ""
              text: "󰖟 прокси"
              color: thumb.visible ? "white" : root.accent
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
              color: root.dlState === "error" ? root.urgent : root.accent

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
            color: root.dlState === "error" ? root.urgent
                 : root.dlState === "done" ? root.accent
                 : Qt.darker(root.fg, 1.3)
            font.family: root.ff
            font.pixelSize: Style.font.caption
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
          }
        }

        // ======== tab 1: settings ========
        Flickable {
          id: settingsFlick
          anchors.fill: parent
          visible: root.tab === 1
          contentWidth: width
          contentHeight: setCol.implicitHeight
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          flickableDirection: Flickable.VerticalFlick
          interactive: contentHeight > height
          ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

          Column {
            id: setCol
            width: settingsFlick.width - Style.space(8)   // room for the scrollbar
            spacing: Style.spacing.md

            // ---- proxy ----
            PanelSectionHeader { width: parent.width; text: "ПРОКСИ"; foreground: root.fg; fontFamily: root.ff; font.letterSpacing: 1.2 }

            Dropdown {
              width: parent.width
              label: "Активный прокси"
              options: [{ value: "", label: "Без прокси" }].concat(root.proxies.map(function(p) {
                return { value: p.url, label: p.name }
              }))
              value: root.activeProxy
              foreground: root.fg
              accent: root.accent
              fontFamily: root.ff
              onChanged: function(v) { root.persist({ activeProxy: v }) }
            }

            Repeater {
              model: root.proxies

              delegate: Rectangle {
                id: proxyRow
                required property var modelData
                readonly property bool isActive: modelData.url === root.activeProxy
                readonly property var status: root.proxyStatus[modelData.url]

                width: setCol.width
                height: Style.spacing.controlHeight + Style.space(8)
                radius: Style.cornerRadius
                color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, isActive ? 0.09 : 0.04)
                border.width: isActive ? 1 : 0
                border.color: root.accent

                Column {
                  anchors.left: parent.left
                  anchors.leftMargin: Style.spacing.md
                  anchors.right: proxyActions.left
                  anchors.rightMargin: Style.spacing.sm
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(1)

                  Text {
                    width: parent.width
                    text: (proxyRow.isActive ? "● " : "") + proxyRow.modelData.name
                    color: proxyRow.isActive ? root.accent : root.fg
                    font.family: root.ff
                    font.pixelSize: Style.font.body
                    font.bold: proxyRow.isActive
                    elide: Text.ElideRight
                  }
                  Text {
                    width: parent.width
                    text: Model.maskProxy(proxyRow.modelData.url) +
                          (proxyRow.status ? "   ·   " + proxyRow.status.text : "")
                    color: proxyRow.status && !proxyRow.status.ok ? root.urgent : Qt.darker(root.fg, 1.4)
                    font.family: root.ff
                    font.pixelSize: Style.font.caption
                    elide: Text.ElideMiddle
                  }
                }

                Row {
                  id: proxyActions
                  anchors.right: parent.right
                  anchors.rightMargin: Style.spacing.sm
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(2)

                  PanelActionButton {
                    iconText: proxyRow.isActive ? "󰄬" : "󰐕"
                    tooltipText: proxyRow.isActive ? "Активен" : "Сделать активным"
                    foreground: proxyRow.isActive ? root.accent : root.fg
                    hoverColor: root.accent
                    fontFamily: root.ff
                    onClicked: root.persist({ activeProxy: proxyRow.isActive ? "" : proxyRow.modelData.url })
                  }
                  PanelActionButton {
                    iconText: "󰓅"
                    tooltipText: "Проверить связь"
                    foreground: root.fg
                    hoverColor: root.accent
                    fontFamily: root.ff
                    enabled: !testProc.running
                    onClicked: root.testProxy(proxyRow.modelData.url)
                  }
                  PanelActionButton {
                    iconText: "󰆴"
                    tooltipText: "Удалить"
                    foreground: root.fg
                    hoverColor: root.urgent
                    fontFamily: root.ff
                    onClicked: root.removeProxy(proxyRow.modelData.url)
                  }
                }
              }
            }

            Row {
              width: parent.width
              height: Style.spacing.controlHeight
              spacing: Style.spacing.sm

              TextField {
                id: proxyName
                width: Math.round(parent.width * 0.3)
                height: parent.height
                foreground: root.fg
                accent: root.accent
                placeholderText: "Имя"
                verticalPadding: 6
                onAccepted: proxyUrl.forceActiveFocus()
              }
              TextField {
                id: proxyUrl
                width: parent.width - proxyName.width - addProxyBtn.width - parent.spacing * 2
                height: parent.height
                foreground: root.fg
                accent: root.accent
                placeholderText: "socks5://127.0.0.1:1080"
                verticalPadding: 6
                onTextChanged: root.proxyFormError = ""
                onAccepted: addProxyBtn.clicked()
              }
              PanelActionButton {
                id: addProxyBtn
                width: parent.height
                height: parent.height
                iconText: "󰐕"
                tooltipText: "Добавить прокси"
                foreground: root.fg
                hoverColor: root.accent
                fontFamily: root.ff
                bordered: true
                onClicked: {
                  if (root.addProxy(proxyName.text, proxyUrl.text)) { proxyName.text = ""; proxyUrl.text = "" }
                }
              }
            }

            Text {
              width: parent.width
              font.family: root.ff
              font.pixelSize: Style.font.caption
              wrapMode: Text.Wrap
              text: root.proxyFormError !== "" ? root.proxyFormError
                : "Действует только для Omaloader: превью и загрузка. Поддерживаются http, https, socks4 и socks5."
              color: root.proxyFormError !== "" ? root.urgent : Qt.darker(root.fg, 1.5)
            }

            PanelSeparator { width: parent.width; foreground: root.fg }

            // ---- download ----
            PanelSectionHeader { width: parent.width; text: "ЗАГРУЗКА"; foreground: root.fg; fontFamily: root.ff; font.letterSpacing: 1.2 }

            TextField {
              width: parent.width
              height: Style.spacing.controlHeight
              foreground: root.fg
              accent: root.accent
              placeholderText: "Папка: ~/Videos/Omaloader"
              verticalPadding: 6
              text: String(root.opt("downloadDir", "") || "")
              onEditingFinished: if (text !== String(root.opt("downloadDir", "") || "")) root.persist({ downloadDir: text.trim() })
            }

            Toggle {
              width: parent.width
              label: "Автовставка ссылки"
              description: "При открытии подставлять ссылку из буфера обмена. ПКМ по значку вставляет всегда"
              checked: root.opt("autoPaste", false) === true
              foreground: root.fg
              accent: root.accent
              fontFamily: root.ff
              titleSize: Style.font.body
              onClicked: root.persist({ autoPaste: !checked })
            }

            Row {
              width: parent.width
              spacing: Style.spacing.md

              Dropdown {
                width: (parent.width - parent.spacing) / 2
                label: "Контейнер видео"
                options: Model.containerOptions()
                value: String(root.opt("container", "auto"))
                foreground: root.fg
                accent: root.accent
                fontFamily: root.ff
                onChanged: function(v) { root.persist({ container: v }) }
              }
              Dropdown {
                width: (parent.width - parent.spacing) / 2
                label: "Формат звука"
                options: Model.audioFormatOptions()
                value: String(root.opt("audioFormat", "m4a"))
                foreground: root.fg
                accent: root.accent
                fontFamily: root.ff
                onChanged: function(v) { root.persist({ audioFormat: v }) }
              }
            }

            Dropdown {
              width: parent.width
              label: "Ограничение скорости"
              options: Model.rateOptions()
              value: String(root.opt("rate", ""))
              foreground: root.fg
              accent: root.accent
              fontFamily: root.ff
              onChanged: function(v) { root.persist({ rate: v }) }
            }

            Toggle {
              width: parent.width
              label: "Ускоренная загрузка"
              description: "Качать 4 фрагмента параллельно"
              checked: root.opt("fragments", true) === true
              foreground: root.fg
              accent: root.accent
              fontFamily: root.ff
              titleSize: Style.font.body
              onClicked: root.persist({ fragments: !checked })
            }
            Toggle {
              width: parent.width
              label: "Плейлист целиком"
              description: "Если ссылка ведёт на плейлист, скачать все видео (кроме GIF)"
              checked: root.opt("playlist", false) === true
              foreground: root.fg
              accent: root.accent
              fontFamily: root.ff
              titleSize: Style.font.body
              onClicked: root.persist({ playlist: !checked })
            }

            PanelSeparator { width: parent.width; foreground: root.fg }

            // ---- processing ----
            PanelSectionHeader { width: parent.width; text: "ОБРАБОТКА"; foreground: root.fg; fontFamily: root.ff; font.letterSpacing: 1.2 }

            Toggle {
              width: parent.width
              label: "Обложка в файл"
              description: "Встроить превью ролика как обложку"
              checked: root.opt("embedThumb", false) === true
              foreground: root.fg
              accent: root.accent
              fontFamily: root.ff
              titleSize: Style.font.body
              onClicked: root.persist({ embedThumb: !checked })
            }
            Toggle {
              width: parent.width
              label: "Встроить субтитры"
              description: "Только для видео: mp4, mkv, webm"
              checked: root.opt("embedSubs", false) === true
              foreground: root.fg
              accent: root.accent
              fontFamily: root.ff
              titleSize: Style.font.body
              onClicked: root.persist({ embedSubs: !checked })
            }

            TextField {
              width: parent.width
              height: Style.spacing.controlHeight
              visible: root.opt("embedSubs", false) === true
              foreground: root.fg
              accent: root.accent
              placeholderText: "Языки субтитров: ru,en"
              verticalPadding: 6
              text: String(root.opt("subLangs", "ru,en"))
              onEditingFinished: { var t = text.replace(/\s+/g, ""); if (t) root.persist({ subLangs: t }) }
            }

            Toggle {
              width: parent.width
              label: "Вырезать рекламные вставки"
              description: "SponsorBlock: спонсоры, самореклама, просьбы подписаться. Только YouTube"
              checked: root.opt("sponsor", false) === true
              foreground: root.fg
              accent: root.accent
              fontFamily: root.ff
              titleSize: Style.font.body
              onClicked: root.persist({ sponsor: !checked })
            }

            PanelSeparator { width: parent.width; foreground: root.fg }

            // ---- access ----
            PanelSectionHeader { width: parent.width; text: "ДОСТУП"; foreground: root.fg; fontFamily: root.ff; font.letterSpacing: 1.2 }

            Dropdown {
              width: parent.width
              label: "Cookies браузера"
              options: Model.cookiesOptions()
              value: String(root.opt("cookies", ""))
              foreground: root.fg
              accent: root.accent
              fontFamily: root.ff
              onChanged: function(v) { root.persist({ cookies: v }) }
            }
            Text {
              width: parent.width
              color: Qt.darker(root.fg, 1.5)
              font.family: root.ff
              font.pixelSize: Style.font.caption
              wrapMode: Text.Wrap
              text: "Для видео 18+, приватных и для подписчиков: yt-dlp войдёт под вашей сессией из браузера."
            }

            PanelSeparator { width: parent.width; foreground: root.fg }

            // ---- after download ----
            PanelSectionHeader { width: parent.width; text: "ПОСЛЕ ЗАГРУЗКИ"; foreground: root.fg; fontFamily: root.ff; font.letterSpacing: 1.2 }

            Toggle {
              width: parent.width
              label: "Уведомление"
              description: "Показать уведомление, когда файл готов"
              checked: root.opt("notify", true) === true
              foreground: root.fg
              accent: root.accent
              fontFamily: root.ff
              titleSize: Style.font.body
              onClicked: root.persist({ notify: !checked })
            }
            Toggle {
              width: parent.width
              label: "Открыть папку"
              description: "Открыть папку загрузок после скачивания"
              checked: root.opt("openAfter", false) === true
              foreground: root.fg
              accent: root.accent
              fontFamily: root.ff
              titleSize: Style.font.body
              onClicked: root.persist({ openAfter: !checked })
            }

            Item { width: 1; height: Style.spacing.sm }
          }
        }
      }
    }
  }
}
