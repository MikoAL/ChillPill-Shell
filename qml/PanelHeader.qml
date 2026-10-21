import QtQuick
import QtQuick.Layouts

// header shared by the wifi / bluetooth panels: title (left) | scan (centre) | on-off switch (right)
Item {
  id: header

  property string title: ""
  property bool active: false
  property bool scanning: false
  property bool canScan: active

  signal scanClicked()
  signal toggleClicked()

  Layout.fillWidth: true
  implicitHeight: 24

  Text {
    id: titleText
    text: header.title
    color: "#d2d2d2"
    font { family: Theme.fontFamily; pixelSize: 14; bold: true }
    anchors.left: parent.left
    anchors.leftMargin: 5
    anchors.verticalCenter: parent.verticalCenter
  }

  // scan button (sized to its label so wide fonts never overflow it)
  Rectangle {
    id: scanBtn
    width: scanRow.implicitWidth + 20
    height: 24
    anchors.verticalCenter: parent.verticalCenter
    // centred, but never overlapping a wide title
    x: Math.max((parent.width - width) / 2, titleText.x + titleText.width + 8)
    radius: 12
    opacity: header.canScan ? 1 : 0.4
    color: header.scanning ? (scanMA.containsMouse ? "#34496e" : "#2b3d5c")
                           : (scanMA.containsMouse ? "#313131" : "#252525")
    border.color: header.scanning ? "#3f7de0" : "#2f2f2f"
    border.width: 1
    scale: scanMA.pressed ? 0.93 : 1.0
    Behavior on color { ColorAnimation { duration: 120 } }
    Behavior on scale { NumberAnimation { duration: 80; easing.type: Easing.OutQuad } }

    Row {
      id: scanRow
      anchors.centerIn: parent
      spacing: 5
      Text {
        id: scanIcon
        text: "\uf021" // refresh glyph
        color: header.scanning ? "#8ab4ff" : "#b4b4b4"
        font { family: Theme.nerdFontFamily; pixelSize: 10 }
        anchors.verticalCenter: parent.verticalCenter
        RotationAnimation on rotation {
          running: header.scanning
          from: 0; to: 360
          duration: 1000
          loops: Animation.Infinite
          onRunningChanged: if (!running) scanIcon.rotation = 0
        }
      }
      Text {
        text: "Scan"
        color: header.scanning ? "#8ab4ff" : "#dadada"
        font { family: Theme.fontFamily; pixelSize: 10 }
        anchors.verticalCenter: parent.verticalCenter
      }
    }

    MouseArea {
      id: scanMA
      anchors.fill: parent
      hoverEnabled: true
      enabled: header.canScan
      cursorShape: Qt.PointingHandCursor
      onClicked: header.scanClicked()
    }
  }

  // on / off switch
  Rectangle {
    id: toggle
    width: 38
    height: 22
    radius: 11
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    color: header.active ? (toggleMA.containsMouse ? "#4a88e6" : "#3f7de0")
                         : (toggleMA.containsMouse ? "#3a3a3a" : "#333333")
    scale: toggleMA.pressed ? 0.93 : 1.0
    Behavior on color { ColorAnimation { duration: 150 } }
    Behavior on scale { NumberAnimation { duration: 80; easing.type: Easing.OutQuad } }

    Rectangle {
      width: 16
      height: 16
      radius: 8
      anchors.verticalCenter: parent.verticalCenter
      x: header.active ? parent.width - width - 3 : 3
      color: "#f2f2f2"
      Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
    }

    MouseArea {
      id: toggleMA
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: header.toggleClicked()
    }
  }
}
