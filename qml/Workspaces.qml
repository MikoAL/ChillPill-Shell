import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

RowLayout {
  Layout.fillWidth: false
  spacing: 4 * Config.paddingScale
 
  Repeater {
    model: Config.maxWorkspaces // max workspace buttons/texts to show

    delegate: Rectangle {
      id: wsButton

      required property int index
      // Each button is a column of ~/.config/hypr/cross.lua: workspaces 10*col .. 10*col+9
      property int column: index + 1
      property var ws: Hyprland.workspaces.values.find(w => Math.floor(w.id / 10) === column)
      property bool isActive: Math.floor((Hyprland.focusedWorkspace?.id ?? 0) / 10) === column
      property string activeBg: "#4d5258"
      property string inactiveBg: "#393c41"

      Layout.preferredWidth: 17.5 * Config.pillScale
      Layout.preferredHeight: Layout.preferredWidth
      radius: 8 * Config.pillScale
      color: isActive ? activeBg : (ws ? inactiveBg : "transparent")

      // animate color transition on workspace switch
      Behavior on color { ColorAnimation { duration: 120 } }

      Text {
        anchors.centerIn: parent
        text: wsButton.column
        color: wsButton.isActive ? "#ffffff" : "#dae0ea"
        font {
          family: Theme.fontFamily
          pixelSize: 9 * Config.pillScale
          weight: 300
        }
      }

      // clickable text buttons
      // NOTE: this machine runs a Lua-config Hyprland variant where the
      // dispatcher socket expects hl.dsp.focus({ workspace = N }) — the plain
      // "workspace N" syntax errors out. Verified live on 0.55.2.
      MouseArea {
        anchors.fill: parent
        onClicked: Hyprland.dispatch("hl.dsp.focus({ workspace = " + (wsButton.column * 10) + " })")
        cursorShape: Qt.PointingHandCursor
      }
    }
  }
}
