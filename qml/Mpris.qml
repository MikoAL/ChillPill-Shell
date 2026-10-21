import Quickshell
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property var playersList: Mpris.players.values !== undefined ? Mpris.players.values : Mpris.players
    property var activePlayer: resolveActivePlayer()
    property string lastActivePlayerDbusName: ""

    readonly property string track: activePlayer ? (activePlayer.trackTitle || activePlayer.title || "") : ""
    readonly property string artist: {
        if (!activePlayer) return ""
        let a = activePlayer.artist
        if (!a && activePlayer.metadata) a = activePlayer.metadata["xesam:artist"]
        if (a) return Array.isArray(a) ? a.join(", ") : String(a)
        return ""
    }
    readonly property string artUrl: activePlayer ? (activePlayer.trackArtUrl || activePlayer.artUrl || "") : ""
    readonly property bool playing: activePlayer ? activePlayer.playbackState === MprisPlaybackState.Playing : false

    readonly property bool hasPlayer: activePlayer !== null && (
        activePlayer.playbackState === MprisPlaybackState.Playing ||
        activePlayer.playbackState === MprisPlaybackState.Paused
    )

    // only the dashboard's media card shows progress, so the 250ms poll runs
    // while something is watching (bound from shell.qml)
    property bool polling: true
    // refresh synchronously so the media card never shows a stale position
    onPollingChanged: if (polling) pollProgress()

    property real polledPosition: 0
    property real polledLength: 0
    property real lastPollTime: 0
    property bool lastPollPlaying: false
    property string lastTrackKey: ""
    property real lengthCache: 0
    readonly property real progress: polledLength > 0 ? polledPosition / polledLength : 0

    function pollProgress() {
        if (!activePlayer) {
            polledPosition = 0
            polledLength = 0
            lastPollTime = 0
            lastTrackKey = ""
            lengthCache = 0
            return
        }
        const now = Date.now()
        const delta = lastPollTime > 0 ? (now - lastPollTime) / 1000 : 0
        lastPollTime = now
        // the gap since the last poll can be long while the dashboard is
        // closed; it only counts toward the estimate below if the player was
        // playing through it (pause/resume/track changes poll immediately)
        const wasPlaying = lastPollPlaying
        lastPollPlaying = root.playing

        // restart the local position estimate whenever the track changes
        const trackKey = (activePlayer.trackTitle || "") + "\u0000" + (activePlayer.trackArtUrl || "")
        const trackChanged = trackKey !== lastTrackKey
        if (trackChanged) {
            lastTrackKey = trackKey
            polledPosition = 0
            lengthCache = 0
        }

        // length in seconds. Firefox drops mpris:length from its metadata when
        // you seek (both SetPosition and Seek trigger it), which makes
        // Quickshell report length == position and collapses the bar to full.
        // Only trust the reported length while the player says it's supported;
        // otherwise keep the last good value for this track.
        let len = 0
        if (activePlayer.lengthSupported) {
            len = Number(activePlayer.length) || 0
        } else if (activePlayer.metadata) {
            const metaLen = Number(activePlayer.metadata["mpris:length"]) || 0
            if (metaLen > 0) len = metaLen / 1000000
        }
        if (len <= 0) len = lengthCache
        if (len > 0) lengthCache = len
        polledLength = len

        if (activePlayer.positionSupported) {
            polledPosition = Number(activePlayer.position) || 0
        } else if (wasPlaying && !trackChanged && len > 0) {
            // browser tabs etc. don't expose the Position property: keep a
            // local wall-clock estimate so the bar and time left still advance
            if (delta > 0) polledPosition += delta
        }
    }

    Timer {
        id: positionTimer
        interval: 250
        running: root.hasPlayer && root.polling
        repeat: true
        triggeredOnStart: true
        onTriggered: root.pollProgress()
    }

    Connections {
        target: root.activePlayer
        function onPositionChanged() { root.pollProgress() }
        function onLengthChanged() { root.pollProgress() }
        function onPlaybackStateChanged() { root.pollProgress() }
        function onTrackTitleChanged() { root.pollProgress() }
        function onTrackArtUrlChanged() { root.pollProgress() }
      }

    function resolveActivePlayer() {
        if (!playersList || playersList.length === 0) return null
        for (let i = 0; i < playersList.length; i++)
            if (playersList[i].playbackState === MprisPlaybackState.Playing)
                return playersList[i]
        const remembered = findByDbus(lastActivePlayerDbusName)
        if (remembered) return remembered
        for (let i = 0; i < playersList.length; i++)
            if (playersList[i].playbackState === MprisPlaybackState.Paused)
                return playersList[i]
        return playersList.length > 0 ? playersList[0] : null
    }

    function findByDbus(name) {
        if (!playersList || !name) return null
        for (let i = 0; i < playersList.length; i++)
            if (playersList[i].dbusName === name) return playersList[i]
        return null
    }

    function playPause() { if (activePlayer && activePlayer.canTogglePlaying) activePlayer.togglePlaying() }
    function next() { if (activePlayer && activePlayer.canGoNext) activePlayer.next() }
    function prev() { if (activePlayer && activePlayer.canGoPrevious) activePlayer.previous() }

    onActivePlayerChanged: {
        if (activePlayer && activePlayer.dbusName)
            lastActivePlayerDbusName = activePlayer.dbusName
    }
}
