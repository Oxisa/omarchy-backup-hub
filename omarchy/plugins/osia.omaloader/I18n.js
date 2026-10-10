.pragma library

// UI strings for Omaloader. English is the default; the settings tab switches
// the language. t(lang, key, args) falls back to English, then to the key
// itself; "{0}", "{1}" in a string are replaced from args.

var LANGS = [
  { value: "en", label: "English" },
  { value: "ru", label: "Русский" }
]

var STRINGS = {
  en: {
    "tab.download": "Download",
    "tab.settings": "Settings",

    // download tab
    "url.placeholder": "Paste a video link…",
    "url.paste": "Paste from clipboard",
    "preview.loading": "Loading preview…",
    "preview.empty": "Preview appears here",
    "preview.proxy": "󰖟 proxy",
    "quality.video": "Picture",
    "quality.audio": "Sound",
    "btn.cancel": "Cancel",
    "btn.download": "Download",
    "btn.downloadGif": "Download GIF",
    "btn.downloadAudio": "Download audio",

    // status line
    "status.needUrl": "Paste a video link.",
    "status.needTrack": "Pick video or sound.",
    "status.missing": "Missing: {0} —  omarchy pkg add yt-dlp ffmpeg",
    "status.downloadingSource": "Downloading source…",
    "status.downloading": "Downloading…",
    "status.downloadingPct": "Downloading…  {0}%",
    "status.viaProxy": "  (via proxy)",
    "status.gif": "Converting to GIF…",
    "status.cancelled": "Cancelled.",
    "status.noYtdlp": "yt-dlp is not installed.",
    "status.errorCode": "Error (code {0}).",
    "status.done": "Done — {0}",
    "notify.savedTo": "Saved to {0}",

    // errors from yt-dlp
    "err.403": "The site refused the download (403). Update yt-dlp or try another video.",
    "err.unsupported": "This link is not supported.",
    "err.private": "The video is private or needs a login. Try browser cookies in settings.",
    "err.network": "No connection. Check the proxy in settings.",
    "err.unavailable": "The video is unavailable.",
    "err.ffmpeg": "ffmpeg failed while converting to GIF.",

    // option labels
    "opt.best": "Best",
    "opt.noVideo": "No video — sound only",
    "opt.noAudio": "No sound",
    "opt.containerAuto": "As on the site",
    "opt.containerMp4": "MP4 (compatible)",
    "opt.cookiesOff": "Don't use",
    "opt.rateOff": "No limit",
    "opt.rate": "{0} MB/s",

    // settings: interface
    "sec.interface": "INTERFACE",
    "set.language": "Language",

    // settings: proxy
    "sec.proxy": "PROXY",
    "proxy.active": "Active proxy",
    "proxy.none": "No proxy",
    "proxy.isActive": "Active",
    "proxy.makeActive": "Make active",
    "proxy.test": "Test connection",
    "proxy.remove": "Remove",
    "proxy.name": "Name",
    "proxy.add": "Add proxy",
    "proxy.hint": "Applies to Omaloader only: preview and download. Supports http, https, socks4 and socks5.",
    "proxy.badUrl": "Use socks5://host:port or http://user:pass@host:port",
    "proxy.duplicate": "This proxy is already in the list.",
    "proxy.testing": "Testing…",
    "proxy.ok": "OK · {0} ms",
    "proxy.noConnection": "No connection",
    "proxy.httpCode": "Response {0}",

    // settings: download
    "sec.download": "DOWNLOAD",
    "set.folder": "Folder: ~/Videos/Omaloader",
    "set.autoPaste": "Auto-paste link",
    "set.autoPasteDesc": "Fill in the link from the clipboard on open. Right-click on the icon always pastes",
    "set.container": "Video container",
    "set.audioFormat": "Audio format",
    "set.rate": "Speed limit",
    "set.fragments": "Faster download",
    "set.fragmentsDesc": "Fetch 4 fragments in parallel",
    "set.playlist": "Whole playlist",
    "set.playlistDesc": "If the link points to a playlist, download every video (except GIF)",

    // settings: processing
    "sec.processing": "PROCESSING",
    "set.embedThumb": "Cover in file",
    "set.embedThumbDesc": "Embed the video thumbnail as cover art",
    "set.embedSubs": "Embed subtitles",
    "set.embedSubsDesc": "Video only: mp4, mkv, webm",
    "set.subLangs": "Subtitle languages: ru,en",
    "set.sponsor": "Cut sponsor segments",
    "set.sponsorDesc": "SponsorBlock: sponsors, self-promo, subscribe reminders. YouTube only",

    // settings: access
    "sec.access": "ACCESS",
    "set.cookies": "Browser cookies",
    "set.cookiesHint": "For 18+, private and members-only videos: yt-dlp signs in with your browser session.",

    // settings: after download
    "sec.after": "AFTER DOWNLOAD",
    "set.notify": "Notification",
    "set.notifyDesc": "Notify when the file is ready",
    "set.openAfter": "Open folder",
    "set.openAfterDesc": "Open the download folder when finished"
  },

  ru: {
    "tab.download": "Скачать",
    "tab.settings": "Настройки",

    "url.placeholder": "Вставь ссылку на видео…",
    "url.paste": "Вставить из буфера",
    "preview.loading": "Загрузка превью…",
    "preview.empty": "Превью появится здесь",
    "preview.proxy": "󰖟 прокси",
    "quality.video": "Картинка",
    "quality.audio": "Звук",
    "btn.cancel": "Отмена",
    "btn.download": "Скачать",
    "btn.downloadGif": "Скачать GIF",
    "btn.downloadAudio": "Скачать звук",

    "status.needUrl": "Вставь ссылку на видео.",
    "status.needTrack": "Выбери видео или звук.",
    "status.missing": "Нужно: {0} —  omarchy pkg add yt-dlp ffmpeg",
    "status.downloadingSource": "Загрузка исходника…",
    "status.downloading": "Загрузка…",
    "status.downloadingPct": "Загрузка…  {0}%",
    "status.viaProxy": "  (через прокси)",
    "status.gif": "Конвертация в GIF…",
    "status.cancelled": "Отменено.",
    "status.noYtdlp": "yt-dlp не установлен.",
    "status.errorCode": "Ошибка (код {0}).",
    "status.done": "Готово — {0}",
    "notify.savedTo": "Сохранено в {0}",

    "err.403": "Сайт отклонил загрузку (403). Обнови yt-dlp или попробуй другое видео.",
    "err.unsupported": "Ссылка не поддерживается.",
    "err.private": "Видео приватное / требует входа. Попробуй cookies браузера в настройках.",
    "err.network": "Нет связи. Проверь прокси в настройках.",
    "err.unavailable": "Видео недоступно.",
    "err.ffmpeg": "Ошибка ffmpeg при конвертации в GIF.",

    "opt.best": "Лучшее",
    "opt.noVideo": "Без видео — только звук",
    "opt.noAudio": "Без звука",
    "opt.containerAuto": "Как на сайте",
    "opt.containerMp4": "MP4 (совместимый)",
    "opt.cookiesOff": "Не использовать",
    "opt.rateOff": "Без ограничения",
    "opt.rate": "{0} МБ/с",

    "sec.interface": "ИНТЕРФЕЙС",
    "set.language": "Язык",

    "sec.proxy": "ПРОКСИ",
    "proxy.active": "Активный прокси",
    "proxy.none": "Без прокси",
    "proxy.isActive": "Активен",
    "proxy.makeActive": "Сделать активным",
    "proxy.test": "Проверить связь",
    "proxy.remove": "Удалить",
    "proxy.name": "Имя",
    "proxy.add": "Добавить прокси",
    "proxy.hint": "Действует только для Omaloader: превью и загрузка. Поддерживаются http, https, socks4 и socks5.",
    "proxy.badUrl": "Адрес вида socks5://host:port или http://user:pass@host:port",
    "proxy.duplicate": "Такой прокси уже есть.",
    "proxy.testing": "Проверка…",
    "proxy.ok": "OK · {0} мс",
    "proxy.noConnection": "Нет связи",
    "proxy.httpCode": "Ответ {0}",

    "sec.download": "ЗАГРУЗКА",
    "set.folder": "Папка: ~/Videos/Omaloader",
    "set.autoPaste": "Автовставка ссылки",
    "set.autoPasteDesc": "При открытии подставлять ссылку из буфера обмена. ПКМ по значку вставляет всегда",
    "set.container": "Контейнер видео",
    "set.audioFormat": "Формат звука",
    "set.rate": "Ограничение скорости",
    "set.fragments": "Ускоренная загрузка",
    "set.fragmentsDesc": "Качать 4 фрагмента параллельно",
    "set.playlist": "Плейлист целиком",
    "set.playlistDesc": "Если ссылка ведёт на плейлист, скачать все видео (кроме GIF)",

    "sec.processing": "ОБРАБОТКА",
    "set.embedThumb": "Обложка в файл",
    "set.embedThumbDesc": "Встроить превью ролика как обложку",
    "set.embedSubs": "Встроить субтитры",
    "set.embedSubsDesc": "Только для видео: mp4, mkv, webm",
    "set.subLangs": "Языки субтитров: ru,en",
    "set.sponsor": "Вырезать рекламные вставки",
    "set.sponsorDesc": "SponsorBlock: спонсоры, самореклама, просьбы подписаться. Только YouTube",

    "sec.access": "ДОСТУП",
    "set.cookies": "Cookies браузера",
    "set.cookiesHint": "Для видео 18+, приватных и для подписчиков: yt-dlp войдёт под вашей сессией из браузера.",

    "sec.after": "ПОСЛЕ ЗАГРУЗКИ",
    "set.notify": "Уведомление",
    "set.notifyDesc": "Показать уведомление, когда файл готов",
    "set.openAfter": "Открыть папку",
    "set.openAfterDesc": "Открыть папку загрузок после скачивания"
  }
}

function t(lang, key, args) {
  var table = STRINGS[lang] || STRINGS.en
  var s = table[key]
  if (s === undefined) s = STRINGS.en[key]
  if (s === undefined) return key
  if (args !== undefined && args !== null) {
    if (!Array.isArray(args)) args = [args]
    for (var i = 0; i < args.length; i++) s = s.split("{" + i + "}").join(String(args[i]))
  }
  return s
}
