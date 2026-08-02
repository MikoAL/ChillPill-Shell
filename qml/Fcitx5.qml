import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

// fcitx5 input method indicator for the pill bar.
//
// Shows "中" while the chewing (zhuyin) input method is active, "EN"
// while typing in the latin layout, and "—" when fcitx5 isn't running.
// Clicking cycles between the input methods of the active group
// (keyboard-us <-> chewing) via fcitx5-remote.
RowLayout {
  id: root

  spacing: 4 * Config.paddingScale

  property string currentIm: "" // from `fcitx5-remote -n`
  property string imState: ""   // from `fcitx5-remote`: 0 close, 1 inactive, 2 active

  readonly property bool active: imState === "2"
  readonly property bool chewing: currentIm === "chewing"

  readonly property string label: {
    if (root.active && root.chewing) return "中"
    if (root.imState === "" || root.imState === "0") return "—"
    return "EN"
  }

  // re-read both fcitx5 state and current input method
  function query() {
    imStateProc.running = false
    imStateProc.running = true
    imQuery.running = false
    imQuery.running = true
  }

  Process {
    id: imStateProc
    command: ["fcitx5-remote"]
    stdout: StdioCollector {
      onStreamFinished: root.imState = this.text.trim()
    }
  }

  Process {
    id: imQuery
    command: ["fcitx5-remote", "-n"]
    stdout: StdioCollector {
      onStreamFinished: root.currentIm = this.text.trim()
    }
  }

  // busctl monitor spews many lines per state change; debounce them
  // into a single query
  Timer {
    id: queryDebounce
    interval: 80
    onTriggered: root.query()
  }

  // watch fcitx5 signals so the bar updates without polling
  // (same pattern as Volume.qml's `pactl subscribe`)
  Process {
    id: imWatch
    command: ["busctl", "--user", "monitor", "org.fcitx.Fcitx5"]
    running: true
    stdout: SplitParser {
      onRead: data => queryDebounce.restart()
    }
  }

  Component.onCompleted: root.query()

  Text {
    text: root.label
    color: {
      if (root.active && root.chewing) return "#5892f3"
      if (root.imState === "" || root.imState === "0") return "#666666"
      return Theme.fg
    }
    font {
      family: Theme.fontFamily
      pixelSize: 10 * Config.pillScale
      weight: 600
    }
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    hoverEnabled: true
    onClicked: {
      // cycle between the IMs of the default group
      imSet.command = ["fcitx5-remote", "-s", root.chewing ? "keyboard-us" : "chewing"]
      imSet.running = false
      imSet.running = true
      root.query()
    }
  }

  Process { id: imSet }
}
