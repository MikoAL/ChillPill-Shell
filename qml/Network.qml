import Quickshell
import Quickshell.Networking
import QtQuick
import QtQuick.Layouts

RowLayout {
  id: root

  spacing: 4 * Config.paddingScale

  property string iconFg: "#6791dc"
  property string disconIconFg: "#9ea9bd"

  property var wifiDevice: Networking.devices.values.find(d => d.type === DeviceType.Wifi)
  property var active: wifiDevice ? wifiDevice.networks.values.find(n => n.connected) : null

  // The device's own `connected` flag is stable, unlike the per-AP scan list,
  // which can briefly drop the active AP while scanning (common at weak
  // signal). Gate the icon on it so we don't flip to "no wifi" mid-connection.
  readonly property bool connected: wifiDevice ? wifiDevice.connected : false

  // keep the last known signal/ssid so a transient list drop doesn't blank
  // the strength while we are still connected
  property real lastSignal: 0
  property string lastName: ""
  onActiveChanged: {
    if (active) {
      lastSignal = active.signalStrength
      lastName = active.name
    }
  }

  readonly property real signal: active ? active.signalStrength : lastSignal
  readonly property string ssid: active ? active.name : lastName

  // md-wifi_strength_N icons are consecutive: f091f, f0922, f0925, f0928
  readonly property string icon: {
    if (!Networking.wifiEnabled) return String.fromCodePoint(0xf092e) // wifi_strength_off_outline
    if (!connected) return String.fromCodePoint(0xf092e)

    let tier = signal >= 0.75 ? 4
             : signal >= 0.50 ? 3
             : signal >= 0.25 ? 2
             : 1

      return String.fromCodePoint(0xf091f + (tier - 1) * 3)
  }

  Text {
    text: root.icon
    color: Networking.wifiEnabled && root.connected ? iconFg : disconIconFg

    font {
      family: Theme.nerdFontFamily
      pixelSize: 10 * Config.pillScale
    }
  }

  // SSID is already in the wifi panel; only show it in the bar when asked.
  // Fixed width when shown so an elided/absent SSID can't move the bar.
  Text {
      text: {
          if (!Networking.wifiEnabled) return "off"
          if (!root.connected) return "N/A"
          return root.ssid
      }
      color: Theme.fg
      font { family: Theme.fontFamily; pixelSize: 10 * Config.pillScale; weight: 500 }
      elide: Text.ElideRight
      visible: Config.showSsidInBar
      Layout.preferredWidth: Config.showSsidInBar ? 90 * Config.pillScale : 0
  }
}
