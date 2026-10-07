import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// What can be reclaimed, biggest first, each with its own Clean button.
// Scanning is read-only (bin/disk-reclaim scan). Cleaning opens a floating
// terminal that previews and asks before anything is deleted; when that
// terminal closes, the panel scans again.
Panel {
  id: root
  moduleName: "nejcc.disk-reclaim"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  readonly property string helper: String(Qt.resolvedUrl("bin/disk-reclaim")).replace(/^file:\/\//, "")
  readonly property color fg: bar ? bar.foreground : Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  property var categories: []
  property bool scanned: false
  property string cleaningId: ""
  readonly property real total: Model.totalReclaim(categories)
  readonly property var free: hostWidget ? hostWidget.free : null

  function scan() {
    if (!scanProc.running) scanProc.running = true
  }

  function clean(id) {
    if (cleanProc.running) return
    root.cleaningId = id
    cleanProc.command = ["bash", root.helper, "launch", id]
    cleanProc.running = true
    root.close()
  }

  function open() {
    scan()
    root.controller.show()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  Process {
    id: scanProc
    command: ["bash", root.helper, "scan", "--json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.categories = Model.parseScan(text)
        root.scanned = true
      }
    }
  }

  Process {
    id: cleanProc
    onExited: function() {
      root.cleaningId = ""
      root.scan()
      if (root.hostWidget) root.hostWidget.refreshFree()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(420))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Flickable {
        id: scroll
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
          id: column
          width: scroll.width
          spacing: Style.space(12)

          PanelHero {
            title: "Disk Reclaim"
            foreground: root.fg
            fontFamily: root.fontFamily
            detail: root.scanned ? Model.formatBytes(root.total) : ""
            meta: !root.scanned ? "Scanning…"
              : (root.free ? Model.formatBytes(root.free.avail) + " free on /  ·  " : "")
                + Model.formatBytes(root.total) + " reclaimable"
            iconComponent: Text {
              textFormat: Text.PlainText
              text: "󰋊"
              color: root.hostWidget && root.hostWidget.low ? (root.bar ? root.bar.urgent : Color.urgent) : root.fg
              font.family: root.fontFamily
              font.pixelSize: Style.font.display
            }
          }

          Repeater {
            model: root.categories

            Column {
              id: row
              required property var modelData
              width: column.width
              spacing: Style.space(6)

              PanelSeparator { foreground: root.fg }

              Item {
                width: parent.width
                implicitHeight: Math.max(labels.implicitHeight, cleanButton.implicitHeight)

                Column {
                  id: labels
                  anchors.left: parent.left
                  anchors.right: cleanButton.left
                  anchors.rightMargin: Style.space(10)
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(2)

                  Text {
                    textFormat: Text.PlainText
                    width: parent.width
                    elide: Text.ElideRight
                    text: row.modelData.name + "   " + (row.modelData.reclaim >= 0
                      ? Model.formatBytes(row.modelData.reclaim)
                      : row.modelData.detail)
                    color: root.fg
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                    font.bold: true
                  }

                  Text {
                    textFormat: Text.PlainText
                    visible: row.modelData.reclaim >= 0
                    width: parent.width
                    elide: Text.ElideRight
                    text: row.modelData.detail + "  ·  " + Model.formatBytes(row.modelData.size) + " in use"
                    color: root.fg
                    opacity: 0.6
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                  }
                }

                Button {
                  id: cleanButton
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  visible: row.modelData.cleanable === true && row.modelData.reclaim > 0
                  width: visible ? implicitWidth : 0
                  text: root.cleaningId === row.modelData.id ? "Cleaning…" : "Clean"
                  active: root.cleaningId === row.modelData.id
                  fontSize: Style.font.bodySmall
                  foreground: root.fg
                  fontFamily: root.fontFamily
                  bordered: true
                  onClicked: root.clean(row.modelData.id)
                }
              }

              Text {
                textFormat: Text.PlainText
                width: parent.width
                wrapMode: Text.WordWrap
                text: row.modelData.description
                color: root.fg
                opacity: 0.6
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }
            }
          }
        }
      }
    }
  }
}
