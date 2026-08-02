import Quickshell
import QtQuick
import QtQuick.Layouts
import IslandBackend

// live upload throughput from SysMonitor. Fixed-width reservation for the
// worst case "888.8M" so the value never makes the pill breathe.
RowLayout {
  id: root

  spacing: 4 * Config.paddingScale

  TextMetrics { id: metrics; font: valueText.font; text: "888.8M" }

  Text {
    text: String.fromCodePoint(0xf0aa)
    color: "#a8a8a8"
    font {
      family: Theme.nerdFontFamily
      pixelSize: 10 * Config.pillScale
    }
  }

  Text {
    id: valueText
    text: Config.formatRate(SysMonitor.txBytesPerSec)
    color: Theme.fg
    font { family: Theme.fontFamily; weight: 500; pixelSize: 10 * Config.pillScale }
    Layout.preferredWidth: metrics.width
    horizontalAlignment: Text.AlignRight
  }
}
