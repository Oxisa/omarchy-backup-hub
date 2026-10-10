import QtQuick
import qs.Commons
import qs.Ui
import "I18n.js" as I18n

// Settings: language, record pressing, spectrum style, bar spectrum and
// track-change notices. Everything is stored in the bar entry's settings.
Column {
  id: page
  property var host: null
  spacing: Style.spacing.md

  readonly property color fg: host ? host.fg : "white"
  readonly property color accent: host ? host.accent : "white"
  readonly property string ff: host ? host.ff : ""

  function t(k) { return host ? host.t(k) : k }
  readonly property var styles: ["bars", "dots", "beads", "glow", "spikes", "steps", "wave"]

  PanelSectionHeader { width: parent.width; text: page.t("set.interface"); foreground: page.fg; fontFamily: page.ff; font.letterSpacing: 1.2 }
  Dropdown {
    width: parent.width
    label: page.t("set.language")
    options: I18n.LANGS
    value: host ? host.lang : "en"
    foreground: page.fg; accent: page.accent; fontFamily: page.ff
    onChanged: function(v) { host.persist({ lang: v }) }
  }

  PanelSeparator { width: parent.width; foreground: page.fg }

  PanelSectionHeader { width: parent.width; text: page.t("set.vinyl"); foreground: page.fg; fontFamily: page.ff; font.letterSpacing: 1.2 }
  Row {
    width: parent.width
    spacing: Style.spacing.md
    Dropdown {
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width - preview.width - parent.spacing
      label: page.t("set.pressing")
      options: ["theme", "classic", "picture", "clear", "gold"].map(function(k) { return { value: k, label: page.t("press." + k) } })
      value: host ? String(host.opt("pressing", "theme")) : "theme"
      foreground: page.fg; accent: page.accent; fontFamily: page.ff
      onChanged: function(v) { host.persist({ pressing: v }) }
    }
    Vinyl {
      id: preview
      anchors.verticalCenter: parent.verticalCenter
      size: Style.space(64)
      showArm: false
      playing: true
      pressing: host ? String(host.opt("pressing", "theme")) : "theme"
      artUrl: host && host.media && host.media.activePlayer ? (host.media.activePlayer.trackArtUrl || "") : ""
      accent: page.accent; fg: page.fg; bg: host ? host.bgc : "black"
    }
  }

  PanelSeparator { width: parent.width; foreground: page.fg }

  PanelSectionHeader { width: parent.width; text: page.t("set.bar"); foreground: page.fg; fontFamily: page.ff; font.letterSpacing: 1.2 }
  Row {
    width: parent.width
    spacing: Style.spacing.md
    Dropdown {
      width: (parent.width - parent.spacing * 2) / 3
      label: page.t("set.spectrumStyle")
      options: page.styles.map(function(k) { return { value: k, label: page.t("spec." + k) } })
      value: host ? String(host.opt("barStyle", "bars")) : "bars"
      foreground: page.fg; accent: page.accent; fontFamily: page.ff
      onChanged: function(v) { host.persist({ barStyle: v }) }
    }
    Dropdown {
      width: (parent.width - parent.spacing * 2) / 3
      label: page.t("set.palette")
      options: ["accent", "foreground", "muted", "gradient", "spectrum", "cover"].map(function(k) { return { value: k, label: page.t("pal." + k) } })
      value: host ? String(host.opt("barPalette", "accent")) : "accent"
      foreground: page.fg; accent: page.accent; fontFamily: page.ff
      onChanged: function(v) { host.persist({ barPalette: v }) }
    }
    Dropdown {
      width: (parent.width - parent.spacing * 2) / 3
      label: page.t("set.mode")
      options: ["bottom", "mirror", "top"].map(function(k) { return { value: k, label: page.t("mode." + k) } })
      value: host ? String(host.opt("barMode", "bottom")) : "bottom"
      foreground: page.fg; accent: page.accent; fontFamily: page.ff
      onChanged: function(v) { host.persist({ barMode: v }) }
    }
  }
  Text {
    width: parent.width
    wrapMode: Text.Wrap
    text: page.t("set.barHint")
    color: Qt.darker(page.fg, 1.5)
    font.family: page.ff; font.pixelSize: Style.font.caption
  }

  PanelSeparator { width: parent.width; foreground: page.fg }

  PanelSectionHeader { width: parent.width; text: page.t("set.spectrum"); foreground: page.fg; fontFamily: page.ff; font.letterSpacing: 1.2 }
  Dropdown {
    width: parent.width
    label: page.t("set.panelSpectrum")
    options: ["bars", "mirror", "dots", "beads", "glow", "spikes", "steps", "wave"].map(function(k) { return { value: k, label: page.t("spec." + k) } })
    value: host ? String(host.opt("spectrumStyle", "bars")) : "bars"
    foreground: page.fg; accent: page.accent; fontFamily: page.ff
    onChanged: function(v) { host.persist({ spectrumStyle: v }) }
  }
  Toggle {
    width: parent.width
    label: page.t("set.lyrics")
    description: page.t("set.lyricsDesc")
    checked: host ? host.opt("lyrics", true) === true : true
    foreground: page.fg; accent: page.accent; fontFamily: page.ff
    titleSize: Style.font.body
    onClicked: host.persist({ lyrics: !checked })
  }
  Toggle {
    width: parent.width
    label: page.t("set.notify")
    description: page.t("set.notifyDesc")
    checked: host ? host.opt("notify", false) === true : false
    foreground: page.fg; accent: page.accent; fontFamily: page.ff
    titleSize: Style.font.body
    onClicked: host.persist({ notify: !checked })
  }
}
