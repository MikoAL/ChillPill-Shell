import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Notifications
import QtQuick
import QtMultimedia

Item {
  id: root

  // toast state
  property var queue: []
  property var current: null
  readonly property bool active: current !== null
  property int displayTime: Config.notificationDisplayTime
  // cap on app-requested timeouts so one app can't hold the pill for minutes
  property int maxToastTime: 30000

  // hovering the toast holds it on screen
  property bool pillHovered: false
  property bool cardHovered: false
  readonly property bool hoverPaused: pillHovered || cardHovered
  onHoverPausedChanged: scheduleHide()

  property int _idCounter: 0
  property alias dndEnabled: savedState.dndEnabled
  property var notifications: []
  property var notificationsReversed: [] // pre-computed. avoid recomputing per bindig
  property int maxStored: Config.maxNotificationsInStack
  property bool avoidDuplicateNotifications: Config.avoidDuplicateNotifications

  SoundEffect {
    id: notifySound
    source: "file://" + Quickshell.shellDir + "/share/notification.wav"
    volume: 1
  }

  // DND survives restarts. kept out of config.jsonc so writing it back
  // doesn't clobber the user's comments/formatting there
  FileView {
    path: Quickshell.env("HOME") + "/.config/chillpill-shell/state.json"
    printErrors: false
    onAdapterUpdated: writeAdapter()
    onLoadFailed: error => { if (error === FileViewError.FileNotFound) writeAdapter() }

    JsonAdapter {
      id: savedState
      property bool dndEnabled: false
    }
  }

  function trigger(): void {
    if (Config.notificationSound && notifySound.status === SoundEffect.Ready) notifySound.play()
  }

  function syncReversed(): void {
    notificationsReversed = notifications.slice().reverse()
  }

  function makeEntry(notif) {
    const entry = {}
    for (let key in notif) {
      entry[key] = notif[key]
    }
    entry.notif = notif
    entry.baseSummary = notif.summary
    entry.count = 1
    entry.receivedTime = new Date()
    entry._id = _idCounter++
    return entry
  }

  // release the server-side Notification so it's freed and the sending app
  // gets its "closed" signal. entries are plain JS copies, so setting
  // tracked on the entry itself does nothing
  function untrack(notif): void {
    if (notif && notif.tracked) notif.tracked = false
  }

  // drop our entry when the sending app closes/withdraws its notification.
  // callers always remove the entry before untracking, so our own untrack
  // finds nothing here and doesn't recurse
  function watchClosed(notif): void {
    notif.closed.connect(() => root.dismiss(notif))
  }

  function findDuplicate(notif) {
    for (let i = 0; i < notifications.length; i++) {
      const e = notifications[i]
      if (e.appName === notif.appName &&
          e.baseSummary === notif.summary &&
          e.body === notif.body) {
        return e
      }
    }
    return null
  }

  function enqueue(notif): void {
    watchClosed(notif)

    // conditional duplicate check
    if (avoidDuplicateNotifications) {
      const dup = findDuplicate(notif)
      if (dup) {
        // fresh object so bindings on `current` see the new count
        const entry = Object.assign({}, dup)
        entry.notif = notif
        entry.count = dup.count + 1
        entry.summary = dup.baseSummary + " (" + entry.count + ")"
        entry.receivedTime = new Date()

        const idx = notifications.indexOf(dup)
        if (idx !== -1) notifications.splice(idx, 1)
        notifications.push(entry)
        const qidx = queue.indexOf(dup)
        if (qidx !== -1) queue.splice(qidx, 1)

        syncReversed()
        notificationsChanged()
        untrack(dup.notif)

        if (current === dup) {
          // already on screen: swap in the new count and extend its time
          current = entry
          scheduleHide()
          trigger()
        } else if (!silenced(entry)) {
          queue.push(entry)
          trigger()
          if (!current) advance()
        }
        console.log("Duplicate notification incremented:", entry.summary)
        return
      }
    }

    const entry = makeEntry(notif)
    notifications.push(entry)
    if (notifications.length > maxStored) {
      const old = notifications.shift()
      const qidx = queue.indexOf(old)
      if (qidx !== -1) queue.splice(qidx, 1)
      untrack(old.notif)
    }
    syncReversed()
    notificationsChanged()
    if (silenced(entry)) return
    queue.push(entry)
    trigger()
    if (!current) advance()
  }

  function advance(): void {
    current = queue.length > 0 ? queue.shift() : null
    scheduleHide()
  }

  function isCritical(entry): bool {
    return entry.urgency === NotificationUrgency.Critical
  }

  // DND mutes everything except critical (low battery, alarms, ...)
  function silenced(entry): bool {
    return dndEnabled && !isCritical(entry)
  }

  // ms the toast stays up, -1 = until clicked. expireTimeout is the app's
  // request in ms (-1 = "server default", 0 = "never", which we treat as default
  // for non-critical so a chatty app can't pin the pill)
  function toastDuration(entry): int {
    if (isCritical(entry)) return -1
    if (entry.expireTimeout > 0) return Math.min(entry.expireTimeout, maxToastTime)
    return displayTime
  }

  function scheduleHide(): void {
    hideTimer.stop()
    if (!current || hoverPaused) return
    const ms = toastDuration(current)
    if (ms < 0) return
    hideTimer.interval = ms
    hideTimer.start()
  }

  // take the toast off screen but keep it in the dashboard list
  function hideToast(): void {
    if (current) advance()
  }

  function findEntry(target) {
    for (let i = 0; i < notifications.length; i++) {
      const e = notifications[i]
      if (e === target || e.notif === target || e._id === target)
        return i
    }
    return -1
  }

  function dismiss(target): void {
    const idx = findEntry(target)
    if (idx === -1) return
    const entry = notifications[idx]
    notifications.splice(idx, 1)
    const qidx = queue.indexOf(entry)
    if (qidx !== -1) queue.splice(qidx, 1)
    syncReversed()
    notificationsChanged()
    if (current === entry) advance()
    untrack(entry.notif)
  }

  // click-to-open: fire the app's "default" action (Discord uses it to jump
  // to the message's channel) and raise the app's window ourselves, since
  // Hyprland ignores most apps' own focus requests
  function activate(target): void {
    const idx = findEntry(target)
    if (idx === -1) return
    const entry = notifications[idx]
    focusApp(entry)
    const action = findAction(entry, "default")
    if (action) action.invoke()
    // invoke() may already have closed it (non-resident), dismiss is a no-op then
    dismiss(entry)
  }

  function findAction(entry, identifier) {
    const notif = entry.notif
    if (!notif || !notif.tracked) return null
    const actions = notif.actions
    for (let i = 0; i < actions.length; i++) {
      if (actions[i].identifier === identifier) return actions[i]
    }
    return null
  }

  // actions to show as buttons in the dashboard ("Mark as read", "Reply", ...).
  // "default" is the click-the-notification action, so it's left out
  function buttonActions(entry) {
    const notif = entry ? entry.notif : null
    if (!notif || !notif.tracked) return []
    const out = []
    const actions = notif.actions
    for (let i = 0; i < actions.length; i++) {
      if (actions[i].identifier !== "default" && actions[i].text) out.push(actions[i])
    }
    return out
  }

  function invokeAction(target, identifier): void {
    const idx = findEntry(target)
    if (idx === -1) return
    const entry = notifications[idx]
    const action = findAction(entry, identifier)
    if (!action) return
    // resident notifications stay after an action (e.g. a media player's
    // play/pause), everything else is done once acted on
    const resident = entry.notif.resident
    action.invoke()
    if (!resident) dismiss(entry)
  }

  // match an open window by app id against the notification's desktop entry
  // or app name ("discord", "org.telegram.desktop" vs "telegram", ...)
  function focusApp(entry): void {
    const names = [entry.desktopEntry, entry.appName]
      .filter(n => n)
      .map(n => String(n).toLowerCase().replace(/\.desktop$/, ""))
    if (names.length === 0) return
    const toplevels = ToplevelManager.toplevels.values
    for (let i = 0; i < toplevels.length; i++) {
      const id = (toplevels[i].appId || "").toLowerCase()
      if (!id) continue
      for (const n of names) {
        if (id === n || id.endsWith("." + n) || n.endsWith("." + id)) {
          toplevels[i].activate()
          return
        }
      }
    }
  }

  function clearAll(): void {
    const old = notifications
    notifications = []
    notificationsReversed = []
    queue = []
    current = null
    hideTimer.stop()
    for (let i = 0; i < old.length; i++) untrack(old[i].notif)
  }

  Timer {
    id: hideTimer
    onTriggered: root.advance()
  }
}
