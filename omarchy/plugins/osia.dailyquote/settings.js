// Settings schema shared by Service.qml (the overlay) and BarWidget.qml
// (the control panel), so both read the same file the same way.
// Based on io.github.r4y-br.quran-motivation (MIT).

var DEFAULTS = {
  visible: true,
  scale: 1.0,
  posX: 0.5,
  posY: 0.86,
  backgroundOpacity: 0.4,
  intervalMinutes: 240,
  lang: "en"
}
var SCALE_MIN = 0.6
var SCALE_MAX = 2.0
var OPACITY_MAX = 0.85
var INTERVALS = [15, 30, 60, 120, 240, 480, 1440]

// The 3×3 picker: a place sets the card's centre to an edge/centre of the
// screen (the overlay keeps it inside a margin); a dragged position that
// matches no place lights nothing.
var PLACES = { tl: [0, 0], t: [0.5, 0], tr: [1, 0], l: [0, 0.5], c: [0.5, 0.5], r: [1, 0.5],
               bl: [0, 1], b: [0.5, 1], br: [1, 1] }
function placeOf(cfg) {
  for (var k in PLACES) if (Math.abs(cfg.posX - PLACES[k][0]) < 0.001 && Math.abs(cfg.posY - PLACES[k][1]) < 0.001) return k
  return ""
}

// Font for the original: blackletter for Latin-script languages, CJK serif
// for Japanese / Chinese / Korean, a plain serif for everything else.
var LATIN = ["en", "fr", "de", "es", "it", "la", "pt", "nl", "pl", "cs", "sv", "da", "no", "fi"]
function fontFor(lang, gothic) {
  if (LATIN.indexOf(lang) >= 0) return gothic
  if (lang === "ja") return "Noto Serif CJK JP"
  if (lang === "zh") return "Noto Serif CJK SC"
  if (lang === "ko") return "Noto Serif CJK KR"
  return "Noto Serif"
}
// The quote under the original, in the chosen language (old {en, ru} files too).
function topOf(q) { return q ? String(q.text || q.en || "") : "" }
function langOf(q) { return q ? String(q.lang || "en") : "en" }
function bottomOf(q, lang) {
  if (!q || langOf(q) === lang) return ""
  if (q.tr && q.tr[lang]) return q.tr[lang]
  return lang === "ru" && q.ru ? q.ru : ""
}
// "Reset" puts the overlay's look back: place, size, background
function resetLook() {
  return { posX: DEFAULTS.posX, posY: DEFAULTS.posY, scale: DEFAULTS.scale, backgroundOpacity: DEFAULTS.backgroundOpacity }
}

function clamp(v, lo, hi, d) { var n = Number(v); if (isNaN(n)) n = d; return Math.max(lo, Math.min(hi, n)) }

function parse(raw) {
  var o = {}
  try { var x = JSON.parse(String(raw || "{}")); if (x && typeof x === "object") o = x } catch (e) {}
  return {
    visible: typeof o.visible === "boolean" ? o.visible : DEFAULTS.visible,
    scale: clamp(o.scale, SCALE_MIN, SCALE_MAX, DEFAULTS.scale),
    posX: clamp(o.posX, 0, 1, DEFAULTS.posX),
    posY: clamp(o.posY, 0, 1, DEFAULTS.posY),
    backgroundOpacity: clamp(o.backgroundOpacity, 0, OPACITY_MAX, DEFAULTS.backgroundOpacity),
    intervalMinutes: INTERVALS.indexOf(Number(o.intervalMinutes)) >= 0 ? Number(o.intervalMinutes) : DEFAULTS.intervalMinutes,
    lang: o.lang === "ru" ? "ru" : "en"
  }
}

var STRINGS = {
  en: {
    title: "Daily Quote", show: "Show quote on desktop", size: "Size", background: "Background",
    position: "Position", drag: "Drag to reposition on desktop", change: "Change quote", now: "Show a new quote now",
    language: "Language", languageHint: "Panel and the translation under the quote", place: "Position", reset: "Reset", hint: "Drag the quote to move it — click anywhere else when done",
    every: { 15: "Every 15 minutes", 30: "Every 30 minutes", 60: "Every hour", 120: "Every 2 hours",
             240: "Every 4 hours", 480: "Every 8 hours", 1440: "Once a day" }
  },
  ru: {
    title: "Цитата дня", show: "Показывать цитату на рабочем столе", size: "Размер", background: "Фон",
    position: "Положение", drag: "Перетащить на рабочем столе", change: "Смена цитаты", now: "Новая цитата сейчас",
    language: "Язык", languageHint: "Панель и перевод под цитатой", place: "Положение", reset: "Сбросить", hint: "Перетащите цитату — затем кликните в любом другом месте",
    every: { 15: "Каждые 15 минут", 30: "Каждые 30 минут", 60: "Каждый час", 120: "Каждые 2 часа",
             240: "Каждые 4 часа", 480: "Каждые 8 часов", 1440: "Раз в день" }
  }
}
function t(lang, k) { var s = STRINGS[lang] || STRINGS.en; return s[k] !== undefined ? s[k] : STRINGS.en[k] }
