import QtQuick
import qs.Commons
import "I18n.js" as I18n

// Settings: language, record pressing, the bar spectrum, the spectrum under
// the lyrics and track-change notices — soft cards of label/control rows.
// Everything is stored in the bar entry's settings.
Column {
  id: page
  property var host: null
  spacing: HubStyle.gap

  readonly property color fg: host ? host.fg : "white"
  readonly property color accent: host ? host.accent : "white"
  readonly property color bgc: host ? host.bgc : "black"
  readonly property string ff: host ? host.ff : ""
  readonly property real selW: Style.space(176)

  function t(k) { return host ? host.t(k) : k }
  function opt(k, d) { return host ? String(host.opt(k, d)) : d }
  readonly property var styles: ["bars", "dots", "beads", "glow", "spikes", "steps", "wave"]

  component Section: Column {
    property alias title: cap.text
    property alias icon: cap.icon
    default property alias rows: body.data
    width: page.width
    spacing: Style.space(6)
    HubCaption { id: cap; fg: page.fg; fontFamily: page.ff }
    HubCard {
      width: parent.width
      height: body.implicitHeight + HubStyle.pad * 2
      fg: page.fg; accent: page.accent
      Column {
        id: body
        x: HubStyle.pad; y: HubStyle.pad
        width: parent.width - HubStyle.pad * 2
        spacing: Style.space(10)
      }
    }
  }
  component Select: HubSelect {
    width: page.selW
    showLabel: false
    foreground: page.fg; accent: page.accent; background: page.bgc; fontFamily: page.ff
  }

  Section {
    title: page.t("set.interface"); icon: "󰗊"
    HubRow {
      title: page.t("set.language"); fg: page.fg; fontFamily: page.ff
      Select {
        options: I18n.LANGS
        value: host ? host.lang : "en"
        onChanged: function(v) { host.persist({ lang: v }) }
      }
    }
  }

  Section {
    title: page.t("set.vinyl"); icon: "󰀥"
    HubRow {
      title: page.t("set.pressing"); fg: page.fg; fontFamily: page.ff
      Row {
        spacing: Style.space(10)
        Vinyl {
          anchors.verticalCenter: parent.verticalCenter
          size: Style.space(34)
          showArm: false
          playing: true
          pressing: page.opt("pressing", "theme")
          artUrl: host && host.media && host.media.activePlayer ? (host.media.activePlayer.trackArtUrl || "") : ""
          accent: page.accent; fg: page.fg; bg: page.bgc
        }
        Select {
          anchors.verticalCenter: parent.verticalCenter
          options: ["theme", "classic", "picture", "clear", "gold"].map(function(k) { return { value: k, label: page.t("press." + k) } })
          value: page.opt("pressing", "theme")
          onChanged: function(v) { host.persist({ pressing: v }) }
        }
      }
    }
  }

  Section {
    title: page.t("set.bar"); icon: "󰐿"
    HubRow {
      title: page.t("set.spectrumStyle"); fg: page.fg; fontFamily: page.ff
      Select {
        options: page.styles.map(function(k) { return { value: k, label: page.t("spec." + k) } })
        value: page.opt("barStyle", "bars")
        onChanged: function(v) { host.persist({ barStyle: v }) }
      }
    }
    HubRow {
      title: page.t("set.palette"); fg: page.fg; fontFamily: page.ff
      Select {
        options: ["accent", "foreground", "muted", "gradient", "spectrum", "cover"].map(function(k) { return { value: k, label: page.t("pal." + k) } })
        value: page.opt("barPalette", "accent")
        onChanged: function(v) { host.persist({ barPalette: v }) }
      }
    }
    HubRow {
      title: page.t("set.mode"); fg: page.fg; fontFamily: page.ff
      Select {
        options: ["bottom", "mirror", "top"].map(function(k) { return { value: k, label: page.t("mode." + k) } })
        value: page.opt("barMode", "bottom")
        onChanged: function(v) { host.persist({ barMode: v }) }
      }
    }
    Text {
      width: parent.width
      wrapMode: Text.Wrap
      text: page.t("set.barHint")
      color: Qt.darker(page.fg, 1.7)
      font.family: page.ff; font.pixelSize: Style.font.caption - 1
    }
  }

  Section {
    title: page.t("set.spectrum"); icon: "󰎈"
    HubRow {
      title: page.t("set.panelSpectrum"); fg: page.fg; fontFamily: page.ff
      Select {
        options: ["bars", "mirror", "dots", "beads", "glow", "spikes", "steps", "wave"].map(function(k) { return { value: k, label: page.t("spec." + k) } })
        value: page.opt("spectrumStyle", "bars")
        onChanged: function(v) { host.persist({ spectrumStyle: v }) }
      }
    }
    HubRow {
      title: page.t("set.notify"); hint: page.t("set.notifyDesc"); fg: page.fg; fontFamily: page.ff
      HubSwitch {
        checked: host ? host.opt("notify", false) === true : false
        fg: page.fg; accent: page.accent; ink: page.bgc
        onToggled: host.persist({ notify: !checked })
      }
    }
  }
}
