.pragma library
.import "I18n.js" as I18n

// All yt-dlp / ffmpeg decisions for the Omaloader plugin. QML stays about
// presentation; the command building and output parsing live here.

// ---- dropdown option sets --------------------------------------------------

// Picture quality. A separator row, then the GIF variants below it.
function videoOptions(lang) {
  return [
    { value: "best",   label: I18n.t(lang, "opt.best") },
    { value: "2160",   label: "2160p (4K)" },
    { value: "1440",   label: "1440p" },
    { value: "1080",   label: "1080p" },
    { value: "720",    label: "720p" },
    { value: "480",    label: "480p" },
    { value: "360",    label: "360p" },
    { value: "none",   label: I18n.t(lang, "opt.noVideo") },
    { value: "__sep__", label: "──────  GIF  ──────" },
    { value: "gif720", label: "GIF · 720p · 20 fps" },
    { value: "gif480", label: "GIF · 480p · 15 fps" },
    { value: "gif360", label: "GIF · 360p · 12 fps" }
  ]
}

function audioOptions(lang) {
  return [
    { value: "best", label: I18n.t(lang, "opt.best") },
    { value: "192",  label: "~192 kbps" },
    { value: "128",  label: "~128 kbps" },
    { value: "none", label: I18n.t(lang, "opt.noAudio") }
  ]
}

// Settings tab option sets.
function containerOptions(lang) {
  return [
    { value: "auto", label: I18n.t(lang, "opt.containerAuto") },
    { value: "mp4",  label: I18n.t(lang, "opt.containerMp4") },
    { value: "mkv",  label: "MKV" },
    { value: "webm", label: "WebM" }
  ]
}

function audioFormatOptions() {
  return [
    { value: "m4a",  label: "M4A (AAC)" },
    { value: "mp3",  label: "MP3" },
    { value: "opus", label: "Opus" },
    { value: "flac", label: "FLAC" }
  ]
}

function cookiesOptions(lang) {
  return [
    { value: "",         label: I18n.t(lang, "opt.cookiesOff") },
    { value: "chromium", label: "Chromium" },
    { value: "chrome",   label: "Chrome" },
    { value: "brave",    label: "Brave" },
    { value: "firefox",  label: "Firefox" }
  ]
}

function rateOptions(lang) {
  return [{ value: "", label: I18n.t(lang, "opt.rateOff") }].concat(
    ["1", "2", "5", "10"].map(function(n) { return { value: n + "M", label: I18n.t(lang, "opt.rate", n) } }))
}

function isGif(video)      { return String(video || "").indexOf("gif") === 0 }
function isSeparator(v)    { return v === "__sep__" }
function gifSpec(video) {
  switch (video) {
    case "gif720": return { h: 720, fps: 20, w: 720 }
    case "gif480": return { h: 480, fps: 15, w: 480 }
    default:       return { h: 360, fps: 12, w: 360 }
  }
}

// ---- format selector -----------------------------------------------------

function heightCap(video) {
  var n = parseInt(video, 10)
  return isFinite(n) ? n : 0
}

// yt-dlp -f string for a plain (non-GIF) download.
function formatSelector(video, audio) {
  if (video === "none") return "ba/b"                      // audio-only handled with -x too

  var h = heightCap(video)
  var vsel = h > 0 ? ("bv*[height<=" + h + "]") : "bv*"
  var vfallback = h > 0 ? ("b[height<=" + h + "]") : "b"

  if (audio === "none") return vsel + "/" + vfallback      // video, no audio track

  var acap = (audio === "192" || audio === "128") ? ("[abr<=" + audio + "]") : ""
  // best video + (capped) best audio, falling back to a progressive stream
  return vsel + "+ba" + acap + "/" + vsel + "+ba/" + vfallback
}

// ---- shell quoting -----------------------------------------------------

function shq(s) {
  return "'" + String(s === undefined || s === null ? "" : s).replace(/'/g, "'\\''") + "'"
}

// ---- proxy -----------------------------------------------------------------

// Proxies apply to this plugin's yt-dlp / curl calls only, never system-wide.
function validProxy(u) {
  return /^(https?|socks4a?|socks5h?):\/\/[^\s\/]+(:\d+)?\/?$/i.test(String(u || "").trim())
}

// Hide a password in user:pass@host for display.
function maskProxy(u) {
  return String(u || "").replace(/^([a-z0-9]+:\/\/[^:@\/]+):[^@\/]*@/i, "$1:•••@")
}

// curl a tiny YouTube endpoint through the proxy; prints "<code> <seconds>".
function proxyTestCommand(u) {
  return ["curl", "-sS", "-o", "/dev/null", "-w", "%{http_code} %{time_total}",
          "--max-time", "10", "--proxy", String(u), "https://www.youtube.com/generate_204"]
}

// Returns { ok, key, arg } so the panel can render it in the current language.
function parseProxyTest(out, exitCode) {
  var m = /^(\d{3})\s+([\d.]+)/.exec(String(out || "").trim())
  if (exitCode !== 0 || !m || m[1] === "000") return { ok: false, key: "proxy.noConnection" }
  var ms = Math.round(parseFloat(m[2]) * 1000)
  var code = parseInt(m[1], 10)
  if (code >= 400) return { ok: false, key: "proxy.httpCode", arg: code }
  return { ok: true, key: "proxy.ok", arg: ms }
}

// Preview thumbnails go through the same proxy as yt-dlp, so they are
// fetched with curl into a local file instead of letting Qt load the URL.
function thumbCommand(url, proxy, dest) {
  var a = ["curl", "-sSL", "--max-time", "15", "-o", String(dest)]
  if (proxy) a.push("--proxy", String(proxy))
  a.push(String(url))
  return a
}

// ---- shared yt-dlp options ---------------------------------------------------

// Network-side flags every yt-dlp call gets (preview and download alike).
function networkArgs(opts) {
  opts = opts || {}
  var a = []
  if (opts.proxy) a.push("--proxy", String(opts.proxy))
  if (opts.cookies) a.push("--cookies-from-browser", String(opts.cookies))
  return a
}

function infoCommand(url, opts) {
  return ["yt-dlp", "-J", "--no-playlist", "--no-warnings", "--skip-download"]
    .concat(networkArgs(opts), [String(url)])
}

// Download-only flags shared by the plain and GIF paths.
function transferArgs(opts) {
  opts = opts || {}
  var a = []
  if (opts.rate) a.push("-r", String(opts.rate))
  if (opts.fragments) a.push("-N", "4")
  return a
}

// ---- command building ------------------------------------------------------

// Returns { argv: [...], gif: bool }. argv is passed to Process as
// ["bash","-lc", <string>] so one pipeline can chain yt-dlp -> ffmpeg.
function buildCommand(o) {
  // o: { url, video, audio, dir, opts }; opts as collected from the settings tab
  var opts = o.opts || {}
  var dir  = String(o.dir || "").trim()
  var tmpl = dir + "/%(title).180B [%(id)s].%(ext)s"
  var url  = shq(o.url)

  if (isGif(o.video)) {
    var g = gifSpec(o.video)
    var vf = "fps=" + g.fps + ",scale=" + g.w + ":-1:flags=lanczos,split[a][b];" +
             "[a]palettegen=stats_mode=diff[p];[b][p]paletteuse=dither=bayer:diff_mode=rectangle"
    var sel = "bv*[height<=" + g.h + "]/b[height<=" + g.h + "]"
    var script =
      'set -e; mkdir -p ' + shq(dir) + '; ' +
      'src=$(yt-dlp --newline --no-playlist --no-warnings ' +
        networkArgs(opts).concat(transferArgs(opts)).map(shq).join(" ") + ' -f ' + shq(sel) +
        ' -o ' + shq(tmpl) + ' --print after_move:filepath --no-simulate ' + url + ' | tail -n1); ' +
      '[ -f "$src" ] || { echo "ERROR: download produced no file" >&2; exit 3; }; ' +
      'out="${src%.*}.gif"; ' +
      'echo "PHASE:gif"; ' +
      'ffmpeg -y -hide_banner -loglevel error -stats -i "$src" -vf ' + shq(vf) + ' "$out"; ' +
      'rm -f "$src"; ' +
      'echo "DONE:$out"'
    return { argv: ["bash", "-lc", script], gif: true }
  }

  var args = ["yt-dlp", "--newline", opts.playlist ? "--yes-playlist" : "--no-playlist",
              "--no-warnings", "--embed-metadata"]
    .concat(networkArgs(opts), transferArgs(opts), ["-f", formatSelector(o.video, o.audio)])
  if (o.video === "none") {
    args.push("-x", "--audio-format", opts.audioFormat || "m4a", "--audio-quality", "0")
  } else {
    if (opts.container && opts.container !== "auto") args.push("--remux-video", String(opts.container))
    if (opts.embedSubs) args.push("--embed-subs", "--sub-langs", String(opts.subLangs || "ru,en"))
  }
  if (opts.embedThumb) args.push("--embed-thumbnail")
  if (opts.sponsor) args.push("--sponsorblock-remove", "sponsor,selfpromo,interaction")
  args.push("-o", tmpl, "--print", "after_move:filepath", "--no-simulate", String(o.url || ""))

  // join into a single quoted string, then echo DONE:<path> from the printed line
  var joined = args.map(shq).join(" ")
  // pipefail: rc must be yt-dlp's, not tail's, or a failed run reads as done
  var script2 = 'set -o pipefail; mkdir -p ' + shq(dir) + '; ' +
                'p=$(' + joined + ' | tail -n1); rc=$?; ' +
                '[ $rc -eq 0 ] && [ -n "$p" ] && echo "DONE:$p"; exit $rc'
  return { argv: ["bash", "-lc", script2], gif: false }
}

// ---- output parsing ------------------------------------------------------

function parseProgress(line) {
  // yt-dlp:  [download]  42.7% of 10.55MiB at 3.11MiB/s ETA 00:02
  var m = /^\[download\]\s+([\d.]+)%/.exec(line)
  if (m) return { kind: "dl", percent: parseFloat(m[1]) }
  // ffmpeg -stats:  frame=  128 fps= 30 q=-0.0 size=  ... time=00:00:04.26 ...
  if (/^frame=\s*\d+/.test(line) || /time=\d\d:\d\d:\d\d/.test(line)) return { kind: "gif" }
  if (line.indexOf("PHASE:gif") === 0) return { kind: "gifstart" }
  var d = /^DONE:(.+)$/.exec(line)
  if (d) return { kind: "done", path: d[1].trim() }
  if (/^ERROR:/.test(line)) return { kind: "error", text: line.replace(/^ERROR:\s*/, "") }
  return null
}

function friendlyError(e, lang) {
  var s = String(e || "")
  if (/HTTP Error 403|403 Forbidden/i.test(s)) return I18n.t(lang, "err.403")
  if (/Unsupported URL|is not a valid URL/i.test(s)) return I18n.t(lang, "err.unsupported")
  if (/Private video|members-only|Sign in/i.test(s)) return I18n.t(lang, "err.private")
  if (/proxy|Unable to connect|Connection refused|timed out/i.test(s)) return I18n.t(lang, "err.network")
  if (/Video unavailable/i.test(s)) return I18n.t(lang, "err.unavailable")
  if (/ffmpeg/i.test(s)) return I18n.t(lang, "err.ffmpeg")
  return s.length > 140 ? s.slice(0, 140) + "…" : s
}

// ---- preview (yt-dlp -J) ------------------------------------------------

function parseInfo(jsonText) {
  try {
    var j = JSON.parse(jsonText)
    var thumb = j.thumbnail || ""
    if (!thumb && Array.isArray(j.thumbnails) && j.thumbnails.length)
      thumb = j.thumbnails[j.thumbnails.length - 1].url || ""
    return {
      ok: true,
      title: j.title || j.fulltitle || "",
      uploader: j.uploader || j.channel || j.uploader_id || "",
      duration: Number(j.duration || 0),
      thumb: thumb,
      ext: j.ext || "",
      heights: collectHeights(j)
    }
  } catch (e) {
    return { ok: false }
  }
}

function collectHeights(j) {
  var hs = {}
  var fmts = Array.isArray(j.formats) ? j.formats : []
  for (var i = 0; i < fmts.length; i++) {
    var h = Number(fmts[i].height || 0)
    if (h > 0) hs[h] = true
  }
  return Object.keys(hs).map(function(x){ return parseInt(x,10) }).sort(function(a,b){ return b-a })
}

function fmtDuration(sec) {
  sec = Math.max(0, Math.floor(Number(sec) || 0))
  var h = Math.floor(sec / 3600), m = Math.floor((sec % 3600) / 60), s = sec % 60
  function p(n){ return n < 10 ? "0" + n : "" + n }
  return h > 0 ? (h + ":" + p(m) + ":" + p(s)) : (m + ":" + p(s))
}

function looksLikeUrl(t) {
  t = String(t || "").trim()
  return /^(https?:\/\/|www\.)/i.test(t) ||
         /^(youtu\.be\/|youtube\.com\/|vimeo\.com\/|twitch\.tv\/|x\.com\/|twitter\.com\/|reddit\.com\/|v\.redd\.it\/|tiktok\.com\/|instagram\.com\/)/i.test(t)
}

function baseName(p) {
  var s = String(p || "")
  var i = s.lastIndexOf("/")
  return i >= 0 ? s.slice(i + 1) : s
}
