import Quickshell
import QtQuick
import QtQuick.Layouts

// battery charge/discharge rate from UPower (watts), smoothed as a rolling
// average of 1s samples over the last 5 seconds so it doesn't jitter with
// every noisy UPower reading. Sampling is a local property read (UPower is
// already pushing live updates via DBus), not a poll of any hardware/service.
// Sign is dropped — the battery icon elsewhere already shows charging vs.
// discharging.
RowLayout {
  id: root

  property int fontSize: 10 * Config.pillScale
  property var samples: []
  readonly property real avgRate: samples.length
    ? samples.reduce((sum, s) => sum + s, 0) / samples.length
    : 0

  Timer {
    interval: 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      const next = root.samples.concat([Math.abs(box.battery.changeRate)])
      root.samples = next.length > 5 ? next.slice(next.length - 5) : next
    }
  }

  spacing: 4 * Config.paddingScale

  TextMetrics { id: metrics; font: valueText.font; text: "888.8W" }

  Text {
    id: valueText
    text: root.avgRate.toFixed(1) + "W"
    color: Theme.fg
    font { family: Theme.fontFamily; weight: 500; pixelSize: root.fontSize }
    Layout.preferredWidth: metrics.width
    horizontalAlignment: Text.AlignRight
  }
}
