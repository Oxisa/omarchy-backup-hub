.pragma library

// Pure helpers for SoundHub: formatting, cava config/frames, PipeWire node
// labels. QML files stay about presentation and state.

// ---- time --------------------------------------------------------------------

function fmtTime(sec) {
  sec = Math.max(0, Math.floor(Number(sec) || 0))
  var h = Math.floor(sec / 3600), m = Math.floor((sec % 3600) / 60), s = sec % 60
  function p(n) { return n < 10 ? "0" + n : "" + n }
  return h > 0 ? (h + ":" + p(m) + ":" + p(s)) : (m + ":" + p(s))
}

function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, Number(v) || 0)) }

// ---- cava ----------------------------------------------------------------------

var asciiRange = 1000

// source: a PipeWire sink node name to listen to (its monitor), or "" for auto.
// The native pipewire input is used for a named sink: through the pulse layer
// WirePlumber re-routed the capture onto the EQ in front of the device, whose
// monitor is near-silent.
function cavaConfig(bars, framerate, source) {
  return [
    "[general]",
    "framerate = " + framerate,
    "bars = " + bars,
    "autosens = 1",
    "",
    "[input]",
    "method = " + (source ? "pipewire" : "pulse"),
    "source = " + (source ? source : "auto"),
    "",
    "[output]",
    "method = raw",
    "raw_target = /dev/stdout",
    "data_format = ascii",
    "ascii_max_range = " + asciiRange,
    "channels = mono",
    "",
    "[smoothing]",
    "noise_reduction = 0.77",
    ""
  ].join("\n")
}

// "12;400;993;...;" -> [0.012, 0.4, 0.993, ...] or null for a broken line.
function parseFrame(line, bars) {
  var text = String(line || "").trim()
  if (!text) return null
  var parts = text.split(";")
  if (parts.length && parts[parts.length - 1] === "") parts.pop()
  if (parts.length < bars) return null
  var out = new Array(bars)
  for (var i = 0; i < bars; i++) {
    var v = parseInt(parts[i], 10)
    out[i] = isFinite(v) ? clamp(v / asciiRange, 0, 1) : 0
  }
  return out
}

function zeros(n) {
  var a = new Array(n)
  for (var i = 0; i < n; i++) a[i] = 0
  return a
}

// ---- PipeWire nodes ----------------------------------------------------------

function nodeProps(node) {
  return node && node.ready && node.properties ? node.properties : {}
}

function isPlaybackStream(node) {
  if (!node || !node.isStream) return false
  if (node.isSink === true) return true
  var mediaClass = String(node.type || "")
  return mediaClass.indexOf("Stream/Output/Audio") !== -1 || mediaClass.indexOf("Output") !== -1
}

function isAudioSource(node) {
  if (!node) return false
  if (node.audio) return true
  var mediaClass = String(node.type || "")
  return mediaClass.indexOf("Audio/Source") !== -1 || mediaClass.indexOf("Source") !== -1
}

// Our own and Omarchy's DSP plumbing: processing, not something to pick or mix.
function isInternalNode(node) {
  var name = String(node && node.name || "")
  return name.indexOf("soundhub_") === 0 || name.indexOf("omarchy_speaker_tuning") === 0
    || name.indexOf("omarchy_equalizer") === 0 || name.indexOf("omarchy.equalizer") !== -1
    || name === "quickshell" || name.indexOf("cava") === 0
}

function friendlyDeviceLabel(text) {
  var label = String(text || "").trim()
  label = label.replace(/^sof-soundwire\s+/i, "")
  label = label.replace(/^built-?in audio\s+/i, "")
  label = label.replace(/\s+Output$/i, "")
  label = label.replace(/\s+Input$/i, "")
  return label
}

function nodeLabel(node) {
  if (!node) return "—"
  var p = nodeProps(node)
  var nick = friendlyDeviceLabel(node.nickname || p["node.nick"] || p["device.profile.description"] || "")
  if (nick) return nick
  return friendlyDeviceLabel(node.description || p["node.description"] || node.name || "—")
}

function streamLabel(node) {
  if (!node) return ""
  var p = nodeProps(node)
  return String(p["application.name"] || node.description || p["media.name"] || node.name || "")
}

function blob(node, extra) {
  var p = nodeProps(node)
  return String([node.name, node.description, node.nickname,
                 p["device.icon-name"] || "", p["device.product.name"] || "", extra || ""]
    .join(" ")).toLowerCase()
}

function sinkGlyph(node) {
  if (!node) return "󰓃"
  var b = blob(node)
  if (/headphone|headset|earbud|earphone|airpod/.test(b)) return "󰋋"
  if (b.indexOf("bluetooth") !== -1) return "󰂯"
  if (b.indexOf("hdmi") !== -1 || b.indexOf("display") !== -1) return "󰍹"
  return "󰓃"
}

function sourceGlyph(node) {
  if (!node) return "󰍬"
  var b = blob(node)
  if (b.indexOf("headset") !== -1) return "󰋋"
  if (b.indexOf("bluetooth") !== -1) return "󰂯"
  if (b.indexOf("webcam") !== -1 || b.indexOf("camera") !== -1) return "󰄀"
  return "󰍬"
}

function volumeGlyph(volume, muted) {
  if (muted || volume <= 0.001) return "󰝟"
  if (volume < 0.34) return "󰕿"
  if (volume < 0.67) return "󰖀"
  return "󰕾"
}

// ---- equalizer -----------------------------------------------------------------

var eqFreqs = [60, 250, 1000, 4000, 8000, 16000]

function eqFreqLabel(f) { return f >= 1000 ? (f / 1000) + "k" : String(f) }

// Gentle auto-preamp: pull down by the largest boost so the curve can't clip.
function autoPreamp(bands) {
  var mx = 0
  for (var i = 0; i < bands.length; i++) mx = Math.max(mx, Number(bands[i]) || 0)
  return -Math.round(mx * 10) / 10
}
