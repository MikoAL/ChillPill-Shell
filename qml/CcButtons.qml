import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth
import IslandBackend

RowLayout {
  id: root

  property real buttonBorderWidth
  property string buttonBorderColor
  property real buttonWidth
  property real buttonHeight
  property real buttonRadius
  property color buttonBgOff
  property color buttonFgOff

  property bool notificationPopup: false
  property bool dashboardOpen: false
  property bool wifiPanelOpened: false
  property bool btPanelOpened: false
  property bool hasPlayer: false
  property real playerHeight: 0

  Layout.fillWidth: true

  onDashboardOpenChanged: {
    if (!dashboardOpen) { root.wifiPanelOpened = false; root.btPanelOpened = false }
  }

  // wifi
  Rectangle {
    id: wifiBtn
    width: root.buttonWidth
    height: root.buttonHeight
    radius: root.buttonRadius
    visible: root.dashboardOpen
    color: WifiController.enabled ? "#212529" : (wifiHover.hovered ? Qt.lighter(root.buttonBgOff, 1.5) : root.buttonBgOff)
    border.width: buttonBorderWidth
    border.color: buttonBorderColor
    scale: wifiMouse.pressed ? 0.93 : 1.0
    Behavior on color { ColorAnimation { duration: 150 } }
    Behavior on scale { NumberAnimation { duration: 80; easing.type: Easing.OutQuad } }

    RowLayout {
      anchors.centerIn: parent
      spacing: 5
      Text {
        text: "\uf1eb" // wifi glyph
        color: WifiController.enabled ? "#3f7de0" : root.buttonFgOff
        font { family: Theme.nerdFontFamily; pixelSize: 14 }
      }
      Text {
        text: !WifiController.enabled ? "Off"
            : WifiController.currentSsid.length > 0 ? WifiController.currentSsid
            : (WifiController.statusText.length > 0 ? WifiController.statusText : "Not connected")
        color: WifiController.enabled ? "#dedede" : root.buttonFgOff
        font { family: Theme.fontFamily; pixelSize: 12; weight: 400 }
        elide: Text.ElideRight
        Layout.maximumWidth: 90
      }
    }

    HoverHandler { id: wifiHover }
    MouseArea {
      id: wifiMouse
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      cursorShape: Qt.PointingHandCursor
      onClicked: {
        root.btPanelOpened = false
        root.wifiPanelOpened = !root.wifiPanelOpened
      }
    }
  }

  // mapToGlobal is not reactive, so the anchor bindings also read the
  // "opened" flag and layout geometry to be re-evaluated when the panel shows
  WifiPanel {
    id: wifiPanel
    visible: root.wifiPanelOpened
    onCloseRequested: root.wifiPanelOpened = false
    anchorX: {  // sit left of the wifi button
      root.wifiPanelOpened; root.width; wifiBtn.x
      return wifiBtn.mapToGlobal(0, 0).x - wifiPanel.width
    }
    anchorY: 0  // panels hang from the top of the bar, beside the dashboard
  }

  onNotificationPopupChanged: {
    if (root.notificationPopup) { root.wifiPanelOpened = false; root.btPanelOpened = false }
  }

  Item { Layout.fillWidth: true }

  // silent notifications
  Rectangle {
    id: dndBtn
    width: root.buttonWidth
    height: root.buttonHeight
    radius: root.buttonRadius
    visible: root.dashboardOpen
    color: notificationModule.dndEnabled ? "#2e2c28" : (dndHover.hovered ? Qt.lighter(root.buttonBgOff, 1.5) : root.buttonBgOff)
    border.width: buttonBorderWidth
    border.color: buttonBorderColor
    scale: dndMouse.pressed ? 0.93 : 1.0
    Behavior on color { ColorAnimation { duration: 150 } }
    Behavior on scale { NumberAnimation { duration: 80; easing.type: Easing.OutQuad } }

    Text {
      text: String.fromCodePoint(0xf1f6)
      color: notificationModule.dndEnabled ? "#fbf5e8" : root.buttonFgOff
      anchors.centerIn: parent
      font { family: Theme.nerdFontFamily; pixelSize: 14 }
    }
    HoverHandler { id: dndHover }
    MouseArea {
      id: dndMouse
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: notificationModule.dndEnabled = !notificationModule.dndEnabled
    }
  }

  Item { Layout.fillWidth: true }

  // bluetooth
  property var btAdapter: Bluetooth.defaultAdapter
  property bool btEnabled: btAdapter ? btAdapter.enabled : false
  property var btConnected: []

  function refreshBt() {
    btConnected = Bluetooth.devices.values.filter(d => d.connected)
  }

  // watch every device's `connected` so the label reacts to (dis)connects
  Instantiator {
    model: Bluetooth.devices
    delegate: QtObject {
      required property var modelData
      property bool connected: modelData.connected
      onConnectedChanged: root.refreshBt()
      Component.onCompleted: root.refreshBt()
      Component.onDestruction: root.refreshBt()
    }
  }

  Rectangle {
    id: btBtn
    width: root.buttonWidth
    height: root.buttonHeight
    radius: root.buttonRadius
    color: root.btEnabled ? "#212529" : (btHover.hovered ? Qt.lighter(root.buttonBgOff, 1.5) : root.buttonBgOff)
    border.width: buttonBorderWidth
    border.color: buttonBorderColor
    scale: btMouse.pressed ? 0.93 : 1.0
    Behavior on color { ColorAnimation { duration: 150 } }
    Behavior on scale { NumberAnimation { duration: 80; easing.type: Easing.OutQuad } }

    RowLayout {
      anchors.centerIn: parent
      spacing: 5
      Text {
        text: "\uf293" // bluetooth glyph
        color: root.btEnabled ? "#3f7de0" : root.buttonFgOff
        font { family: Theme.nerdFontFamily; pixelSize: 14 }
      }
      Text {
        text: !root.btAdapter ? "No adapter"
            : !root.btEnabled ? "Off"
            : root.btConnected.length === 0 ? "Not connected"
            : root.btConnected.length === 1 ? root.btConnected[0].name
            : root.btConnected[0].name + " +" + (root.btConnected.length - 1)
        color: root.btEnabled ? "#dedede" : root.buttonFgOff
        font { family: Theme.fontFamily; pixelSize: 12; weight: 400 }
        elide: Text.ElideRight
        Layout.maximumWidth: 80
      }
    }

    HoverHandler { id: btHover }
    MouseArea {
      id: btMouse
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      cursorShape: Qt.PointingHandCursor
      onClicked: {
        root.wifiPanelOpened = false
        root.btPanelOpened = !root.btPanelOpened
      }
    }
  }

  BluetoothPanel {
    visible: root.btPanelOpened
    onCloseRequested: root.btPanelOpened = false
    anchorX: {  // sit right of the bluetooth button
      root.btPanelOpened; root.width; btBtn.x
      return btBtn.mapToGlobal(0, 0).x + btBtn.width
    }
    anchorY: 0
  }
}
