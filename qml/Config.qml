pragma Singleton
import Quickshell
import Quickshell.Io

Singleton {
  id: root

  // false until the file has been read (or found missing): the adapter holds
  // the fallback values below until then, which matters for anything that's
  // costly to create and then throw away (e.g. the notification SoundEffect)
  property bool loaded: false

  FileView {
    path: Quickshell.env("HOME") + "/.config/chillpill-shell/config.jsonc"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: root.loaded = true
    onLoadFailed: root.loaded = true

    // fallback values
    JsonAdapter {
      id: adapter
      property string displayPicture: "~/.pfp.png"
      property string clockFormat: "MMM d  HH:mm:ss"
      property int pillTopMargin: 9
      property int pillBottomMargin: 26
      property string textFontFamily: "Monocraft"
      property string nerdFontFamily: "JetBrainsMono Nerd Font Propo"
      property list<int> timerPresets: [1, 5, 10, 15, 30]
      property int maxWorkspaces: 5
      property int notificationDisplayTime: 3000
      property int maxNotificationsInStack: 20
      property int bandwidthRefreshInterval: 300000
      property string screenLockAppCommand: "hyprlock"
      property int osdDuration: 800
      property string weatherUnits: "metric"
      property string weatherLocation: "Delhi"
      property int weatherRefreshInterval: 3600000
      property bool avoidDuplicateNotifications: true
      property bool notificationSound: true
      property string defaultTerminal: "kitty"
      property real pillScale: 1.0
      property int sysMonitorInterval: 2000
      property bool showSsidInBar: false
      property string ramDisplay: "percent"
      property string netExcludeInterfaces: "^(lo|docker|veth|br-|virbr|tun|wg)"
      property int zoneGap: 20
      property int pillSidePadding: 16
    }
  }

  // deterministic rate formatter shared by the net/cpu modules.
  // scales to K/M/G on 1024 boundaries, one decimal below 10, zero at/above,
  // single-char unit, no /s. 0 renders as "0K".
  function formatRate(bytesPerSec) {
    if (bytesPerSec <= 0) return "0K"
    let v = bytesPerSec / 1024.0
    let u = 0
    const units = ["K", "M", "G"]
    while (v >= 1024 && u < units.length - 1) { v /= 1024; u++ }
    if (v < 10) return v.toFixed(1) + units[u]
    return Math.round(v) + units[u]
  }

  // "~/" expands to $HOME so the shipped config works for any user
  readonly property string displayPicture: adapter.displayPicture.startsWith("~/")
      ? Quickshell.env("HOME") + adapter.displayPicture.slice(1)
      : adapter.displayPicture
  readonly property alias clockFormat: adapter.clockFormat
  readonly property alias pillTopMargin: adapter.pillTopMargin
  readonly property alias pillBottomMargin: adapter.pillBottomMargin
  readonly property alias textFontFamily: adapter.textFontFamily
  readonly property alias nerdFontFamily: adapter.nerdFontFamily
  readonly property alias timerPresets: adapter.timerPresets
  readonly property alias maxWorkspaces: adapter.maxWorkspaces
  readonly property alias notificationDisplayTime: adapter.notificationDisplayTime
  readonly property alias maxNotificationsInStack: adapter.maxNotificationsInStack
  readonly property alias bandwidthRefreshInterval: adapter.bandwidthRefreshInterval
  readonly property alias screenLockAppCommand: adapter.screenLockAppCommand
  readonly property alias osdDuration: adapter.osdDuration
  readonly property alias weatherUnits: adapter.weatherUnits
  readonly property alias weatherLocation: adapter.weatherLocation
  readonly property alias weatherRefreshInterval: adapter.weatherRefreshInterval
  readonly property alias avoidDuplicateNotifications: adapter.avoidDuplicateNotifications
  readonly property alias notificationSound: adapter.notificationSound
  readonly property alias defaultTerminal: adapter.defaultTerminal
  readonly property alias pillScale: adapter.pillScale
  readonly property alias sysMonitorInterval: adapter.sysMonitorInterval
  readonly property alias showSsidInBar: adapter.showSsidInBar
  readonly property alias ramDisplay: adapter.ramDisplay
  readonly property alias netExcludeInterfaces: adapter.netExcludeInterfaces
  readonly property alias zoneGap: adapter.zoneGap
  readonly property alias pillSidePadding: adapter.pillSidePadding
  readonly property real paddingScale: 1 + (pillScale - 1) * 0.6  // sub linear, keep padding sane
}
