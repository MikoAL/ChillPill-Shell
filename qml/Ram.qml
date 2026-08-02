import Quickshell
import QtQuick
import QtQuick.Layouts
import IslandBackend

// RAM usage from SysMonitor. Default shows used %, the "used" display mode
// (Config.ramDisplay) shows used GiB instead. Fixed-width reservation either
// way so the pill never breathes.
RowLayout {
  id: root

  spacing: 4 * Config.paddingScale

  readonly property bool usedMode: Config.ramDisplay === "used"

  TextMetrics { id: pctMetrics; font: valueText.font; text: "100%" }
  TextMetrics { id: usedMetrics; font: valueText.font; text: "888.8G" }

  Text {
    text: String.fromCodePoint(0xefc5)
    color: SysMonitor.ramPercent > 90 ? "#e22323"
         : SysMonitor.ramPercent > 80 ? "#eecc47"
         : Theme.fg
    font {
      family: Theme.nerdFontFamily
      pixelSize: 10 * Config.pillScale
    }
  }

  Text {
    id: valueText
    text: root.usedMode
      ? Config.formatRate(SysMonitor.ramUsedBytes)
      : Math.round(SysMonitor.ramPercent) + "%"
    color: Theme.fg
    font { family: Theme.fontFamily; weight: 500; pixelSize: 10 * Config.pillScale }
    Layout.preferredWidth: (root.usedMode ? usedMetrics : pctMetrics).width
    horizontalAlignment: Text.AlignRight
  }
}
