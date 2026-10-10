.pragma library

// All yt-dlp / ffmpeg decisions for the Video Grabber plugin. QML stays about
// presentation; the command building and output parsing live here.

// ---- dropdown option sets --------------------------------------------------

// Picture quality. A separator row, then the GIF variants below it.
function videoOptions() {
  return [
    { value: "best",   label: "Лучшее" },
    { value: "2160",   label: "2160p (4K)" },
    { value: "1440",   label: "1440p" },
    { value: "1080",   label: "1080p" },
    { value: "720",    label: "720p" },
    { value: "480",    label: "480p" },
    { value: "360",    label: "360p" },
    { value: "none",   label: "Без видео — только звук" },
    { value: "__sep__", label: "──────  GIF  ──────" },
    { value: "gif720", label: "GIF · 720p · 20 fps" },
    { value: "gif480", label: "GIF · 480p · 15 fps" },
    { value: "gif360", label: "GIF · 360p · 12 fps" }
  ]
}

function audioOptions() {
  return [
    { value: "best", label: "Лучшее" },
    { value: "192",  label: "~192 kbps" },
    { value: "128",  label: "~128 kbps" },
    { value: "none", label: "Без звука" }
  ]
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

// ---- command building ------------------------------------------------------

// Returns { argv: [...], gif: bool }. argv is passed to Process as
// ["bash","-lc", <string>] so one pipeline can chain yt-dlp -> ffmpeg.
function buildCommand(o) {
  // o: { url, video, audio, dir }
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
      'src=$(yt-dlp --newline --no-playlist --no-warnings -f ' + shq(sel) +
        ' -o ' + shq(tmpl) + ' --print after_move:filepath --no-simulate ' + url + ' | tail -n1); ' +
      '[ -f "$src" ] || { echo "ERROR: download produced no file" >&2; exit 3; }; ' +
      'out="${src%.*}.gif"; ' +
      'echo "PHASE:gif"; ' +
      'ffmpeg -y -hide_banner -loglevel error -stats -i "$src" -vf ' + shq(vf) + ' "$out"; ' +
      'rm -f "$src"; ' +
      'echo "DONE:$out"'
    return { argv: ["bash", "-lc", script], gif: true }
  }

  var args = ["yt-dlp", "--newline", "--no-playlist", "--no-warnings",
              "--embed-metadata",
              "-f", formatSelector(o.video, o.audio)]
  if (o.video === "none") args.push("-x", "--audio-format", "m4a", "--audio-quality", "0")
  args.push("-o", tmpl, "--print", "after_move:filepath", "--no-simulate", String(o.url || ""))

  // join into a single quoted string, then echo DONE:<path> from the printed line
  var joined = args.map(shq).join(" ")
  var script2 = 'mkdir -p ' + shq(dir) + '; ' +
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

function friendlyError(e) {
  var s = String(e || "")
  if (/HTTP Error 403|403 Forbidden/i.test(s)) return "Сайт отклонил загрузку (403). Обнови yt-dlp или попробуй другое видео."
  if (/Unsupported URL|is not a valid URL/i.test(s)) return "Ссылка не поддерживается."
  if (/Private video|members-only|Sign in/i.test(s)) return "Видео приватное / требует входа."
  if (/Video unavailable/i.test(s)) return "Видео недоступно."
  if (/ffmpeg/i.test(s)) return "Ошибка ffmpeg при конвертации в GIF."
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
