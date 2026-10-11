import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "settings.js" as Settings
import "../osia.soundhub" as SH

// Bar button + control panel for the desktop quote: show/hide, size,
// background, drag to move, how often it changes, a new quote now, and the
// panel language. Writes the settings file the overlay (Service.qml) watches.
// Adapted from io.github.r4y-br.quran-motivation by Rayen Iben Romdhane (MIT).
Panel {
  id: root
  moduleName: "osia.dailyquote"
  ipcTarget: "osia.dailyquote.panel"

  readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/omarchy/dailyquote"
  readonly property string settingsPath: stateDir + "/settings.json"

  property var cfg: Settings.parse("")
  function t(k) { return Settings.t(cfg.lang, k) }

  FileView {
    id: settingsFile
    path: root.settingsPath
    watchChanges: true
    printErrors: false
    onLoaded: root.cfg = Settings.parse(text())
    onFileChanged: reload()
  }

  function set(key, value) { var v = {}; v[key] = value; setMany(v) }
  function setMany(values) {
    var c = Object.assign({}, cfg)
    for (var k in values) c[k] = values[k]
    cfg = Settings.parse(JSON.stringify(c))
    settingsFile.setText(JSON.stringify(cfg))
  }

  function ipc(cmd) { Quickshell.execDetached(["qs", "-p", Quickshell.shellDir, "ipc", "call", "osia.dailyquote", cmd]) }

  visible: true
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "\u{f0757}"
    tooltipText: root.t("title")
    onPressed: function() { root.toggle() }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(400))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: SH.HubStyle.gap

        readonly property color fg: root.bar ? root.bar.barForeground : Color.foreground
        readonly property color accent: Color.accent
        readonly property color bgc: Color.background
        readonly property string ff: root.bar ? root.bar.fontFamily : Style.font.family

        component Card: SH.HubCard {
          default property alias rows: body.data
          width: column.width
          height: body.implicitHeight + SH.HubStyle.pad * 2
          fg: column.fg; accent: column.accent
          Column {
            id: body
            x: SH.HubStyle.pad; y: SH.HubStyle.pad
            width: parent.width - SH.HubStyle.pad * 2
            spacing: Style.space(10)
          }
        }

        Text {
          leftPadding: Style.space(4)
          text: "\u{f0757}  " + root.t("title")
          color: column.fg
          font.family: column.ff; font.pixelSize: Style.font.title; font.bold: true
        }

        Card {
          SH.HubRow {
            title: root.t("show"); fg: column.fg; fontFamily: column.ff
            SH.HubSwitch {
              checked: root.cfg.visible
              fg: column.fg; accent: column.accent; ink: column.bgc
              onToggled: root.set("visible", !root.cfg.visible)
            }
          }
          SH.HubRow {
            title: root.t("size"); fg: column.fg; fontFamily: column.ff
            SH.HubSlider {
              width: Style.space(170)
              minimum: Settings.SCALE_MIN; maximum: Settings.SCALE_MAX; step: 0.05
              value: root.cfg.scale
              fillColor: column.accent; fontFamily: column.ff
              onReleased: function(v) { root.set("scale", v) }
            }
          }
          SH.HubRow {
            title: root.t("background"); fg: column.fg; fontFamily: column.ff
            SH.HubSlider {
              width: Style.space(170)
              minimum: 0; maximum: Settings.OPACITY_MAX; step: 0.05
              value: root.cfg.backgroundOpacity
              fillColor: column.accent; fontFamily: column.ff
              onReleased: function(v) { root.set("backgroundOpacity", v) }
            }
          }
        }

        Card {
          SH.HubRow {
            title: root.t("place"); fg: column.fg; fontFamily: column.ff
            SH.HubPlacePicker {
              value: Settings.placeOf(root.cfg)
              fg: column.fg; accent: column.accent
              onPicked: function(p) { root.setMany({ posX: Settings.PLACES[p][0], posY: Settings.PLACES[p][1] }) }
            }
          }
          Row {
            spacing: Style.space(6)
            SH.HubChip {
              icon: "\u{f01be}"; label: root.t("drag")
              fg: column.fg; accent: column.accent; fontFamily: column.ff
              onClicked: { root.close(); root.ipc("edit") }
            }
            SH.HubChip {
              icon: "󰑓"; label: root.t("reset")
              fg: column.fg; accent: column.accent; fontFamily: column.ff
              onClicked: root.setMany(Settings.resetLook())
            }
          }
        }

        Card {
          SH.HubRow {
            title: root.t("change"); fg: column.fg; fontFamily: column.ff
            SH.HubSelect {
              width: Style.space(170); showLabel: false
              value: String(root.cfg.intervalMinutes)
              options: Settings.INTERVALS.map(function(m) { return { value: String(m), label: root.t("every")[m] } })
              foreground: column.fg; accent: column.accent; background: column.bgc; fontFamily: column.ff
              onChanged: function(v) { root.set("intervalMinutes", parseInt(v, 10)) }
            }
          }
          SH.HubChip {
            icon: "\u{f0450}"; label: root.t("now")
            on: true
            fg: column.fg; accent: column.accent; ink: column.bgc; fontFamily: column.ff
            onClicked: root.ipc("next")
          }
          SH.HubRow {
            title: root.t("language"); hint: root.t("languageHint"); fg: column.fg; fontFamily: column.ff
            SH.HubSelect {
              width: Style.space(170); showLabel: false
              value: root.cfg.lang
              options: [{ value: "en", label: "English" }, { value: "ru", label: "Русский" }]
              foreground: column.fg; accent: column.accent; background: column.bgc; fontFamily: column.ff
              onChanged: function(v) { root.set("lang", v) }
            }
          }
        }
      }
    }
  }
}
