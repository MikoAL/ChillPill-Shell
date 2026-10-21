import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts

RowLayout {
  id: root
  signal volumeChanged
  onVolChanged: root.volumeChanged()
  onMutedChanged: root.volumeChanged()
  property string fg: Theme.fg
  property string mutedFg: "#fb2a2a"
  property var sink: Pipewire.defaultAudioSink
  readonly property bool ready: sink && sink.ready
  readonly property bool muted: ready && sink.audio.muted
  readonly property int vol: ready ? Math.round(sink.audio.volume * 100) : 0

  property string activePort: ""
  readonly property bool isHeadphone: activePort.indexOf("headphone") !== -1
                                     || activePort.indexOf("headset") !== -1
  spacing: 4 * Config.paddingScale
  function checkPort() {
    if (!ready) return
    portCheck.command = ["bash", "-c",
      "pactl list sinks | awk -v RS='' '/Name: " + sink.name + "/' | grep -oP 'Active Port: \\K.*'"]
    portCheck.running = true
  }

  Process {
    id: portCheck
    stdout: SplitParser { onRead: data => root.activePort = data.trim() }
  }

  // every volume step is also a "change on sink" event; coalesce them so a
  // slider drag or held volume key doesn't spawn a pactl pipeline per event
  Timer {
    id: portCheckDebounce
    interval: 250
    onTriggered: root.checkPort()
  }

  // watch for jack plug/unplug events ral time
  Process {
    running: true
    command: ["pactl", "subscribe"]
    stdout: SplitParser {
      onRead: data => { if (data.indexOf("on sink") !== -1) portCheckDebounce.restart() }
    }
  }

  Component.onCompleted: checkPort()
  onSinkChanged: checkPort()

  property string icon: {
    if (!ready || muted) return isHeadphone ? "\uf025" : String.fromCodePoint(0xf0581)
    if (isHeadphone) return "\uee58"
    if (vol === 0) return String.fromCodePoint(0xf0581)
    if (vol < 40) return String.fromCodePoint(0xf0580)
    return String.fromCodePoint(0xf057e)
  }

  // icon
  Text {
    text: root.icon

    color: root.muted || vol === 0 ? root.mutedFg : root.fg

    font.family: Theme.nerdFontFamily
    font.pixelSize: 10 * Config.pillScale
  }

  // handlers, not a MouseArea: a RowLayout would try to lay out a MouseArea.
  // grab on press so the pill's own click (dashboard) doesn't fire too
  HoverHandler { cursorShape: Qt.PointingHandCursor }
  TapHandler {
    gesturePolicy: TapHandler.ReleaseWithinBounds
    onTapped: sink.audio.muted = !sink.audio.muted
  }

  // percentage
  TextMetrics { id: volMetrics; font: volText.font; text: "100%" }

  Text {
    id: volText
    text: {
      if (!root.ready) return "-"
      if (root.muted) return "0%"
      return root.vol + "%"
    }
    color: fg
    Layout.preferredWidth: volMetrics.width
    horizontalAlignment: Text.AlignRight

    font {
      pixelSize: 10 * Config.pillScale
      family: Theme.fontFamily
      weight: 500
    }
  }

  PwObjectTracker {
    objects: [root.sink]
  }
}
