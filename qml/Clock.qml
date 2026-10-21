import Quickshell
import QtQuick

Text {
  id: root

  property string fontFamily: Theme.fontFamily

  // worst case of "MMM d  HH:mm:ss": longest month (Sept), two-digit day
  TextMetrics { id: metrics; font: root.font; text: "Sept 30  00:00:00" }

  // force English month names regardless of the system locale
  readonly property var enLocale: Qt.locale("en_US")
  text: clock.date.toLocaleString(enLocale, Config.clockFormat)
  color: Theme.fg
  width: metrics.width
  horizontalAlignment: Text.AlignRight

  font {
    family: Theme.fontFamily
    weight: 500
    pixelSize: 10 * Config.pillScale
    letterSpacing: -0.5
  }
}
