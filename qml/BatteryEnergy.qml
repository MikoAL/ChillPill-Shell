import Quickshell
import QtQuick
import QtQuick.Layouts

// live battery energy level from UPower, in watt-hours.
RowLayout {
  id: root

  property int fontSize: 10 * Config.pillScale

  spacing: 4 * Config.paddingScale

  TextMetrics { id: metrics; font: valueText.font; text: "888.8Wh" }

  Text {
    id: valueText
    text: box.battery.energy.toFixed(1) + "Wh"
    color: Theme.fg
    font { family: Theme.fontFamily; weight: 500; pixelSize: root.fontSize }
    Layout.preferredWidth: metrics.width
    horizontalAlignment: Text.AlignRight
  }
}
