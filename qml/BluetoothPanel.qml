import Quickshell
import Quickshell.Wayland
import Quickshell.Bluetooth
import QtQuick
import QtQuick.Layouts

PanelWindow {
  id: btListWindow

  property real anchorX: 0
  property real anchorY: 0

  anchors.top: true
  anchors.left: true
  margins.top: anchorY
  margins.left: anchorX

  // see WifiPanel: exclusive while shown so Hyprland routes the pointer here
  WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

  signal closeRequested()  // Esc: the panel owns keyboard focus while open

  property var adapter: Bluetooth.defaultAdapter
  property bool adapterOn: adapter ? adapter.enabled : false

  exclusionMode: ExclusionMode.Ignore
  width: 300
  height: 360
  color: "transparent"

  // discovery runs only while the scan button is active: it stops on its
  // own after a while, when the panel closes, or when clicked again
  function setDiscovering(on) {
    if (!adapter) return
    adapter.discovering = on
    if (on) discoveryTimeout.restart()
    else discoveryTimeout.stop()
  }

  Timer {
    id: discoveryTimeout
    interval: 20000
    onTriggered: btListWindow.setDiscovering(false)
  }

  onVisibleChanged: if (!visible) setDiscovering(false)
  onAdapterOnChanged: if (!adapterOn) discoveryTimeout.stop()

  function deviceGlyph(icon) {
    if (!icon) return "\uf293"
    if (icon.indexOf("headset") >= 0 || icon.indexOf("headphones") >= 0) return "\uf025"
    if (icon.indexOf("audio") >= 0) return "\uf028"
    if (icon.indexOf("keyboard") >= 0) return "\uf11c"
    if (icon.indexOf("mouse") >= 0) return "\uf245"
    if (icon.indexOf("gaming") >= 0) return "\uf11b"
    if (icon.indexOf("phone") >= 0) return "\uf10b"
    if (icon.indexOf("computer") >= 0) return "\uf108"
    return "\uf293"
  }

  Item {
    anchors.fill: parent
    focus: true
    Keys.onEscapePressed: btListWindow.closeRequested()
  }

  Rectangle {
    anchors.fill: parent
    anchors.topMargin: 40
    anchors.leftMargin: 30  // sit right of the bluetooth button
    color: "#1c1c1c"
    radius: 26

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: 16
      spacing: 13

      PanelHeader {
        title: "Bluetooth"
        active: btListWindow.adapterOn
        scanning: btListWindow.adapter ? btListWindow.adapter.discovering : false
        onScanClicked: btListWindow.setDiscovering(!(btListWindow.adapter && btListWindow.adapter.discovering))
        onToggleClicked: if (btListWindow.adapter) btListWindow.adapter.enabled = !btListWindow.adapter.enabled
      }

      Text {
        visible: !btListWindow.adapter
        text: "No Bluetooth adapter found."
        color: "#949494"
        font { family: Theme.fontFamily; pixelSize: 11 }
        wrapMode: Text.Wrap
        Layout.fillWidth: true
        Layout.leftMargin: 5
      }

      Text {
        visible: btListWindow.adapter && !btListWindow.adapterOn
        text: "Turn on Bluetooth to see devices."
        color: "#949494"
        font { family: Theme.fontFamily; pixelSize: 11 }
        wrapMode: Text.Wrap
        Layout.fillWidth: true
        Layout.leftMargin: 5
      }

      Flickable {
        Layout.fillWidth: true
        Layout.fillHeight: true
        contentHeight: deviceColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
          id: deviceColumn
          width: parent.width
          spacing: 4

          Repeater {
            model: btListWindow.adapterOn ? Bluetooth.devices : null

            delegate: Rectangle {
              id: deviceRow
              required property var modelData
              readonly property bool shown: modelData.paired || modelData.connected || modelData.deviceName.length > 0
              readonly property bool busy: modelData.pairing
                  || modelData.state === BluetoothDeviceState.Connecting
                  || modelData.state === BluetoothDeviceState.Disconnecting
              property bool connectAfterPair: false

              width: deviceColumn.width
              height: shown ? 45 : 0
              visible: shown
              radius: 16
              color: modelData.connected ? "#4173c4" : (deviceMouse.containsMouse ? "#313131" : "#252525")
              border.color: modelData.connected ? "" : "#2f2f2f"
              border.width: modelData.connected ? 0 : 1

              // finish the pair -> connect flow once bluez reports paired
              Connections {
                target: deviceRow.modelData
                function onPairedChanged() {
                  if (deviceRow.connectAfterPair && deviceRow.modelData.paired) {
                    deviceRow.connectAfterPair = false
                    deviceRow.modelData.connect()
                  }
                }
              }

              MouseArea {
                id: deviceMouse
                anchors.fill: parent
                hoverEnabled: true
                enabled: !deviceRow.busy
                onClicked: {
                  const d = deviceRow.modelData
                  if (d.connected) { d.disconnect(); return }
                  if (d.paired) { d.connect(); return }
                  deviceRow.connectAfterPair = true
                  d.pair()
                }
              }

              Row {
                anchors.fill: parent
                anchors.margins: 10
                anchors.leftMargin: 17
                spacing: 20

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: btListWindow.deviceGlyph(deviceRow.modelData.icon)
                  font { family: Theme.nerdFontFamily; pixelSize: 12 }
                  color: "#b4b4b4"
                }

                Column {
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: 2
                  Text {
                    text: deviceRow.modelData.name || deviceRow.modelData.address
                    color: "#ffffff"
                    font { family: Theme.fontFamily; pixelSize: 11; weight: deviceRow.modelData.connected ? 500 : 300 }
                  }
                  Text {
                    text: {
                      const d = deviceRow.modelData
                      if (d.pairing) return "Pairing..."
                      if (d.state === BluetoothDeviceState.Connecting) return "Connecting..."
                      if (d.state === BluetoothDeviceState.Disconnecting) return "Disconnecting..."
                      if (d.connected) return d.batteryAvailable ? "Connected · " + Math.round(d.battery * 100) + "%" : "Connected"
                      if (d.paired) return "Paired"
                      return "Not paired"
                    }
                    color: deviceRow.modelData.connected ? "#c8d7ef" : "#949494"
                    elide: Text.ElideRight
                    font { family: Theme.fontFamily; pixelSize: 9 }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
