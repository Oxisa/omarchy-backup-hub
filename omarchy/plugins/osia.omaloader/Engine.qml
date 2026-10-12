import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "Model.js" as Model
import "I18n.js" as I18n

// Omaloader's engine: settings, preview (yt-dlp -J + thumbnail), downloads
// (yt-dlp + ffmpeg), the plugin-only proxy manager. No UI — Content.qml draws
// it, and both the bar panel (Panel.qml) and TheNotch host the same engine.
// Downloads keep running while nothing is open.
Item {
  id: root
  visible: false

  property string url: ""               // the URL being previewed / downloaded


  property color fg: Color.foreground
  property string ff: Style.font.family
  property color accent: Color.accent
  property color urgent: Color.urgent
  readonly property string home: Quickshell.env("HOME")
  readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"

  property int tab: 0                   // 0 download | 1 settings

  // UI language from the settings tab; English by default.
  // a host with one language for everything (TheNotch) sets langOverride
  property string langOverride: ""
  readonly property string lang: langOverride || String(opt("lang", "en") || "en")
  function t(key, args) { return I18n.t(root.lang, key, args) }

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

  // Settings come in through `settings`; changes go out through
  // persistRequested (the bar panel writes its bar entry, TheNotch its file).
  property var settings: ({})
  signal persistRequested(var values)
  function setting(key, fallback) { return opt(key, fallback) }
  function persist(values) {
    var e = {}
    for (var k in settings) if (k !== "id") e[k] = settings[k]
    for (var key in values) e[key] = values[key]
    settings = e
    persistRequested(values)
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

  // ---- actions ----
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
        if (Model.looksLikeUrl(t)) { root.tab = 0; root.url = t; root.onUrlEdited() }
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
    var u = String(root.url || "").trim()
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
    var u = String(root.url || "").trim()
    if (!u) { root.statusText = root.t("status.needUrl"); root.dlState = "idle"; return }
    if (root.video === "none" && root.audio === "none") {
      root.statusText = root.t("status.needTrack"); root.dlState = "idle"; return
    }
    if (!root.hasYtdlp || (Model.isGif(root.video) && !root.hasFfmpeg)) {
      root.dlState = "error"; root.indeterminate = false
      root.statusText = root.t("status.missing", (!root.hasYtdlp ? "yt-dlp " : "") +
        (Model.isGif(root.video) && !root.hasFfmpeg ? "ffmpeg" : ""))
      return
    }

    var c = Model.buildCommand({ url: u, video: root.video, audio: root.audio,
                                 dir: root.dlDir, opts: root.collectOpts() })
    root.running = true; root.dlState = "running"
    root.indeterminate = true; root.progress = 0
    root.phase = "dl"; root.cancelled = false; root.lastFile = ""; root.errText = ""
    root.statusText = root.t(Model.isGif(root.video) ? "status.downloadingSource" : "status.downloading") +
      (root.activeProxy ? root.t("status.viaProxy") : "")
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
      if (root.phase !== "gif") root.statusText = root.t("status.downloadingPct", Math.round(p.percent))
    } else if (p.kind === "gifstart" || p.kind === "gif") {
      root.phase = "gif"; root.indeterminate = true
      root.statusText = root.t("status.gif")
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
        root.indeterminate = true; root.statusText = root.t("status.cancelled")
        return
      }
      if (code !== 0) {
        root.dlState = "error"; root.indeterminate = false
        root.statusText = code === 127 ? root.t("status.noYtdlp")
          : (Model.friendlyError(root.errText, root.lang) || root.t("status.errorCode", code))
        root.errText = ""
        return
      }
      root.dlState = "done"; root.indeterminate = false; root.progress = 100
      root.statusText = root.t("status.done", root.lastFile ? Model.baseName(root.lastFile) : root.dlDir)
      if (root.opt("notify", true) === true) root.notifyDone()
      if (root.opt("openAfter", false) === true) root.openFolder()
    }
  }

  function notifyDone() {
    var msg = root.lastFile ? Model.baseName(root.lastFile) : root.t("notify.savedTo", root.dlDir)
    Quickshell.execDetached(["sh", "-lc",
      "command -v omarchy-notification-send >/dev/null && omarchy-notification-send -g 󰇚 'Omaloader' " +
      Model.shq(msg) + " || notify-send -a 'Omaloader' 'Omaloader' " + Model.shq(msg)])
  }

  // ---- proxy manager ----
  function addProxy(name, url) {
    name = String(name || "").trim()
    url = String(url || "").trim()
    if (!Model.validProxy(url)) {
      root.proxyFormError = root.t("proxy.badUrl")
      return false
    }
    for (var i = 0; i < root.proxies.length; i++) {
      if (root.proxies[i].url === url) { root.proxyFormError = root.t("proxy.duplicate"); return false }
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
    var st = Object.assign({}, root.proxyStatus); st[url] = { ok: true, key: "proxy.testing" }; root.proxyStatus = st
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
}
