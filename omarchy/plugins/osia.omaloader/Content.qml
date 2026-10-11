import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import qs.Commons
import "Model.js" as Model
import "I18n.js" as I18n
import "../osia.soundhub" as SH

// Omaloader's UI (Download and Settings tabs) over an Engine given as
// `host`, in SoundHub's look: a sliding segmented tab strip, soft cards,
// pill fields, selects and switches. Used by the bar panel and by TheNotch.
Column {
  id: contentCol
  property var host: null
  property alias urlField: urlField.input
  // "" both tabs with the strip (bar panel); "download" or "settings" alone (TheNotch)
  property string only: ""
  readonly property int shownTab: only === "download" ? 0 : only === "settings" ? 1 : (host ? host.tab : 0)
  width: parent ? parent.width : 0
  spacing: SH.HubStyle.gap

  readonly property color fg: host ? host.fg : "white"
  readonly property color accent: host ? host.accent : "white"
  readonly property color urgent: host ? host.urgent : "red"
  readonly property color bgc: Color.background
  readonly property string ff: host ? host.ff : ""
  readonly property real selW: Style.space(170)

  component Section: Column {
    property alias title: cap.text
    property alias icon: cap.icon
    default property alias rows: body.data
    width: setCol.width
    spacing: Style.space(6)
    SH.HubCaption { id: cap; fg: contentCol.fg; fontFamily: contentCol.ff }
    SH.HubCard {
      width: parent.width
      height: body.implicitHeight + SH.HubStyle.pad * 2
      fg: contentCol.fg; accent: contentCol.accent
      Column {
        id: body
        x: SH.HubStyle.pad; y: SH.HubStyle.pad
        width: parent.width - SH.HubStyle.pad * 2
        spacing: Style.space(10)
      }
    }
  }
  component Switch: SH.HubRow {
    id: sw
    property string key: ""
    property bool fallback: false
    fg: contentCol.fg; fontFamily: contentCol.ff
    SH.HubSwitch {
      checked: contentCol.host ? contentCol.host.opt(sw.key, sw.fallback) === true : false
      fg: contentCol.fg; accent: contentCol.accent; ink: contentCol.bgc
      onToggled: { var v = {}; v[sw.key] = !checked; contentCol.host.persist(v) }
    }
  }
  component Select: SH.HubSelect {
    width: contentCol.selW
    showLabel: false
    foreground: contentCol.fg; accent: contentCol.accent; background: contentCol.bgc; fontFamily: contentCol.ff
  }

  // ---- tabs: a segmented control with a sliding pill ----
  Rectangle {
    id: strip
    visible: contentCol.only === ""
    width: parent.width
    height: SH.HubStyle.controlH + Style.space(8)
    radius: height / 2
    color: SH.HubStyle.tint(contentCol.fg, SH.HubStyle.surface)
    readonly property real pad: Style.space(4)
    readonly property real tabW: (width - pad * 2) / 2

    Rectangle {
      x: strip.pad + strip.tabW * (host ? host.tab : 0)
      y: strip.pad
      width: strip.tabW; height: strip.height - strip.pad * 2
      radius: height / 2
      color: contentCol.accent
      Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
    }
    Repeater {
      model: [{ icon: "󰇚", key: "tab.download" }, { icon: "󰒓", key: "tab.settings" }]
      delegate: Item {
        id: tabItem
        required property var modelData
        required property int index
        readonly property bool current: host && host.tab === index
        x: strip.pad + strip.tabW * index; y: strip.pad
        width: strip.tabW; height: strip.height - strip.pad * 2
        Row {
          anchors.centerIn: parent
          spacing: Style.space(7)
          Text {
            text: tabItem.modelData.icon
            color: tabItem.current ? contentCol.bgc : Qt.darker(contentCol.fg, 1.25)
            font.family: contentCol.ff; font.pixelSize: Style.font.body + 1
          }
          Text {
            text: host ? host.t(tabItem.modelData.key) : ""
            color: tabItem.current ? contentCol.bgc : Qt.darker(contentCol.fg, 1.25)
            font.family: contentCol.ff; font.pixelSize: Style.font.body; font.bold: tabItem.current
          }
        }
        Rectangle {                                   // busy dot on Settings while downloading
          visible: tabItem.index === 1 && host && host.running && host.tab !== 1
          anchors.right: parent.right; anchors.rightMargin: Style.space(14)
          anchors.verticalCenter: parent.verticalCenter
          width: Style.space(6); height: width; radius: width / 2
          color: contentCol.accent
        }
        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: { host.tab = tabItem.index; if (tabItem.index === 0) urlField.forceActiveFocus() }
        }
      }
    }
  }

  // ---- tab pages; settings scrolls inside the downloader page's height ----
  Item {
    width: parent.width
    height: contentCol.only === "settings" ? setCol.implicitHeight : grabCol.implicitHeight

    // ======== tab 0: downloader ========
    Column {
      id: grabCol
      width: parent.width
      spacing: SH.HubStyle.gap
      visible: contentCol.shownTab === 0

      Row {
        width: parent.width
        spacing: Style.space(8)
        SH.HubField {
          id: urlField
          width: parent.width - pasteBtn.width - parent.spacing
          icon: "󰌷"
          placeholderText: host ? host.t("url.placeholder") : ""
          fg: contentCol.fg; accent: contentCol.accent; fontFamily: contentCol.ff
          // two-way with the engine: typing sets host.url, a paste sets the field
          text: host ? host.url : ""
          onTextEdited: if (host && text !== host.url) { host.url = text; host.onUrlEdited() }
          onAccepted: if (!host.running) host.startDownload()
        }
        SH.HubChip {
          id: pasteBtn
          iconOnly: true
          icon: "󰆒"
          label: host ? host.t("url.paste") : ""
          fg: contentCol.fg; accent: contentCol.accent; fontFamily: contentCol.ff
          onClicked: host.pasteFromClipboard()
        }
      }

      // ---- preview ----
      ClippingRectangle {
        width: parent.width
        height: Style.space(176)
        radius: SH.HubStyle.radius
        color: SH.HubStyle.tint(contentCol.fg, SH.HubStyle.surface)

        Image {
          id: thumb
          anchors.fill: parent
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          cache: false
          source: host ? host.previewThumb : ""
          visible: status === Image.Ready && host.previewThumb !== ""
        }
        Rectangle {
          anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
          height: parent.height * 0.6
          visible: thumb.visible
          gradient: Gradient {
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.72) }
          }
        }
        Column {
          anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
          anchors.margins: SH.HubStyle.pad
          spacing: Style.space(2)
          visible: thumb.visible && host.previewTitle !== ""
          Text {
            width: parent.width
            text: host ? host.previewTitle : ""
            color: "white"
            font.family: contentCol.ff; font.pixelSize: Style.font.body; font.bold: true
            wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight
          }
          Text {
            width: parent.width
            text: host ? host.previewMeta : ""
            color: Qt.rgba(1, 1, 1, 0.8)
            font.family: contentCol.ff; font.pixelSize: Style.font.caption
            elide: Text.ElideRight
          }
        }
        Column {
          anchors.centerIn: parent
          visible: !thumb.visible
          spacing: Style.space(8)
          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: host && host.infoLoading ? "󰔟" : "󰕧"
            color: Qt.darker(contentCol.fg, 1.8)
            font.family: contentCol.ff; font.pixelSize: Style.space(30)
            RotationAnimator on rotation { running: host && host.infoLoading; from: 0; to: 360; duration: 1400; loops: Animation.Infinite }
          }
          Text {
            width: contentCol.width - Style.space(40)
            horizontalAlignment: Text.AlignHCenter
            text: !host ? "" : host.infoLoading ? host.t("preview.loading")
                : (host.previewTitle !== "" ? host.previewTitle : host.t("preview.empty"))
            elide: Text.ElideRight
            color: Qt.darker(contentCol.fg, 1.5)
            font.family: contentCol.ff; font.pixelSize: Style.font.caption
          }
        }
        Rectangle {                                   // proxy badge
          visible: host && host.activeProxy !== ""
          anchors.top: parent.top; anchors.right: parent.right
          anchors.margins: Style.space(10)
          width: proxyBadge.implicitWidth + Style.space(16); height: proxyBadge.implicitHeight + Style.space(6)
          radius: height / 2
          color: SH.HubStyle.tint(contentCol.accent, 0.85)
          Text {
            id: proxyBadge
            anchors.centerIn: parent
            text: host ? host.t("preview.proxy") : ""
            color: contentCol.bgc
            font.family: contentCol.ff; font.pixelSize: Style.font.caption - 1; font.bold: true
          }
        }
      }

      // ---- quality ----
      SH.HubCard {
        width: parent.width
        height: qCol.implicitHeight + SH.HubStyle.pad * 2
        fg: contentCol.fg; accent: contentCol.accent
        Column {
          id: qCol
          x: SH.HubStyle.pad; y: SH.HubStyle.pad
          width: parent.width - SH.HubStyle.pad * 2
          spacing: Style.space(10)
          SH.HubRow {
            title: host ? host.t("quality.video") : ""; fg: contentCol.fg; fontFamily: contentCol.ff
            Select {
              id: videoDd
              icon: "󰕧"
              options: host ? Model.videoOptions(host.lang) : []
              value: host ? host.video : "best"
              onChanged: function(v) {
                if (Model.isSeparator(v)) { videoDd.value = host.prevVideo; return }
                host.prevVideo = v; host.video = v; host.persist({ video: v })
              }
            }
          }
          SH.HubRow {
            title: host ? host.t("quality.audio") : ""; fg: contentCol.fg; fontFamily: contentCol.ff
            opacity: host && Model.isGif(host.video) ? 0.45 : 1
            enabled: !(host && Model.isGif(host.video))
            Select {
              icon: "󰎈"
              options: host ? Model.audioOptions(host.lang) : []
              value: host ? host.audio : "best"
              onChanged: function(v) { host.audio = v; host.persist({ audio: v }) }
            }
          }
        }
      }

      // ---- download / cancel: one wide pill ----
      Rectangle {
        width: parent.width
        height: SH.HubStyle.controlH + Style.space(8)
        radius: height / 2
        color: !host ? "transparent" : host.running ? SH.HubStyle.tint(contentCol.urgent, dlMouse.containsMouse ? 0.32 : 0.22)
             : dlMouse.containsMouse ? Qt.lighter(contentCol.accent, 1.08) : contentCol.accent
        Behavior on color { ColorAnimation { duration: SH.HubStyle.anim } }
        Row {
          anchors.centerIn: parent
          spacing: Style.space(8)
          Text {
            text: host && host.running ? "󰜺" : "󰇚"
            color: host && host.running ? contentCol.urgent : contentCol.bgc
            font.family: contentCol.ff; font.pixelSize: Style.font.body + 1
          }
          Text {
            text: !host ? "" : host.running ? host.t("btn.cancel")
                : host.t(Model.isGif(host.video) ? "btn.downloadGif" : (host.video === "none" ? "btn.downloadAudio" : "btn.download"))
            color: host && host.running ? contentCol.urgent : contentCol.bgc
            font.family: contentCol.ff; font.pixelSize: Style.font.body; font.bold: true
          }
        }
        MouseArea {
          id: dlMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: host.running ? host.cancelDownload() : host.startDownload()
        }
      }

      // ---- progress + status ----
      Rectangle {
        width: parent.width
        height: Style.space(6)
        radius: height / 2
        visible: host && (host.running || host.dlState === "done" || host.dlState === "error")
        color: SH.HubStyle.tint(contentCol.fg, 0.12)
        Rectangle {
          height: parent.height
          radius: height / 2
          width: host && host.indeterminate ? parent.width : Math.max(Style.space(6), parent.width * (host ? host.progress : 0) / 100)
          color: host && host.dlState === "error" ? contentCol.urgent : contentCol.accent
          Behavior on width { NumberAnimation { duration: 200 } }
          SequentialAnimation on opacity {
            running: host && host.indeterminate && host.running
            loops: Animation.Infinite
            NumberAnimation { from: 0.25; to: 0.75; duration: 700 }
            NumberAnimation { from: 0.75; to: 0.25; duration: 700 }
          }
        }
      }
      Text {
        width: parent.width
        visible: host && host.statusText !== ""
        leftPadding: Style.space(4)
        text: host ? host.statusText : ""
        color: !host ? "white" : host.dlState === "error" ? contentCol.urgent
             : host.dlState === "done" ? contentCol.accent : Qt.darker(contentCol.fg, 1.3)
        font.family: contentCol.ff; font.pixelSize: Style.font.caption
        wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight
      }
    }

    // ======== tab 1: settings ========
    Flickable {
      id: settingsFlick
      anchors.fill: parent
      visible: contentCol.shownTab === 1
      contentWidth: width
      contentHeight: setCol.implicitHeight
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      flickableDirection: Flickable.VerticalFlick
      interactive: contentHeight > height
      ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

      Column {
        id: setCol
        width: settingsFlick.width - Style.space(8)        // room for the scrollbar
        spacing: SH.HubStyle.gap

        Section {
          title: host ? host.t("sec.interface") : ""; icon: "󰗊"
          SH.HubRow {
            title: host ? host.t("set.language") : ""; fg: contentCol.fg; fontFamily: contentCol.ff
            Select {
              options: I18n.LANGS
              value: host ? host.lang : "en"
              onChanged: function(v) { host.persist({ lang: v }) }
            }
          }
        }

        Section {
          title: host ? host.t("sec.proxy") : ""; icon: "󰖟"
          SH.HubRow {
            title: host ? host.t("proxy.active") : ""; fg: contentCol.fg; fontFamily: contentCol.ff
            Select {
              options: host ? [{ value: "", label: host.t("proxy.none") }].concat(host.proxies.map(function(p) { return { value: p.url, label: p.name } })) : []
              value: host ? host.activeProxy : ""
              onChanged: function(v) { host.persist({ activeProxy: v }) }
            }
          }
          Repeater {
            model: host ? host.proxies : []
            delegate: Rectangle {
              id: proxyRow
              required property var modelData
              readonly property bool isActive: modelData.url === host.activeProxy
              readonly property var status: host.proxyStatus[modelData.url]
              width: parent ? parent.width : 0
              height: SH.HubStyle.controlH + Style.space(14)
              radius: SH.HubStyle.radiusSmall
              color: isActive ? SH.HubStyle.tint(contentCol.accent, 0.14) : SH.HubStyle.tint(contentCol.fg, SH.HubStyle.surface)
              border.width: isActive ? 1 : 0
              border.color: SH.HubStyle.tint(contentCol.accent, 0.45)
              Column {
                anchors.left: parent.left; anchors.leftMargin: Style.space(12)
                anchors.right: proxyActions.left; anchors.rightMargin: Style.space(8)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(1)
                Text {
                  width: parent.width
                  text: proxyRow.modelData.name
                  color: proxyRow.isActive ? contentCol.accent : contentCol.fg
                  font.family: contentCol.ff; font.pixelSize: Style.font.body; font.bold: proxyRow.isActive
                  elide: Text.ElideRight
                }
                Text {
                  width: parent.width
                  text: Model.maskProxy(proxyRow.modelData.url) + (proxyRow.status ? "   ·   " + host.t(proxyRow.status.key, proxyRow.status.arg) : "")
                  color: proxyRow.status && !proxyRow.status.ok ? contentCol.urgent : Qt.darker(contentCol.fg, 1.5)
                  font.family: contentCol.ff; font.pixelSize: Style.font.caption - 1
                  elide: Text.ElideMiddle
                }
              }
              Row {
                id: proxyActions
                anchors.right: parent.right; anchors.rightMargin: Style.space(8)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(4)
                SH.HubChip {
                  iconOnly: true; h: Style.space(26)
                  icon: proxyRow.isActive ? "󰄬" : "󰐕"
                  label: host.t(proxyRow.isActive ? "proxy.isActive" : "proxy.makeActive")
                  on: proxyRow.isActive
                  fg: contentCol.fg; accent: contentCol.accent; ink: contentCol.bgc; fontFamily: contentCol.ff
                  onClicked: host.persist({ activeProxy: proxyRow.isActive ? "" : proxyRow.modelData.url })
                }
                SH.HubChip {
                  iconOnly: true; h: Style.space(26)
                  icon: "󰓅"
                  label: host.t("proxy.test")
                  enabled: host.testingUrl === ""
                  fg: contentCol.fg; accent: contentCol.accent; fontFamily: contentCol.ff
                  onClicked: host.testProxy(proxyRow.modelData.url)
                }
                SH.HubChip {
                  iconOnly: true; h: Style.space(26)
                  icon: "󰆴"
                  label: host.t("proxy.remove")
                  fg: contentCol.fg; accent: contentCol.accent; fontFamily: contentCol.ff
                  onClicked: host.removeProxy(proxyRow.modelData.url)
                }
              }
            }
          }
          Row {
            width: parent ? parent.width : 0
            spacing: Style.space(6)
            SH.HubField {
              id: proxyName
              width: Math.round(parent.width * 0.3)
              placeholderText: host ? host.t("proxy.name") : ""
              fg: contentCol.fg; accent: contentCol.accent; fontFamily: contentCol.ff
              onAccepted: proxyUrl.input.forceActiveFocus()
            }
            SH.HubField {
              id: proxyUrl
              width: parent.width - proxyName.width - addProxyBtn.width - parent.spacing * 2
              placeholderText: "socks5://127.0.0.1:1080"
              fg: contentCol.fg; accent: contentCol.accent; fontFamily: contentCol.ff
              onTextEdited: host.proxyFormError = ""
              onAccepted: addProxyBtn.clicked()
            }
            SH.HubChip {
              id: addProxyBtn
              iconOnly: true
              icon: "󰐕"
              label: host ? host.t("proxy.add") : ""
              on: true
              fg: contentCol.fg; accent: contentCol.accent; ink: contentCol.bgc; fontFamily: contentCol.ff
              onClicked: if (host.addProxy(proxyName.text, proxyUrl.text)) { proxyName.text = ""; proxyUrl.text = "" }
            }
          }
          Text {
            width: parent ? parent.width : 0
            wrapMode: Text.Wrap
            text: !host ? "" : host.proxyFormError !== "" ? host.proxyFormError : host.t("proxy.hint")
            color: host && host.proxyFormError !== "" ? contentCol.urgent : Qt.darker(contentCol.fg, 1.7)
            font.family: contentCol.ff; font.pixelSize: Style.font.caption - 1
          }
        }

        Section {
          title: host ? host.t("sec.download") : ""; icon: "󰉍"
          SH.HubField {
            width: parent ? parent.width : 0
            icon: "󰉋"
            placeholderText: host ? host.t("set.folder") : ""
            fg: contentCol.fg; accent: contentCol.accent; fontFamily: contentCol.ff
            text: host ? String(host.opt("downloadDir", "") || "") : ""
            onEditingFinished: if (text !== String(host.opt("downloadDir", "") || "")) host.persist({ downloadDir: text.trim() })
          }
          Switch { key: "autoPaste"; title: host ? host.t("set.autoPaste") : ""; hint: host ? host.t("set.autoPasteDesc") : "" }
          SH.HubRow {
            title: host ? host.t("set.container") : ""; fg: contentCol.fg; fontFamily: contentCol.ff
            Select {
              options: host ? Model.containerOptions(host.lang) : []
              value: host ? String(host.opt("container", "auto")) : "auto"
              onChanged: function(v) { host.persist({ container: v }) }
            }
          }
          SH.HubRow {
            title: host ? host.t("set.audioFormat") : ""; fg: contentCol.fg; fontFamily: contentCol.ff
            Select {
              options: Model.audioFormatOptions()
              value: host ? String(host.opt("audioFormat", "m4a")) : "m4a"
              onChanged: function(v) { host.persist({ audioFormat: v }) }
            }
          }
          SH.HubRow {
            title: host ? host.t("set.rate") : ""; fg: contentCol.fg; fontFamily: contentCol.ff
            Select {
              options: host ? Model.rateOptions(host.lang) : []
              value: host ? String(host.opt("rate", "")) : ""
              onChanged: function(v) { host.persist({ rate: v }) }
            }
          }
          Switch { key: "fragments"; fallback: true; title: host ? host.t("set.fragments") : ""; hint: host ? host.t("set.fragmentsDesc") : "" }
          Switch { key: "playlist"; title: host ? host.t("set.playlist") : ""; hint: host ? host.t("set.playlistDesc") : "" }
        }

        Section {
          title: host ? host.t("sec.processing") : ""; icon: "󰒓"
          Switch { key: "embedThumb"; title: host ? host.t("set.embedThumb") : ""; hint: host ? host.t("set.embedThumbDesc") : "" }
          Switch { key: "embedSubs"; title: host ? host.t("set.embedSubs") : ""; hint: host ? host.t("set.embedSubsDesc") : "" }
          SH.HubField {
            width: parent ? parent.width : 0
            visible: host && host.opt("embedSubs", false) === true
            icon: "󰨖"
            placeholderText: host ? host.t("set.subLangs") : ""
            fg: contentCol.fg; accent: contentCol.accent; fontFamily: contentCol.ff
            text: host ? String(host.opt("subLangs", "ru,en")) : ""
            onEditingFinished: { var t = text.replace(/\s+/g, ""); if (t) host.persist({ subLangs: t }) }
          }
          Switch { key: "sponsor"; title: host ? host.t("set.sponsor") : ""; hint: host ? host.t("set.sponsorDesc") : "" }
        }

        Section {
          title: host ? host.t("sec.access") : ""; icon: "󰆥"
          SH.HubRow {
            title: host ? host.t("set.cookies") : ""; hint: host ? host.t("set.cookiesHint") : ""
            fg: contentCol.fg; fontFamily: contentCol.ff
            Select {
              options: host ? Model.cookiesOptions(host.lang) : []
              value: host ? String(host.opt("cookies", "")) : ""
              onChanged: function(v) { host.persist({ cookies: v }) }
            }
          }
        }

        Section {
          title: host ? host.t("sec.after") : ""; icon: "󰄬"
          Switch { key: "notify"; fallback: true; title: host ? host.t("set.notify") : ""; hint: host ? host.t("set.notifyDesc") : "" }
          Switch { key: "openAfter"; title: host ? host.t("set.openAfter") : ""; hint: host ? host.t("set.openAfterDesc") : "" }
        }

        Item { width: 1; height: Style.space(4) }
      }
    }
  }
}
