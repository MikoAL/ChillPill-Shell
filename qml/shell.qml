import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Widgets
import Quickshell.Services.UPower
import Quickshell.Services.Notifications
import IslandBackend

ShellRoot {

  IpcHandler {
      target: "cliphist"
      function toggle(): void { if (box.hidden) return; box.dashboard = false; box.cliphistOpen = !box.cliphistOpen; box.appLauncher = false }
      function show(): void { if (box.hidden) return; box.dashboard = false; box.cliphistOpen = true }
      function hide(): void { box.cliphistOpen = false }
  }

  // merged control center + mini dashboard
  IpcHandler {
      target: "dashboard"
      function toggle(): void { if (box.hidden) return; box.dashboard = !box.dashboard; box.cliphistOpen = false; box.appLauncher = false }
      function show(): void { if (box.hidden) return; box.dashboard = true; box.cliphistOpen = false; box.appLauncher = false }
      function hide(): void { box.dashboard = false }
  }

  // deprecated aliases so existing Hyprland keybinds keep working; they
  // forward to the merged dashboard (see README for replacement bindings)
  IpcHandler {
      target: "controlCenter"
      function toggle(): void { if (box.hidden) return; box.dashboard = !box.dashboard; box.cliphistOpen = false; box.appLauncher = false }
      function show(): void { if (box.hidden) return; box.dashboard = true; box.cliphistOpen = false; box.appLauncher = false }
      function hide(): void { box.dashboard = false }
  }

  IpcHandler {
      target: "miniDashboard"
      function toggle(): void { if (box.hidden) return; box.dashboard = !box.dashboard; box.cliphistOpen = false; box.appLauncher = false }
      function show(): void { if (box.hidden) return; box.dashboard = true; box.cliphistOpen = false; box.appLauncher = false }
      function hide(): void { box.dashboard = false }
  }

  IpcHandler {
    target: "appLauncher"
    function toggle(): void { if (box.hidden) return; box.dashboard = false; box.cliphistOpen = false; box.appLauncher = !box.appLauncher }
    function show(): void { if (box.hidden) return; box.dashboard = false; box.cliphistOpen = false; box.appLauncher = true }
    function hide(): void { box.appLauncher = false }
  }

  // call right before an automated brightness change (e.g. hypridle dim /
  // restore) so the sysfs write it causes doesn't pop the OSD
  IpcHandler {
    target: "brightness"
    function quiet(): void { brightnessQuietTimer.restart() }
  }

  property string bg: Theme.bg
  property string fg: Theme.fg
  property string fontFamily: Theme.fontFamily
  property int avatarSize: 48
  property int buttonSize: 20
  property string buttonBg: "#353535"
  property string buttonHoverBg: "#bababa"
  property int buttonHoverSpeed: 120
  property int buttonctlRadius: 6

  property bool notifFullscreenMode: false
  property bool fullscreenActive: ToplevelManager.activeToplevel && ToplevelManager.activeToplevel.fullscreen

  // osd ui
  property int osdInWidth: 120
  property real osdInHeight: 3.7
  property int osdBarRadius: 2
  property int osdSpeed: 60 // how fast bar fill/unfill
  property int osdWidth: 220
  property int osdHeight: 40

  readonly property int notifMaxHeight: 97

  PanelWindow {

    WlrLayershell.layer: WlrLayershell.Top
    WlrLayershell.keyboardFocus: (box.cliphistOpen || box.appLauncher || box.dashboard) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    // tall enough for the popups (calendar / weather) that hang below the
    // pill, and grows with the pill when a full dashboard (media player +
    // notification stack) pushes it past that; otherwise the compositor
    // clips the bottom of the box
    implicitHeight: Math.max(482, Math.ceil(box.height) + 8)

    anchors {
      top: true
      left: true
      right: true
    }

    margins {
      top: Config.pillTopMargin
    }

    // fixed gap of the active window for the top bar
    exclusiveZone: Config.pillBottomMargin
    color: "transparent"

    // Mask input to only the capsule
    mask: Region {
      Region {
        intersection: Intersection.Combine
        x: Math.floor(box.x); y: Math.floor(box.y)
        width: Math.ceil(box.width); height: Math.ceil(box.height)
      }
      Region {
        intersection: Intersection.Combine
        x: Math.floor(calendarPopup.x); y: Math.floor(calendarPopup.y)
        width: calendarPopup.shown ? Math.ceil(calendarPopup.width) : 0
        height: calendarPopup.shown ? Math.ceil(calendarPopup.height) : 0
      }
      Region {
          intersection: Intersection.Combine
          x: weatherPopupLoader.item ? Math.floor(weatherPopupLoader.item.x) : 0
          y: weatherPopupLoader.item ? Math.floor(weatherPopupLoader.item.y) : 0
          width: weatherPopupLoader.item && weatherPopupLoader.item.shown ? Math.ceil(weatherPopupLoader.item.width) : 0
          height: weatherPopupLoader.item && weatherPopupLoader.item.shown ? Math.ceil(weatherPopupLoader.item.height) : 0
      }
    }

    // main dynamic pill bar
    Rectangle {
      id: box
      anchors.top: parent.top
      anchors.horizontalCenter: parent.horizontalCenter
      clip: true

      // fullscreen hide/show, choreographed like the Dynamic Island: the
      // contents fade first, the pill morphs into a compact capsule, then the
      // capsule sinks up into the top edge. Coming back runs in reverse with a
      // spring: capsule drops in, unfurls with a slight overshoot, contents
      // fade in last. Three scalars drive it so each stage keeps its own
      // timing independent of the regular width/height Behaviors.
      readonly property bool hidden: fullscreenActive || notifFullscreenMode

      // the pill always leaves as a plain bar: drop any open panel so the
      // morph starts from a capsule, the panel isn't left open (and stealing
      // exclusive keyboard focus) behind the fullscreen window, and the pill
      // comes back as a bar rather than straight into the panel. The IPC
      // handlers also ignore open requests while hidden.
      onHiddenChanged: {
        if (hidden) {
          dashboard = false
          cliphistOpen = false
          appLauncher = false
        }
      }

      // 0 = full bar width, 1 = compact capsule
      property real collapse: hidden ? 1 : 0
      Behavior on collapse {
        SequentialAnimation {
          PauseAnimation { duration: box.hidden ? 0 : 110 }
          NumberAnimation {
            duration: box.hidden ? 320 : 460
            easing.type: box.hidden ? Easing.InOutQuart : Easing.OutBack
            easing.overshoot: 1.15
          }
        }
      }

      // 1 = resting on screen, 0 = swallowed by the top edge
      property real reveal: hidden ? 0 : 1
      Behavior on reveal {
        SequentialAnimation {
          PauseAnimation { duration: box.hidden ? 190 : 0 }
          NumberAnimation {
            duration: box.hidden ? 230 : 380
            easing.type: box.hidden ? Easing.InCubic : Easing.OutBack
            easing.overshoot: 1.0
          }
        }
      }

      // 1 = bar modules visible, 0 = faded (see barContent.opacity)
      property real contentReveal: hidden ? 0 : 1
      Behavior on contentReveal {
        SequentialAnimation {
          PauseAnimation { duration: box.hidden ? 0 : 300 }
          NumberAnimation { duration: box.hidden ? 90 : 220; easing.type: Easing.OutCubic }
        }
      }

      // compact capsule the bar shrinks to before it leaves (island proportions)
      readonly property real collapsedWidth: barHeight * 3.2

      width: implicitWidth * (1 - collapse) + collapsedWidth * collapse
      opacity: Math.min(1, reveal)
      visible: opacity > 0
      scale: 0.7 + 0.3 * reveal
      transformOrigin: Item.Top
      anchors.topMargin: -(1 - reveal) * (height * 0.5 + Config.pillTopMargin)

      property bool appLauncher: false
      property bool hovered: false
      property bool dashboard: false
      property bool cliphistOpen: false

      property var battery: UPower.displayDevice
      // "charging" means on AC power. UPower reports state FullyCharged once
      // the battery tops up while still plugged in, so gating on the raw state
      // would drop the bolt at 100%. onBattery=false covers both active
      // charging and full-but-plugged-in.
      property bool charging: !UPower.onBattery

      readonly property string batteryIconColor: box.charging || box.batteryLevel > 30 ? "#4bd25c"
         : box.batteryLevel <= 15 ? "#e22323"
         : "#eecc47"

      readonly property int batteryLevel: Math.round(battery.percentage * 100)

      // get battery icon according percentage (nf-md-battery_* set — the level
      // is drawn inside the battery; charging variants include the bolt)
      readonly property string batteryIcon: {
        const idx = Math.min(Math.floor(box.batteryLevel / 10), 9)
        // battery_10..battery_90, battery(100)
        const icons = [0xf007a, 0xf007b, 0xf007c, 0xf007d, 0xf007e, 0xf007f, 0xf0080, 0xf0081, 0xf0082, 0xf0079]
        // charging_10..charging_90, charging_100
        const chargingIcons = [0xf089c, 0xf0086, 0xf0087, 0xf0088, 0xf089d, 0xf0089, 0xf089e, 0xf008a, 0xf008b, 0xf0085]
        return String.fromCodePoint(box.charging ? chargingIcons[idx] : icons[idx])
      }

      onChargingChanged: {
        if (!box.dashboard && box.ready) box.activeOsd = "battery"
        osdHideTimer.interval = Config.osdDuration
        osdHideTimer.restart()
        console.log("charging:", box.charging, "level:", box.batteryLevel)
      }

      property string accent: Theme.accent

      // control center UI
      property real ccButtonBorderWidth: 1
      property string ccButtonBorderColor: "#202020"
      property int ccButtonWidth: 112
      property int ccButtonHeight: 35
      property int ccButtonRadius: 10
      property string ccButtonBgOff: "#151515"
      property string ccButtonFgOff: "#a4a4a4"
      property int sliderHeight: 4
      property int sliderRadius: 4
      property string sliderColor: "#c9c9c9"
      // invisible extra clickable area above/below the thin slider bars
      // (proportional to the bar height, so it scales with sliderHeight)
      property int sliderHitSlop: sliderHeight * 2
      property int mprisControlsIconSize: 20

      property string activeOsd: "" // volume, brightness, timer, battery

      Process { id: brightnessSetProc; running: false }

      Timer {
        id: osdHideTimer
        onTriggered: box.activeOsd = ""
      }
      Timer { id: brightnessThrottle; interval: 80; repeat: false }
      // while running, brightness changes update the value but skip the OSD
      // (covers inotify -> 50ms refresh -> brightnessctl get round-trip)
      Timer { id: brightnessQuietTimer; interval: 1000; repeat: false }

      // suppress the volume/brightness/battery OSDs that otherwise flash once
      // right after launch, when the modules do their initial reads
      property bool ready: false
      Timer {
        interval: 2000
        running: true
        onTriggered: box.ready = true
      }

      onImplicitHeightChanged: {
          heightAnim.stop()
          heightAnim.to = implicitHeight
          heightAnim.duration = 550
          heightAnim.start()
      }

      // width of the bar row: three zones with the clock on the true geometric
      // centre of the pill (2 * max(left, right) makes the dead space balance)
      readonly property real barContentWidth:
          2 * Math.max(leftGroup.implicitWidth, rightGroup.implicitWidth)
        + centerGroup.implicitWidth
        + 2 * Config.zoneGap * Config.paddingScale

      readonly property real barHeight:
          (Math.max(leftGroup.implicitHeight, centerGroup.implicitHeight, rightGroup.implicitHeight) * Config.pillScale) + 10

      // adjust box shape conditionally
      implicitWidth: box.activeOsd === "battery" ? osdWidth
                     : box.activeOsd === "timer" ? osdWidth
                     : (notificationModule.active && !notifFullscreenMode) ? 305
                     : dashboard ? 430
                     : activeOsd === "volume" ? osdWidth
                     : box.activeOsd === "brightness" ? osdWidth
                     : appLauncher ? 400
                     : cliphistOpen ? 460
                     : barContentWidth
                       + 2 * Config.pillSidePadding * Config.paddingScale
                       + (12 * Config.paddingScale) + (hovered ? 68 : 56) * Config.paddingScale

      // while hidden the pill always leaves as a plain bar, even if a panel
      // was open, so the collapse morph starts from a capsule
      implicitHeight: hidden ? barHeight
                  : activeOsd === "battery" ? osdHeight
                  : activeOsd === "timer" ? osdHeight
                  : (notificationModule.active && !notifFullscreenMode) ? 52
                  : dashboard ? (dashboardColumn.implicitHeight + 49)
                  : activeOsd === "volume" ? osdHeight
                  : activeOsd === "brightness" ? osdHeight
                  : cliphistOpen ? 270
                  : appLauncher ? 400
                  : barHeight

      radius: hidden ? 20 * Config.pillScale
        : notificationModule.active ? 99
        : cliphistOpen ? 28
        : dashboard && mprisModule.hasPlayer ? 23
        : dashboard && (notificationModule.notifications.length > 0) ? 25
        : appLauncher ? 30
        : dashboard ? 20
        : 20 * Config.pillScale

      Behavior on radius {
          NumberAnimation { duration: 225; easing.type: Easing.OutExpo }
      }
      color: dashboard && mprisModule.hasPlayer ? "#1a1a1a" : bg

      onDashboardChanged: {
        if (dashboard) {
          dashboardPanel.forceActiveFocus()
        } else {
          calendarPopup.shown = false
          if (weatherPopupLoader.item) weatherPopupLoader.item.shown = false
        }
      }

      Behavior on implicitWidth { NumberAnimation { duration: 225; easing.type: Easing.OutExpo } }
      NumberAnimation { id: heightAnim; target: box; property: "height"; easing.type: Easing.OutExpo }

      // hovering a toast holds it on screen
      Binding {
        target: notificationModule
        property: "pillHovered"
        value: box.hovered && notificationModule.active && !notifFullscreenMode
      }

      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

        onEntered: box.hovered = true
        onExited: box.hovered = false

        onClicked: (mouse) => {

          // clicking a toast opens the app that sent it, middle/right
          // click just puts it away (it stays in the dashboard list)
          if (notificationModule.active && !notifFullscreenMode && box.activeOsd === "") {
            if (mouse.button === Qt.LeftButton)
              notificationModule.activate(notificationModule.current)
            else
              notificationModule.hideToast()
            return
          }

          // dashboard closes on a left click on empty pill space
          if (box.dashboard) {
            if (mouse.button === Qt.LeftButton)
                box.dashboard = false
            return
          }

          // cliphist closes on middle click
          if (box.cliphistOpen) {
            if (mouse.button === Qt.MiddleButton) {
              box.cliphistOpen = false
            }
            return
          }

          if (mouse.button === Qt.LeftButton) {
            console.log("Left click detected, opening dashboard")
            box.dashboard = !box.dashboard
            box.appLauncher = false
          }

          if (mouse.button === Qt.MiddleButton) {
            console.log("Middle click detected, opening cliphist")
            box.appLauncher = false
            box.cliphistOpen = !box.cliphistOpen
          }

          // right click is intentionally unbound (reserved for a future action)
        }
      }

      Brightness {
          id: brightnessModule
          visible: false
          onBrightnessUpdated: {
              if (brightnessQuietTimer.running) return
              if (!box.dashboard && box.ready) box.activeOsd = "brightness"
              osdHideTimer.interval = Config.osdDuration
              osdHideTimer.restart()
          }
      }

      // modules in bar: three positioned groups so the clock sits on the
      // geometric centre of the pill
      Item {
        id: barContent
        anchors.fill: parent
        anchors.leftMargin: Config.pillSidePadding * Config.paddingScale
        anchors.rightMargin: Config.pillSidePadding * Config.paddingScale
        opacity: !box.cliphistOpen
                 && !notificationModule.active
                 && !box.dashboard
                 && box.activeOsd === ""
                 && !box.appLauncher ? box.contentReveal : 0
        visible: opacity > 0

        // the fullscreen fade is paced by contentReveal itself; only smooth
        // the regular panel/osd hand-offs
        Behavior on opacity { enabled: box.contentReveal === 1; NumberAnimation { duration: 100 } }

        RowLayout {
          id: leftGroup
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          spacing: 13 * Config.paddingScale

          Workspaces {}
        }

        Item {
          id: centerGroup
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.verticalCenter: parent.verticalCenter
          implicitWidth: clockItem.width
          implicitHeight: clockItem.implicitHeight

          Clock { id: clockItem }
        }

        RowLayout {
          id: rightGroup
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          spacing: 13 * Config.paddingScale

          Fcitx5 {}
          Cpu {}
          Ram {}
          NetUp {}
          NetDown {}
          Network {}
          Volume {
            id: volumeModule
            onVolumeChanged: {
              if (!box.dashboard && box.ready) box.activeOsd = "volume"
              osdHideTimer.interval = Config.osdDuration
              osdHideTimer.restart()
              }
          }
          BatteryRate {}
          BatteryEnergy {}
          Battery {}
        }
      }

      // volume
      OsdBar {
          active: box.activeOsd === "volume"
          icon: volumeModule.icon
          iconColor: volumeModule.muted ? volumeModule.mutedFg : Theme.fg
          percent: volumeModule.vol / 100
          muted: volumeModule.muted
          barWidth: volumeModule.mutedFg ? 90 : 110
          valueText: volumeModule.muted ? "muted" : volumeModule.vol + "%"
      }

      // brightness
      OsdBar {
          active: box.activeOsd === "brightness"
          icon: brightnessModule.icon
          percent: brightnessModule.percent
          valueText: Math.round(brightnessModule.percent * 100) + "%"
          barWidth: 100
      }

      // battery
      OsdBar {
        active: box.activeOsd === "battery"
        icon: box.batteryIcon
        iconColor: box.batteryIconColor
        valueText: box.charging ? "Charging" : "Charging stopped"
        barWidth: 0
        spacing: 5 // gap between battery icon and text
      }

      // timer end
      OsdBar {
        active: box.activeOsd === "timer"
        icon: String.fromCodePoint(0xf1ad1)
        iconColor: "#5892f3"
        valueText: "Timer finished"
        barWidth: 0
        spacing: 5
      }

      // notification
      NotificationPopup {
        active: notificationModule.active
                && !notifFullscreenMode
                && box.activeOsd === ""
        notif: notificationModule.current
      }

      // cliphist opens on middle click
      Item {
        anchors.centerIn: parent
        width: box.implicitWidth - 26
        height: box.cliphistOpen ? box.implicitHeight - 26 : 0
        opacity: box.cliphistOpen
                 && !notificationModule.active
                 && box.activeOsd === ""
                 && !box.dashboard ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
          SequentialAnimation {
            PauseAnimation { duration: box.cliphistOpen ? 15 : 0 }
            NumberAnimation { duration: 150; easing.type: Easing.OutExpo }
          }
        }

        Cliphist {
          id: cliphistPanel
          shown: box.cliphistOpen
          anchors.fill: parent
          onCloseRequested: box.cliphistOpen = false
        }
      }

      // app launcher opens through IPC
      Item {
          anchors.centerIn: parent
          width: box.implicitWidth - 28
          height: box.appLauncher ? 372 : 0
          opacity: box.appLauncher
                   && !notificationModule.active
                   && box.activeOsd === ""
                   && !box.dashboard
                   && !box.cliphistOpen ? 1 : 0
          visible: opacity > 0

          Behavior on opacity {
              SequentialAnimation {
                  PauseAnimation { duration: box.appLauncher ? 15 : 0 }
                  NumberAnimation { duration: 150; easing.type: Easing.OutExpo }
              }
          }

          Loader {
              anchors.fill: parent
              active: box.appLauncher
              asynchronous: true

              sourceComponent: AppLauncher {
                  shown: box.appLauncher
                  onCloseRequested: box.appLauncher = false
              }
          }
      }

      // merged dashboard (control center + mini dashboard) opens on left click
      Item {
        id: dashboardPanel
        anchors.centerIn: parent
        width: box.implicitWidth - 24
        opacity: box.dashboard && box.activeOsd === "" && !notificationModule.active ? 1 : 0
        visible: opacity > 0
        height: box.dashboard && box.activeOsd === "" ? box.implicitHeight - 25 : 0

        Keys.onEscapePressed: box.dashboard = false

        Behavior on opacity {
          SequentialAnimation {
            PauseAnimation { duration: box.dashboard ? 15 : 0 }
            NumberAnimation { duration: 150; easing.type: Easing.OutExpo }
          }
        }

        ColumnLayout {
          id: dashboardColumn
          anchors.fill: parent
          anchors.margins: 12
          spacing: 6

          // ---- profile row: avatar, user@host, uptime, battery ----
          RowLayout {
            Layout.fillWidth: true
            spacing: 10

            // username
            Process {
              id: whoamiProc
              command: ["sh", "-c", 'whoami']
              running: true
              stdout: StdioCollector {
                onStreamFinished: { whoamiText.text = this.text.trim(); whoamiProc.running = false }
              }
            }

            // hostname
            Process {
              id: hostnameProc
              command: ["sh", "-c", "cat /etc/hostname"]
              running: true
              stdout: StdioCollector {
                onStreamFinished: { hostnameText.text = "(" + this.text.trim() + ")"; hostnameProc.running = false }
              }
            }

            // uptime
            Process {
              id: uptimeProc
              command: ["sh", "-c", 'uptime -p']
              running: true
              stdout: StdioCollector {
                onStreamFinished: uptimeText.text = this.text
              }
            }

            // uptime refresh every 60 sec while the dashboard is open
            Timer {
              interval: 60000
              running: box.dashboard
              repeat: true
              triggeredOnStart: true
              onTriggered: {
                uptimeProc.running = false
                uptimeProc.running = true
              }
            }

            // profile picture (display picture)
            ClippingRectangle {
              Layout.preferredWidth: avatarSize
              Layout.preferredHeight: avatarSize
              radius: avatarSize / 2
              color: "transparent"

              Image {
                id: avatarImg
                anchors.fill: parent
                source: Config.displayPicture !== "" ? "file://" + Config.displayPicture : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: false
                sourceSize: Qt.size(avatarSize, avatarSize)
              }

              // placeholder when the picture is unset or missing
              Rectangle {
                anchors.fill: parent
                color: "#2a2a2a"
                visible: avatarImg.status !== Image.Ready

                Text {
                  anchors.centerIn: parent
                  text: String.fromCodePoint(0xf007)
                  color: "#8a8a8a"
                  font { family: Theme.nerdFontFamily; pixelSize: avatarSize * 0.45 }
                }
              }
            }

            // username + uptime stacked
            ColumnLayout {
              spacing: 2
              Layout.alignment: Qt.AlignVCenter

              RowLayout {
                Text {
                  id: whoamiText
                  color: Theme.fg
                  Layout.leftMargin: 10
                  font { family: Theme.fontFamily; pixelSize: 13; weight: 600 }
                }

                Text {
                  id: hostnameText
                  color: "#848484"
                  Layout.topMargin: 2
                  font { family: Theme.fontFamily; pixelSize: 9; weight: 300 }
                }
              }

              Text {
                id: uptimeText
                color: Theme.fg
                opacity: 0.6
                Layout.leftMargin: 10
                font { family: Theme.fontFamily; pixelSize: 8; weight: 400 }
              }
            }

            Item { Layout.fillWidth: true }

            // battery status
            Battery {
              fontSize: 13
              Layout.alignment: Qt.AlignVCenter
            }
          }

          // ---- system row: ip + daily bandwidth ----
          RowLayout {
            Layout.fillWidth: true

            IpStatus { Layout.alignment: Qt.AlignVCenter }
            Item { Layout.fillWidth: true }
            Bandwidth { Layout.alignment: Qt.AlignVCenter }
          }

          // ---- media player ----
          MediaPlayer {
            Layout.fillWidth: true
            Layout.preferredHeight: mprisModule.hasPlayer ? 118 : 0
            margin: 12
            artistFontSize: 10
            artistFontWeight: 300
            artistFontColor: "#7b7b7b"
            color: "#151515"
            radius: mprisModule.hasPlayer ? 16 : 25
            border.width: 1
          }

          // ---- quick controls: wifi / dnd / bluetooth ----
          CcButtons {
            Layout.fillWidth: true
            buttonBorderColor: box.ccButtonBorderColor
            buttonBorderWidth: box.ccButtonBorderWidth
            buttonWidth: box.ccButtonWidth
            buttonHeight: box.ccButtonHeight
            buttonRadius: box.ccButtonRadius
            buttonBgOff: box.dashboard && !mprisModule.hasPlayer ? "#222222" : box.ccButtonBgOff
            buttonFgOff: box.dashboard && !mprisModule.hasPlayer ? "#999999" : box.ccButtonFgOff
            dashboardOpen: box.dashboard
            notificationPopup: notificationModule.active
          }

          // ---- volume + brightness sliders ----
          Column {
            id: sliderColumn
            Layout.fillWidth: true
            spacing: 5

            // volume
            RowLayout {
              width: parent.width
              spacing: 14

              Text {
                text: volumeModule.icon
                color: volumeModule.muted ? "#fd2222" : Theme.fg
                font.family: Theme.nerdFontFamily
                font.pixelSize: 13
                anchors.leftMargin: 10
              }

              Rectangle {
                Layout.fillWidth: true
                height: box.sliderHeight
                radius: box.sliderRadius
                color: "#3a3a3a"

                Rectangle {
                  // animate the *fraction*, not the width: the fill is a pure
                  // function of the current track width, so it can never lag
                  // behind the track with a stale width when the dashboard
                  // opens/closes (that briefly made the bar look over-long,
                  // e.g. volume ~70% while the number said 60%)
                  property real fillFraction: volumeModule.vol / 100
                  width: parent.width * fillFraction
                  height: parent.height
                  radius: box.sliderRadius
                  color: box.sliderColor
                  Behavior on fillFraction { NumberAnimation { duration: 60 } }
                }

                MouseArea {
                  anchors.fill: parent
                  // negative margins extend the clickable area beyond the thin bar
                  anchors.topMargin: -box.sliderHitSlop
                  anchors.bottomMargin: -box.sliderHitSlop
                  onClicked: (mouse) => {
                    volumeModule.sink.audio.volume = Math.max(0, Math.min(1, mouse.x / width))
                  }
                  onPositionChanged: (mouse) => {
                    if (pressed)
                      volumeModule.sink.audio.volume = Math.max(0, Math.min(1, mouse.x / width))
                  }
                }
              }

              Text {
                text: volumeModule.muted ? "muted" : volumeModule.vol + "%"
                color: Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: 10
                Layout.minimumWidth: 35
              }
            }

            // brightness
            RowLayout {
              width: parent.width
              spacing: 14

              Text {
                text: brightnessModule.icon
                color: Theme.fg
                font.family: Theme.nerdFontFamily
                font.pixelSize: 13
              }

              Rectangle {
                Layout.fillWidth: true
                height: box.sliderHeight
                radius: box.sliderRadius
                color: "#3a3a3a"

                Rectangle {
                  // animate the *fraction*, not the width (see volume slider
                  // above): the fill tracks the track width exactly, so it can
                  // never overshoot past 100% when the dashboard opens/closes
                  property real fillFraction: brightnessModule.percent
                  width: parent.width * fillFraction
                  height: parent.height
                  radius: box.sliderRadius
                  color: box.sliderColor
                  Behavior on fillFraction { NumberAnimation { duration: 60 } }
                }

                MouseArea {
                  anchors.fill: parent
                  // negative margins extend the clickable area beyond the thin bar
                  anchors.topMargin: -box.sliderHitSlop
                  anchors.bottomMargin: -box.sliderHitSlop
                  onClicked: (mouse) => {
                    let pct = Math.round(Math.max(0, Math.min(1, mouse.x / width)) * 100)
                    brightnessSetProc.command = ["brightnessctl", "set", pct + "%"]
                    brightnessSetProc.running = false
                    brightnessSetProc.running = true
                  }
                  onPositionChanged: (mouse) => {
                    if (pressed && !brightnessThrottle.running) {
                      let pct = Math.round(Math.max(0, Math.min(1, mouse.x / width)) * 100)
                      brightnessSetProc.command = ["brightnessctl", "set", pct + "%"]
                      brightnessSetProc.running = false
                      brightnessSetProc.running = true
                      brightnessThrottle.start()
                    }
                  }
                }
              }

              Text {
                text: Math.round(brightnessModule.percent * 100) + "%"
                color: Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: 10
                Layout.minimumWidth: 35
              }
            }
          }

          // ---- notification stack (header + list) ----
          Rectangle {
            id: headerBar
            Layout.fillWidth: true
            Layout.preferredHeight: 35
            visible: notificationModule.notifications.length > 0 && box.dashboard
            topLeftRadius: 13
            topRightRadius: 13
            bottomLeftRadius: 0
            bottomRightRadius: 0
            color: "#2f2f2f"
            z: 0

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 16
              anchors.rightMargin: 10

              Text {
                text: "Notifications (" + notificationModule.notifications.length + ")"
                color: "#dddddd"
                font { family: Theme.fontFamily; pixelSize: 9; weight: 400 }
                Layout.fillWidth: true
                verticalAlignment: Text.AlignVCenter
              }

              Rectangle {
                width: 60
                height: 16
                radius: 10
                color: clearAllHover.containsMouse ? "#1d1d1d" : "#242424"
                Behavior on color { ColorAnimation { duration: 100 } }

                Text {
                  text: "Clear all"
                  color: "#dedede"
                  font { family: Theme.fontFamily; pixelSize: 8; weight: 300 }
                  anchors.centerIn: parent
                }

                MouseArea {
                  id: clearAllHover
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: notificationModule.clearAll()
                }
              }
            }
          }

          // notifications list stack
          Rectangle {
            id: notifBox
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(notifList.contentHeight + 7, notifMaxHeight)
            topLeftRadius: 0
            topRightRadius: 0
            bottomLeftRadius: 13
            bottomRightRadius: 13
            color: "#161616"
            visible: notificationModule.notifications.length > 0 && box.dashboard
            clip: true
            border.width: 1
            border.color: "#2f2f2f"
            z: 1

            Behavior on height { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

            ListView {
              id: notifList
              anchors.top: parent.top
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.topMargin: 5
              anchors.leftMargin: 5
              anchors.rightMargin: 5
              // stay inside the box's padding so the last row isn't clipped
              height: Math.min(contentHeight, parent.height - anchors.topMargin - 2)
              spacing: 6
              model: notificationModule.notificationsReversed
              clip: true
              interactive: contentHeight > height
              flickDeceleration: 3000
              maximumFlickVelocity: 2500
              boundsBehavior: Flickable.StopAtBounds

              // cache delegates instead of recreating on scroll
              cacheBuffer: 200
              reuseItems: true

              ScrollBar.vertical: ScrollBar {
                id: notifScrollBar
                policy: ScrollBar.AlwaysOff
                visible: notifList.contentHeight > notifList.height
                width: 10
                anchors.rightMargin: 10
                z: 20
                contentItem: Rectangle {
                  implicitWidth: 8
                  radius: 10
                  color: notifScrollBar.pressed ? "#888"
                       : scrollHover.hovered ? "#6f6f6f"
                       : "#3a3a3a"
                  Behavior on color { ColorAnimation { duration: 100 } }
                  HoverHandler { id: scrollHover }
                }
              }

              // add/append notifications in the stack
              delegate: Item {
                id: notifDelegate
                // the action Repeater below shadows modelData
                readonly property var entry: modelData
                width: ListView.view.width
                height: contentColumn.implicitHeight + 7

                // click the entry to open its app; declared first so the
                // close button stays on top of it
                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    box.dashboard = false
                    notificationModule.activate(modelData._id)
                  }
                }

                // glyph (nerd font) bell icon
                Text {
                  id: bellIcon
                  text: String.fromCodePoint(0xf0f3)
                  color: Theme.fg
                  font { family: Theme.nerdFontFamily; pixelSize: 16 }
                  visible: notifIcon.status !== Image.Ready
                  anchors.left: parent.left
                  anchors.top: parent.top
                  anchors.topMargin: 10
                  anchors.leftMargin: 16
                }

                // custom appicon
                Image {
                  id: notifIcon
                  width: 22
                  height: 22
                  fillMode: Image.PreserveAspectFit
                  // image://icon must load on the GUI thread (QIcon isn't thread-safe)
                  asynchronous: !String(source).startsWith("image://icon/")
                  source: {
                    if (modelData.image) return modelData.image
                    if (modelData.appIcon) {
                      return modelData.appIcon.startsWith("/")
                        ? "file://" + modelData.appIcon
                        : "image://icon/" + modelData.appIcon
                    }
                    return ""
                  }
                  sourceSize: Qt.size(22, 22)
                  visible: status === Image.Ready
                  anchors.top: parent.top
                  anchors.left: parent.left
                  anchors.topMargin: 10
                  anchors.leftMargin: 15
                }

                ColumnLayout {
                  id: contentColumn
                  anchors.fill: parent
                  anchors.leftMargin: 50
                  anchors.rightMargin: 3
                  anchors.bottomMargin: 20
                  spacing: 1

                  Item {
                    Layout.fillHeight: true
                    Layout.topMargin: 8
                    visible: !bodyText.visible
                  }

                  // heading / summary
                  RowLayout {
                    Layout.fillWidth: true

                    Text {
                      text: modelData.summary
                      color: Theme.fg
                      font { family: Theme.fontFamily; pixelSize: 11; weight: 600 }
                      elide: Text.ElideRight
                      Layout.fillWidth: true
                    }

                    Text {
                      text: modelData.receivedTime ? Qt.formatTime(modelData.receivedTime, "hh:mm") : ""
                      color: "#858585"
                      font { family: Theme.fontFamily; pixelSize: 8 }
                      Layout.bottomMargin: 5
                    }

                    // close button
                    Rectangle {
                      Layout.preferredWidth: 22
                      Layout.preferredHeight: 22
                      radius: 99
                      color: dismissHover.containsMouse ? "#333333" : "transparent"
                      Behavior on color { ColorAnimation { duration: 100 } }

                      Text {
                        text: ""
                        color: dismissHover.containsMouse ? "#bebebe" : "#404040"
                        anchors.centerIn: parent
                        font.pixelSize: 11
                        Behavior on color { ColorAnimation { duration: 150 } }
                      }

                      MouseArea {
                        id: dismissHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: notificationModule.dismiss(modelData._id)
                      }
                    }
                  }

                  // description / body
                  Text {
                    id: bodyText
                    text: modelData.body
                    color: "#9f9f9f"
                    font { family: Theme.fontFamily; pixelSize: 9; weight: 300 }
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                    Layout.bottomMargin: 2
                    visible: text !== ""
                  }

                  // app-provided actions ("Mark as read", "Reply", ...)
                  Flow {
                    Layout.fillWidth: true
                    Layout.topMargin: 3
                    Layout.bottomMargin: 2
                    spacing: 5
                    visible: actionRepeater.count > 0

                    Repeater {
                      id: actionRepeater
                      model: notificationModule.buttonActions(notifDelegate.entry)

                      Rectangle {
                        required property var modelData
                        implicitWidth: actionLabel.implicitWidth + 16
                        implicitHeight: 18
                        radius: 99
                        color: actionHover.containsMouse ? "#3a3a3a" : "#2a2a2a"
                        Behavior on color { ColorAnimation { duration: 100 } }

                        Text {
                          id: actionLabel
                          anchors.centerIn: parent
                          text: modelData.text
                          color: Theme.fg
                          font { family: Theme.fontFamily; pixelSize: 8; weight: 600 }
                        }

                        MouseArea {
                          id: actionHover
                          anchors.fill: parent
                          hoverEnabled: true
                          cursorShape: Qt.PointingHandCursor
                          onClicked: notificationModule.invokeAction(notifDelegate.entry._id, modelData.identifier)
                        }
                      }
                    }
                  }

                  Item {
                    Layout.fillHeight: true
                    Layout.bottomMargin: 6
                    visible: !bodyText.visible
                  }
                }

                // divider
                Rectangle {
                  anchors.bottom: parent.bottom
                  width: parent.width
                  height: 1
                  color: "#333"
                  visible: index < notificationModule.notifications.length - 1
                }
              }
            }
          }

          // rectangle where poweroff, sleep etc. buttons placed
          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 30
            color: "#212121"
            radius: 8

            RowLayout {
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.leftMargin: 8
              anchors.rightMargin: 8
              spacing: 8

              // lock
              Rectangle {
                width: buttonSize; height: buttonSize
                radius: buttonctlRadius; color: buttonBg
                Layout.alignment: Qt.AlignVCenter
                Text {
                  anchors.centerIn: parent;
                  text: "";
                  color: lockHover.containsMouse ? buttonHoverBg : Theme.fg;
                  font.pixelSize: 8
                  Behavior on color { ColorAnimation { duration: buttonHoverSpeed } }
                }

                MouseArea {
                  id: lockHover
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: { lockProc.running = false; lockProc.running = true }
                  hoverEnabled: true
                }

                Process { id: lockProc; command: ["bash", "-c", Config.screenLockAppCommand]; running: false }
              }

              // sleep
              Rectangle {
                width: buttonSize; height: buttonSize
                radius: buttonctlRadius; color: buttonBg
                Layout.alignment: Qt.AlignVCenter
                Text {
                  anchors.centerIn: parent;
                  text: "󰤄";
                  color: sleepHover.containsMouse ? buttonHoverBg : Theme.fg;
                  font.pixelSize: 9
                  Behavior on color { ColorAnimation { duration: buttonHoverSpeed } }
                }

                MouseArea {
                  id: sleepHover
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: { sleepProc.running = false; sleepProc.running = true }
                  hoverEnabled: true
                }
                Process { id: sleepProc; command: ["bash", "-c", "systemctl suspend"]; running: false }
              }

              Item { Layout.fillWidth: true }

              Datetime { id: datetimeItem; dateFg: "#aaaaaa"; }

              Item { Layout.fillWidth: true }

              WeatherIndicator { id: weatherIndicatorItem }

              Item { Layout.fillWidth: true }

              // reboot
              Rectangle {
                width: buttonSize; height: buttonSize
                radius: buttonctlRadius; color: buttonBg
                Layout.alignment: Qt.AlignVCenter
                Text {
                  anchors.centerIn: parent;
                  text: "";
                  color: rebootHover.containsMouse ? buttonHoverBg : Theme.fg;
                  font.pixelSize: 9;
                  Behavior on color { ColorAnimation { duration: buttonHoverSpeed } }
                }

                MouseArea {
                  id: rebootHover
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: { rebootProc.running = false; rebootProc.running = true }
                  hoverEnabled: true
                }
                Process { id: rebootProc; command: ["bash", "-c", "systemctl reboot"]; running: false }
              }

              // shutdown
              Rectangle {
                width: buttonSize; height: buttonSize
                radius: buttonctlRadius; color: buttonBg
                Layout.alignment: Qt.AlignVCenter
                Text {
                  anchors.centerIn: parent;
                  text: "󰐥";
                  color: shutdownHover.containsMouse ? buttonHoverBg : Theme.fg;
                  font.pixelSize: 12;
                  Behavior on color { ColorAnimation { duration: buttonHoverSpeed } }
                }

                MouseArea {
                  id: shutdownHover
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: { shutdownProc.running = false; shutdownProc.running = true }
                  hoverEnabled: true
                }
                Process { id: shutdownProc; command: ["bash", "-c", "systemctl poweroff"]; running: false }
              }
            }
          }
        }
      }
      SystemClock {
        id: clock
        precision: SystemClock.Seconds
      }
    }

    // calendar popup box
    CalendarBox { id: calendarPopup }

    Loader {
        id: weatherPopupLoader
        active: false
        asynchronous: false

        sourceComponent: WeatherPopup {
            onShownChanged: if (!shown) closeTimer.start()
        }

        onLoaded: item.shown = true
        Timer {
            id: closeTimer
            interval: 250
            onTriggered: weatherPopupLoader.active = false
        }
    }

    // open calendar when click on date in the dashboard
    Connections {
      target: datetimeItem
      function onToggleCalendar() {
        calendarPopup.shown = !calendarPopup.shown
        if (weatherPopupLoader.item) weatherPopupLoader.item.shown = false
      }
    }

    // open weather when click on weather in the dashboard
    Connections {
      target: weatherIndicatorItem
      function onToggleWeather() {
        if (!weatherPopupLoader.active)
          weatherPopupLoader.active = true
        else if (weatherPopupLoader.item)
          weatherPopupLoader.item.shown = !weatherPopupLoader.item.shown
        calendarPopup.shown = false
      }
    }

    Connections {
      target: countdownModule
      function onTimerFinished() {
        if (!box.dashboard) box.activeOsd = "timer"
        osdHideTimer.interval = 2500
        osdHideTimer.restart()
      }
    }
  }

  Mpris { id: mprisModule; visible: false }

  CountdownModule { id: countdownModule; visible: false }

  // system metrics singleton: live config for interval/exclusions, and stop
  // sampling entirely while the pill is hidden (fullscreen / fullscreen notif)
  Binding { target: SysMonitor; property: "interval"; value: Config.sysMonitorInterval }
  Binding { target: SysMonitor; property: "netExcludeInterfaces"; value: Config.netExcludeInterfaces }
  Binding { target: SysMonitor; property: "running"; value: !fullscreenActive && !notifFullscreenMode }

  NotificationServer {
    id: notifServer
    keepOnReload: false
    // without this apps (Discord/Electron) don't send their click action
    actionsSupported: true
    onNotification: notif => {
      notif.tracked = true
      notificationModule.enqueue(notif)
    }
  }

  NotificationModule { id: notificationModule; visible: false }

  FullscreenOsd {
    id: fsNotif
    active: notificationModule.active && notifFullscreenMode
    visible: notifFullscreenMode
    cardWidth: 300
    cardHeight: 52

    property var displayNotif: null

    // wrapper so the whole card content is clickable (cardRow is a Row,
    // so a MouseArea can't anchor-fill it directly)
    Item {
      implicitWidth: fsRow.implicitWidth
      implicitHeight: fsRow.implicitHeight
      width: implicitWidth
      height: implicitHeight

      RowLayout {
        id: fsRow
        anchors.centerIn: parent
        spacing: 12

        Text {
          text: String.fromCodePoint(0xf0f3)
          color: Theme.fg
          font { family: Theme.nerdFontFamily; pixelSize: 14 }
          visible: cardIcon.status !== Image.Ready
        }

        Image {
          id: cardIcon
          width: 23; height: 23
          fillMode: Image.PreserveAspectCrop
          source: {
            if (fsNotif.displayNotif && fsNotif.displayNotif.image) return fsNotif.displayNotif.image
            if (fsNotif.displayNotif && fsNotif.displayNotif.appIcon) {
              return fsNotif.displayNotif.appIcon.startsWith("/")
                ? "file://" + fsNotif.displayNotif.appIcon
                : "image://icon/" + fsNotif.displayNotif.appIcon
            }
            return ""
          }
          sourceSize: Qt.size(23, 23)
          visible: status === Image.Ready
        }

        ColumnLayout {
          spacing: 3

          Text {
            text: fsNotif.displayNotif ? fsNotif.displayNotif.summary : ""
            color: Theme.fg
            font { family: Theme.fontFamily; pixelSize: 10; weight: 700 }
            elide: Text.ElideRight
            Layout.maximumWidth: 200
          }

          Text {
            text: fsNotif.displayNotif ? fsNotif.displayNotif.body : ""
            color: "#9b9b9b"
            font { family: Theme.fontFamily; pixelSize: 9 }
            elide: Text.ElideRight
            visible: text !== ""
            Layout.maximumWidth: 200
          }
        }
      }

      MouseArea {
        id: fsCardArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onClicked: (mouse) => {
          if (mouse.button === Qt.LeftButton)
            notificationModule.activate(notificationModule.current)
          else
            notificationModule.hideToast()
        }
      }

      Binding {
        target: notificationModule
        property: "cardHovered"
        value: fsCardArea.containsMouse && notifFullscreenMode
      }
    }
  }

  Connections {
    target: notificationModule
    function onActiveChanged() {
        if (notificationModule.active) {
            notifFullscreenMode = fullscreenActive
        } else {
            notifFullscreenMode = false
        }
    }
    function onCurrentChanged() {
      if (notificationModule.current) fsNotif.displayNotif = notificationModule.current
    }
  }

}
