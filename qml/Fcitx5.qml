import Quickshell
import QtQuick
import QtQuick.Layouts
import IslandBackend

// fcitx5 input method indicator for the pill bar.
//
// Shows "中" while the chewing (zhuyin) input method is active, "EN"
// while typing in the latin layout, and "—" when fcitx5 isn't running.
// Clicking cycles between the input methods of the active group
// (keyboard-us <-> chewing), like `fcitx5-remote -s`.
RowLayout {
  id: root

  spacing: 4 * Config.paddingScale
  visible: root.fcitxRunning  // zero width when fcitx5 isn't running

  // state/IM come from the backend's D-Bus poller (see Fcitx5Monitor.h).
  // fcitx5 emits no signal on an IM switch, and the old `busctl monitor` +
  // fcitx5-remote approach fed itself: every query was bus traffic the
  // monitor reported, which re-armed the query, ~12 queries/s forever.
  readonly property string currentIm: Fcitx5Monitor.currentIm
  readonly property int imState: Fcitx5Monitor.state  // 0 close, 1 inactive, 2 active

  readonly property bool active: imState === 2
  readonly property bool chewing: currentIm === "chewing"

  // hide entirely (zero width) instead of showing a stale glyph
  readonly property bool fcitxRunning: Fcitx5Monitor.available

  readonly property string label: {
    if (root.active && root.chewing) return "中"
    if (!root.fcitxRunning || root.imState === 0) return "—"
    return "EN"
  }

  // reserve the worst-case label width ("EN") so the bar never breathes
  // when toggling between 中 / EN / —
  TextMetrics { id: labelMetrics; font: labelText.font; text: "EN" }

  Text {
    id: labelText
    text: root.label
    color: {
      if (root.active && root.chewing) return "#5892f3"
      if (!root.fcitxRunning || root.imState === 0) return "#666666"
      return Theme.fg
    }
    Layout.preferredWidth: labelMetrics.width
    horizontalAlignment: Text.AlignRight
    font {
      family: Theme.fontFamily
      pixelSize: 10 * Config.pillScale
      weight: 600
    }
  }

  // handlers, not a MouseArea: a RowLayout would try to lay out a MouseArea.
  // grab on press so the pill's own click (dashboard) doesn't fire too
  HoverHandler { cursorShape: Qt.PointingHandCursor }
  TapHandler {
    gesturePolicy: TapHandler.ReleaseWithinBounds
    // cycle between the IMs of the default group
    onTapped: Fcitx5Monitor.setCurrentIm(root.chewing ? "keyboard-us" : "chewing")
  }
}
