import Quickshell
import QtQuick
import QtQuick.Layouts
import IslandBackend

// aggregate CPU busy % from SysMonitor. Fixed-width value so the pill never
// breathes when the number changes; color ramp on the glyph at high load.
RowLayout {
  id: root

  spacing: 4 * Config.paddingScale

  TextMetrics { id: metrics; font: valueText.font; text: "100%" }

  Text {
    text: String.fromCodePoint(0xf4bc)
    color: SysMonitor.cpuPercent > 90 ? "#e22323"
         : SysMonitor.cpuPercent > 70 ? "#eecc47"
         : Theme.fg
    font {
      family: Theme.nerdFontFamily
      pixelSize: 10 * Config.pillScale
    }
  }

  Text {
    id: valueText
    text: Math.round(SysMonitor.cpuPercent) + "%"
    color: Theme.fg
    font { family: Theme.fontFamily; weight: 500; pixelSize: 10 * Config.pillScale }
    Layout.preferredWidth: metrics.width
    horizontalAlignment: Text.AlignRight
  }
}
