import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris

Rectangle {
    id: mediaCard
    Layout.fillWidth: true
    Layout.preferredHeight: mprisModule.hasPlayer ? 118 : 0
    radius: 12
    color: "#212121"
    visible: mprisModule.hasPlayer
    clip: true
    border.color: "#202020"
    border.width: 2

    property int margin: 14

    // artist name adjustments
    property int artistFontSize: 10
    property string artistFontColor: "#656565"
    property int artistFontWeight: 600

    property real mprisProgress: 0
    // animate the fraction, not the width: the fill stays a pure function of
    // the current track width and can never lag behind it (same fix as the
    // dashboard volume/brightness sliders). Short duration keeps it responsive.
    Behavior on mprisProgress { NumberAnimation { duration: 60; easing.type: Easing.Linear } }
    property string mprisTimePlayed: "0:00"
    property string mprisTimeTotal: "0:00"
    // invisible extra clickable area above/below the thin progress bar
    property int barHitSlop: 10

    function formatMprisTime(val) {
        let n = Number(val)
        if (isNaN(n) || n <= 0) return "0:00"
        let m = Math.floor(n / 60)
        let s = Math.floor(n % 60)
        return m + ":" + (s < 10 ? "0" : "") + s
    }

    // interpolate every second
    Timer {
        id: progressPoller
        interval: 250
        running: box.dashboard && mprisModule.hasPlayer
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            mediaCard.mprisProgress = mprisModule.progress
            mediaCard.mprisTimePlayed = mediaCard.formatMprisTime(mprisModule.polledPosition)
            mediaCard.mprisTimeTotal = mediaCard.formatMprisTime(mprisModule.polledLength)
        }
    }

     Column {
        anchors.fill: parent
        anchors.margins: margin
        spacing: 15

        // top row -> art + info + controls
        Row {
            width: parent.width
            height: 48
            spacing: 15

            // album art
            ClippingRectangle {
                width: 47; height: 47
                radius: 7
                color: "transparent"
                anchors.verticalCenter: parent.verticalCenter
                clip: true

                Image {
                    anchors.fill: parent
                    source: mprisModule.artUrl
                    fillMode: Image.PreserveAspectCrop
                    visible: mprisModule.artUrl !== ""
                    sourceSize: Qt.size(80, 80)
                }

                Text {
                    anchors.centerIn: parent
                    visible: mprisModule.artUrl === ""
                    text: "\uf001"
                    font.family: "FiraCode Nerd Font Propo"
                    font.pixelSize: 18
                    color: "#555"
                }
            }

            // track + artist
            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 46 - 90 - 24
                spacing: 4

                Text {
                    width: parent.width
                    text: mprisModule.track !== "" ? mprisModule.track : "Nothing playing"
                    color: "#e8e8e8"
                    font.pixelSize: 12
                    font.bold: true
                    font.family: Theme.fontFamily
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: mprisModule.artist
                    color: artistFontColor
                    font.pixelSize: artistFontSize
                    font.weight: artistFontWeight
                    font.family: Theme.fontFamily
                    elide: Text.ElideRight
                }
            }

            // controls
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 14

                Text {
                    text: "⏮"
                    font.family: "FiraCode Nerd Font Propo"
                    font.pixelSize: 23
                    color: prevHover.containsMouse ? "#ffffff" : "#cfcfcf"
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on color { ColorAnimation { duration: 100 } }
                    MouseArea {
                        id: prevHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { mprisModule.prev() }
                    }
                }

                Text {
                    text: mprisModule.playing ? "󰏤" : "󰐊"
                    font.family: "FiraCode Nerd Font Propo"
                    font.pixelSize: 23
                    color: playHover.containsMouse ? "#ffffff" : "#cdcdcd"
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on color { ColorAnimation { duration: 100 } }
                    MouseArea {
                        id: playHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mprisModule.playPause()
                    }
                }

                Text {
                    text: "⏭"
                    font.family: "FiraCode Nerd Font Propo"
                    font.pixelSize: 23
                    color: nextHover.containsMouse ? "#ffffff" : "#b3b3b3"
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on color { ColorAnimation { duration: 100 } }
                    MouseArea {
                        id: nextHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mprisModule.next()
                    }
                }
            }
        }

        // progress bar + time
        Column {
            width: parent.width
            spacing: 8

            Rectangle {
                width: parent.width
                height: barHover.containsMouse ? 5 : 3
                radius: 8
                color: "#4d4d4d"

                Behavior on height { NumberAnimation { duration: 120; easing.type: Easing.OutExpo } }

                Rectangle {
                    width: parent.width * mediaCard.mprisProgress
                    height: parent.height
                    radius: 5
                    color: barHover.containsMouse ? "#cdcdcd" : fg
                }

                // same click leeway as the volume/brightness sliders
                MouseArea {
                    id: barHover
                    anchors.fill: parent
                    anchors.topMargin: -barHitSlop
                    anchors.bottomMargin: -barHitSlop
                    hoverEnabled: true
                    function seekTo(mouse) {
                        let p = mprisModule.activePlayer
                        let len = mprisModule.polledLength
                        if (!p || len <= 0) return
                        let ratio = Math.max(0, Math.min(1, mouse.x / width))
                        // reflect the seek on the bar immediately instead of
                        // waiting for the next poll
                        mediaCard.mprisProgress = ratio
                        if (p.canSeek && p.positionSupported)
                            p.position = ratio * len
                    }
                    onClicked: (mouse) => barHover.seekTo(mouse)
                    onPositionChanged: (mouse) => { if (pressed) barHover.seekTo(mouse) }
                }
            }

            Item {
                width: parent.width
                height: 10

                Text {
                    anchors.left: parent.left
                    text: mediaCard.mprisTimePlayed
                    color: "#676767"
                    font.pixelSize: 10
                    font.family: Theme.fontFamily
                }

                Text {
                    anchors.right: parent.right
                    text: mediaCard.mprisTimeTotal
                    color: "#676767"
                    font.pixelSize: 10
                    font.family: Theme.fontFamily
                }
            }
        }
    }
}
