import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "settings.js" as Settings

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

  function set(key, value) {
    var c = Object.assign({}, cfg)
    c[key] = value
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
    contentWidth: panel.fittedContentWidth(Style.space(340))
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
        spacing: Style.space(14)

        Text {
          textFormat: Text.PlainText
          text: root.t("title")
          color: root.bar.foreground
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.title
          font.bold: true
        }

        PanelSeparator { foreground: root.bar.foreground }

        Item {
          width: parent.width
          implicitHeight: Math.max(showLabel.implicitHeight, showSwitch.implicitHeight)
          Text {
            id: showLabel
            textFormat: Text.PlainText
            text: root.t("show")
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.body
            anchors.left: parent.left
            anchors.right: showSwitch.left
            anchors.rightMargin: Style.space(8)
            elide: Text.ElideRight
            anchors.verticalCenter: parent.verticalCenter
          }
          ToggleSwitch {
            id: showSwitch
            checked: root.cfg.visible
            foreground: root.bar.foreground
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            onToggled: root.set("visible", !root.cfg.visible)
          }
        }

        PanelSeparator { foreground: root.bar.foreground }

        Column {
          width: parent.width
          spacing: Style.space(8)
          Item {
            width: parent.width
            implicitHeight: sizeHeader.implicitHeight
            PanelSectionHeader { id: sizeHeader; text: root.t("size").toUpperCase(); foreground: root.bar.foreground; fontFamily: root.bar.fontFamily }
            Text {
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              text: Math.round((sizeSlider.dragging ? sizeSlider.liveValue : root.cfg.scale) * 100) + "%"
              color: Qt.darker(root.bar.foreground, 1.4)
              font.family: root.bar.fontFamily; font.pixelSize: Style.font.caption; font.bold: true
            }
          }
          PanelSlider {
            id: sizeSlider
            bar: root.bar
            width: parent.width
            minimum: Settings.SCALE_MIN
            maximum: Settings.SCALE_MAX
            step: 0.05
            value: root.cfg.scale
            onReleased: function(v) { root.set("scale", v) }
          }
        }

        PanelSeparator { foreground: root.bar.foreground }

        Column {
          width: parent.width
          spacing: Style.space(8)
          Item {
            width: parent.width
            implicitHeight: bgHeader.implicitHeight
            PanelSectionHeader { id: bgHeader; text: root.t("background").toUpperCase(); foreground: root.bar.foreground; fontFamily: root.bar.fontFamily }
            Text {
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              text: Math.round((bgSlider.dragging ? bgSlider.liveValue : root.cfg.backgroundOpacity) * 100) + "%"
              color: Qt.darker(root.bar.foreground, 1.4)
              font.family: root.bar.fontFamily; font.pixelSize: Style.font.caption; font.bold: true
            }
          }
          PanelSlider {
            id: bgSlider
            bar: root.bar
            width: parent.width
            minimum: 0
            maximum: Settings.OPACITY_MAX
            step: 0.05
            value: root.cfg.backgroundOpacity
            onReleased: function(v) { root.set("backgroundOpacity", v) }
          }
        }

        PanelSeparator { foreground: root.bar.foreground }

        Column {
          width: parent.width
          spacing: Style.space(10)
          PanelSectionHeader { text: root.t("position").toUpperCase(); foreground: root.bar.foreground; fontFamily: root.bar.fontFamily }
          Button {
            width: parent.width
            text: root.t("drag")
            fontSize: Style.font.bodySmall
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            horizontalPadding: Style.spacing.controlPaddingX
            verticalPadding: Style.spacing.controlPaddingY
            bordered: true
            onClicked: { root.close(); root.ipc("edit") }
          }
        }

        PanelSeparator { foreground: root.bar.foreground }

        Column {
          width: parent.width
          spacing: Style.space(10)
          PanelSectionHeader { text: root.t("change").toUpperCase(); foreground: root.bar.foreground; fontFamily: root.bar.fontFamily }
          Dropdown {
            width: parent.width
            showLabel: false
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            value: String(root.cfg.intervalMinutes)
            options: Settings.INTERVALS.map(function(m) { return { value: String(m), label: root.t("every")[m] } })
            onChanged: function(v) { root.set("intervalMinutes", parseInt(v, 10)) }
          }
          Button {
            width: parent.width
            text: root.t("now")
            fontSize: Style.font.bodySmall
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
            horizontalPadding: Style.spacing.controlPaddingX
            verticalPadding: Style.spacing.controlPaddingY
            bordered: true
            onClicked: root.ipc("next")
          }
        }

        PanelSeparator { foreground: root.bar.foreground }

        Dropdown {
          width: parent.width
          label: root.t("language")
          foreground: root.bar.foreground
          fontFamily: root.bar.fontFamily
          value: root.cfg.lang
          options: [{ value: "en", label: "English" }, { value: "ru", label: "Русский" }]
          onChanged: function(v) { root.set("lang", v) }
        }
      }
    }
  }
}
