import Quickshell
import QtQuick
import QtQuick.Layouts

RowLayout {
  id: root

  property string fg: "#dadada"
  property int fontSize: 10 * Config.pillScale
  property var battery: box.battery
  property bool charging: box.charging

  spacing: 4 * Config.paddingScale

  // icon
  Text {
    text: box.batteryIcon
    color: box.batteryIconColor

    font {
      family: Theme.nerdFontFamily
      pixelSize: fontSize
    }
  }

  // percentage — fixed width so the pill never breathes when it changes
  TextMetrics { id: batteryMetrics; font: pctText.font; text: "100%" }

  Text {
    id: pctText
    text: box.batteryLevel + "%"
    color: fg
    Layout.preferredWidth: batteryMetrics.width
    horizontalAlignment: Text.AlignRight

    font {
      family: Theme.fontFamily
      weight: 500
      pixelSize: fontSize
    }
  }
}
