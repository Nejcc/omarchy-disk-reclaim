import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Disk icon with the free space on /, urgent-colored under the threshold.
// Clicking opens Panel.qml, which does the real scan.
BarWidget {
  id: root
  moduleName: "nejcc.disk-reclaim"

  readonly property string icon: "󰋊"
  readonly property real warnPercent: Number(setting("warnPercent", 10))
  property var free: null
  readonly property bool low: free !== null && free.percent < warnPercent

  function refreshFree() {
    if (!dfProc.running) dfProc.running = true
  }

  // Shape contract for shell summon/hide/toggle routing (see the clock widget).
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false
  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch() }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    target.bar = root.bar
    target.settings = root.settings
    target.anchorItem = button
    target.hostWidget = root
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Process {
    id: dfProc
    command: ["df", "-B1", "--output=size,avail", "/"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.free = Model.parseDf(text) }
  }

  // statfs is cheap; five minutes is plenty for a free-space readout.
  Timer { interval: 300000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.refreshFree() }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.vertical || root.free === null ? root.icon : root.icon + " " + Model.formatBytes(root.free.avail)
    fontSize: root.vertical ? Style.bar.iconFont : Style.font.body
    active: root.low
    tooltipText: root.free === null ? "Disk Reclaim"
      : Model.formatBytes(root.free.avail) + " free of " + Model.formatBytes(root.free.size) + " on /"
    onPressed: function(b) { if (panelLoader.item) panelLoader.item.toggle() }
  }
}
