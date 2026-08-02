# ChillPill-Shell — Bar Rework + Panel Merge Spec

Target repo: `LUCKYS1NGHH/ChillPill-Shell` (Quickshell 0.3+, QML + Qt6 C++ backend, GPL-3.0).
Written against upstream `main` (137 commits, flat `qml/` directory, `IslandBackend` C++ plugin).

**Verify before starting:** the local tree already diverges from upstream — an fcitx5/chewing indicator was added by a previous agent and does not exist upstream. Locate that module first and record its filename, data source (DBus `org.fcitx.Fcitx5.Controller` vs polled `fcitx5-remote`), and exported properties. This spec references it as `Fcitx5.qml`.

---

## 0. Repository facts the implementation depends on

| Fact | Location |
|---|---|
| Bar content is one `RowLayout { id: row; anchors.centerIn: parent }` | `qml/shell.qml:303` |
| Current order: `Battery, Volume, Workspaces, Network, Clock` | `qml/shell.qml:319-330` |
| Pill width/height/radius are ternary chains keyed on state booleans | `qml/shell.qml:187-221` |
| State booleans: `appLauncher`, `miniDashboard`, `controlCenter`, `cliphistOpen`, `activeOsd` | `qml/shell.qml:119-123, 166` |
| Four `IpcHandler` blocks toggle those booleans mutually exclusively | `qml/shell.qml:14-40` |
| Left/middle/right click on the pill open control center / cliphist / mini dashboard | `qml/shell.qml:243-289` |
| `SystemClock { precision: SystemClock.Minutes }` — the only clock in the shell | `qml/shell.qml:1129-1132` |
| Input region is masked to the pill + calendar + weather popups | `qml/shell.qml:89-108` |
| Backend singletons use `QML_ELEMENT` + `QML_SINGLETON` under URI `IslandBackend` | `backend/WifiController.h`, `CMakeLists.txt` |
| QML installs flat: `install -m 644 qml/*` → `/usr/share/chillpill-shell` | `install.sh` |
| `miniDashboard` referenced 28× across 3 files; `controlCenter` 51× across 4 files | `qml/` |

**No CPU, RAM, or live-throughput source exists in the repo.** `Bandwidth.qml` reports *cumulative daily* totals from `nusgmon --today --json`, not a rate.

**Dev loop:** QML edits require `sudo ./install.sh --skip-deps`, or symlink `/usr/share/chillpill-shell` → the working tree for iteration. C++ changes require the CMake build step. Restart with `chillpill-shell` (wraps `qs -p /usr/share/chillpill-shell`).

---

## 1. Global constraints

These are hard requirements; violating them is a failed implementation.

1. **No width jitter.** The pill animates `implicitWidth` (`Behavior on implicitWidth`, 225ms OutExpo). Any module whose text width varies with its value (CPU %, RAM %, throughput, seconds) will make the entire bar breathe once per tick. Every numeric field must reserve a fixed width sized to its worst-case string and right-align inside it:

   ```qml
   TextMetrics { id: cpuMetrics; font: cpuText.font; text: "100%" }
   Text { id: cpuText; implicitWidth: cpuMetrics.width; horizontalAlignment: Text.AlignRight }
   ```

2. **Performance budget.** Target hardware for this project is GPU-less (upstream: Intel HD 4000). Seconds display forces ≥1 Hz repaint of the bar. Do not add per-module `Timer` + `Process` polling — one `sh -c` fork per second per metric is the wrong shape. Metrics come from a single C++ timer (§3.2).

3. **Locale.** `Qt.formatDateTime` resolves `MMM` through the system locale; on a `zh_TW` system this yields `8月`, not `Aug`. Force English month abbreviations explicitly:

   ```qml
   text: clock.date.toLocaleString(Qt.locale("en_US"), Config.clockFormat)
   ```

4. **Scaling.** Every new size, padding, and font must be multiplied by `Config.pillScale` / `Config.paddingScale` the way existing modules do. No hardcoded pixel constants outside `Config`.

5. **Fonts.** Text uses `Theme.fontFamily` (Monocraft by default, monospace — this is what makes fixed-width reservations exact). Glyphs use `Theme.nerdFontFamily`. `Network.qml` currently hardcodes `"FiraCode Nerd Font Propo"`; fix it to `Theme.nerdFontFamily` while touching it.

6. **No regressions in collapse states.** OSD (volume/brightness/battery/timer), notification popup, cliphist, and app launcher all take over the pill and hide `row`. All of them must still work unchanged after the layout rewrite.

---

## 2. Task A — Bar layout

### 2.1 Target order

```
[ 1 2 3 4 5 ]        ·····        Aug 2  21:35:32        ·····        [中] CPU RAM ↑ ↓ WIFI VOL BAT
   left edge                          centered                              right edge
```

Left zone: `Workspaces`
Center zone: `Clock`
Right zone, in order: `Fcitx5`, `Cpu`, `Ram`, `NetUp`, `NetDown`, `Network` (wifi), `Volume`, `Battery`

### 2.2 Zone architecture

Replace the single centered `RowLayout` with three positioned groups inside `box`:

```qml
Item {
  id: barContent
  anchors.fill: parent
  anchors.leftMargin:  Config.pillSidePadding * Config.paddingScale
  anchors.rightMargin: Config.pillSidePadding * Config.paddingScale
  // opacity/visible: carry over the exact guard expression from row (shell.qml:309-315)

  RowLayout { id: leftGroup;   anchors.left:  parent.left;  anchors.verticalCenter: parent.verticalCenter }
  Item      { id: centerGroup; anchors.horizontalCenter: parent.horizontalCenter; anchors.verticalCenter: parent.verticalCenter }
  RowLayout { id: rightGroup;  anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter }
}
```

Then:

```qml
readonly property real barContentWidth:
    2 * Math.max(leftGroup.implicitWidth, rightGroup.implicitWidth)
  + centerGroup.implicitWidth
  + 2 * Config.zoneGap * Config.paddingScale
```

and substitute `barContentWidth` for `row.implicitWidth` in the `implicitWidth` chain at `shell.qml:197`. Height chain (`:213`) uses `Math.max` of the three groups' `implicitHeight`.

**Consequence — read this before implementing.** The `2 * Math.max(...)` term is what makes the clock land on the true geometric centre of the pill. Estimated at `pillScale: 1.0`, Monocraft 10px: left ≈ 104px, right ≈ 420px, clock ≈ 90px → pill ≈ 960px, of which ~316px is empty space to the left of the clock. This is the cost of a genuinely centred clock on a shrink-to-fit pill. See Decision D1 — do not pick an approach unilaterally.

### 2.3 Clock

- `shell.qml:1131` → `precision: SystemClock.Seconds`.
- `Config.clockFormat` default → `"MMM d  HH:mm:ss"` (two spaces, matching `Aug 2  21:35:32`). Update `config.jsonc` and the `JsonAdapter` fallback in `Config.qml`.
- `Clock.qml` uses the `toLocaleString` form from §1.3.
- Width is stable under Monocraft except day-of-month `d` (1→2 chars on the 10th) and month name (`May` vs `Sept`). Reserve via `TextMetrics` on `"Sept 30  00:00:00"`.
- Raising precision to `Seconds` re-evaluates every binding on `clock.date`. Audit: `Datetime.qml`, `CalendarBox.qml`, `WeatherModule.qml`. These are cheap, but confirm none of them do work per tick.

### 2.4 Workspaces

`Workspaces.qml` already renders `Config.maxWorkspaces` (default 5) with a click-to-focus `MouseArea`. No change beyond moving it into `leftGroup`. Confirm `Config.maxWorkspaces` is 5 in the user's `~/.config/chillpill-shell/config.jsonc`.

Note the existing dispatch is malformed for standard Hyprland IPC:
```qml
Hyprland.dispatch("hl.dsp.focus({ workspace = " + (index + 1) + "})")
```
That is Hyprland-Lua-config syntax passed to a dispatcher socket. Verify it actually switches workspaces on the target machine; if not, correct to `"workspace " + (index + 1)`.

### 2.5 fcitx5 chewing indicator

Keep the existing module's data source. Requirements for its bar presentation:
- Fixed reserved width (worst case of its label set, e.g. `中`/`英` or `bo`/`us`).
- Must not spawn a process per tick. If the existing implementation polls `fcitx5-remote` on a timer, convert it to the DBus signal `org.fcitx.Fcitx5.Controller` → `InputMethodGroupChanged` / `CurrentInputMethodChanged` before shipping.
- Hidden (`visible: false`, zero width) when fcitx5 is not running, rather than showing a stale glyph.

### 2.6 CPU / RAM / network throughput — new modules

Four new bar modules: `Cpu.qml`, `Ram.qml`, `NetUp.qml`, `NetDown.qml`, all reading one backend singleton (§3).

| Module | Value | Reserved width string | Notes |
|---|---|---|---|
| Cpu | aggregate busy % | `100%` | Nerd glyph `\uf4bc`, colour ramp at >70% / >90% |
| Ram | used % of MemTotal | `100%` | used-GiB variant behind `Config.ramDisplay` |
| NetUp | tx rate | `888.8M` | glyph `\uf0aa` or `↑` |
| NetDown | rx rate | `888.8M` | glyph `\uf0ab` or `↓` |

Rate formatting rule (deterministic, no width surprises): scale to `K`/`M`/`G` on 1024 boundaries; one decimal below 10, zero decimals at/above 10; single-character unit suffix; no `/s` in the bar (implied). `0` renders as `0K`, not `--`.

### 2.7 Wifi / Volume / Battery

Unchanged components, repositioned. Two fixes while moving them:
- `Network.qml` SSID `Layout.maximumWidth: 90 * Config.pillScale` — an elided SSID still varies in width. Either set a fixed `Layout.preferredWidth` or drop the SSID text in the bar and keep only the signal glyph (SSID already appears in the wifi panel). Prefer the latter given the right zone is already dense; make it `Config.showSsidInBar`.
- `Volume.qml` percentage varies 2→3 chars; reserve `100%`.

---

## 3. Task A backend — `SysMonitor`

### 3.1 Placement

New `backend/SysMonitor.h` / `.cpp`, registered exactly like `WifiController`: `QML_ELEMENT`, `QML_SINGLETON`, `QML_UNCREATABLE("Singleton")`, added to the `SOURCES` list in `qt_add_qml_module(IslandBackend ...)`. No new Qt component dependencies (Core only).

### 3.2 Behaviour

- One `QTimer`, interval from a QML-settable `interval` property, default 2000 ms.
- Reads `/proc/stat` (first `cpu` line), `/proc/meminfo` (`MemTotal`, `MemAvailable`), `/proc/net/dev` — direct `QFile` reads, no subprocess.
- CPU %: delta of `(user+nice+system+irq+softirq+steal)` over delta of total jiffies, between consecutive ticks. First tick emits 0, not a garbage value computed against boot totals.
- RAM %: `(MemTotal - MemAvailable) / MemTotal`. Not `MemFree`.
- Net: sum rx/tx bytes across interfaces, excluding `lo` and (configurable) virtual interfaces matching `^(docker|veth|br-|virbr|tun|wg)`. Rate = byte delta ÷ elapsed ms, using `QElapsedTimer` rather than the nominal interval. Handle 32-bit counter wrap by clamping negative deltas to 0.
- Exposed: `cpuPercent` (real 0–100), `ramPercent`, `ramUsedBytes`, `ramTotalBytes`, `rxBytesPerSec`, `txBytesPerSec`, each with a `NOTIFY` signal. Formatting stays in QML.
- `running` property so the timer stops when the bar is hidden (`fullscreenActive`, `notifFullscreenMode`) — the pill is invisible in those states and there is no reason to keep sampling.

### 3.3 Config additions

Add to `config.jsonc`, `Config.qml`'s `JsonAdapter`, and the readonly aliases:

```jsonc
"clockFormat": "MMM d  HH:mm:ss",
"sysMonitorInterval": 2000,
"showSsidInBar": false,
"ramDisplay": "percent",
"netExcludeInterfaces": "^(lo|docker|veth|br-|virbr|tun|wg)",
"zoneGap": 20,
"pillSidePadding": 16
```

`Config.qml` uses `FileView { watchChanges: true }`, so these are live-reloadable — verify each new value actually re-propagates without a restart.

---

## 4. Task B — Merge mini dashboard into control center

### 4.1 What is being merged

| Currently in **control center** (`shell.qml:440-855`) | Currently in **mini dashboard** (`shell.qml:859-1128`) |
|---|---|
| `MediaPlayer` (+ auto-open behaviour) | Avatar, username, hostname, uptime |
| `CcButtons` — wifi / DND / timer | `Battery` (large) |
| Volume + brightness sliders | `IpStatus` (IP, iface, VPN) |
| Notification stack + header + clear-all | `Bandwidth` (nusgmon daily totals) |
| | `Datetime` → calendar popup |
| | `WeatherIndicator` → weather popup |
| | Power row: lock / sleep / reboot / shutdown |

That is 12 content blocks in one panel. This will not fit the current 390×(118–240) geometry. See Decision D3 — the panel shape is not something to guess at.

### 4.2 State model

Collapse `controlCenter` and `miniDashboard` into a single `property bool dashboard`. Do **not** ship compatibility aliases; do a full rename pass, because both names are read *and written* across `shell.qml`, `CcButtons.qml`, `MediaPlayer.qml`, `WifiPanel.qml`, `IpStatus.qml`, `Bandwidth.qml`.

Migration checklist:
- `implicitWidth` / `implicitHeight` / `radius` / `color` ternary chains (`:187-226`) — merge the two branch sets into one, delete the dead branches.
- `onMiniDashboardChanged` (`:228`) closes calendar and weather popups → becomes `onDashboardChanged`. Note the existing bug there: the `if` guards only the first statement, so `weatherPopupLoader.item.shown = false` runs unconditionally and will throw when `item` is null. Fix while migrating.
- Poll gates `running: box.miniDashboard` in `IpStatus.qml`, `Bandwidth.qml`, and the uptime `Timer` (`:939`) → `box.dashboard`.
- `mediaAutoOpened` currently forces a compact 380×124 control-center variant. Decide whether media auto-open still expands the *merged* panel or becomes its own transient state distinct from `dashboard`. Recommended: keep it separate — auto-opening a full dashboard because a track changed is wrong.
- Input mask (`:89-108`) — recheck popup regions against the new panel geometry.

### 4.3 IPC and input

- Merge `controlCenter` and `miniDashboard` `IpcHandler` blocks into one named `dashboard`, keeping `toggle` / `show` / `hide`.
- Keep `miniDashboard` and `controlCenter` as thin deprecated IPC aliases that forward to `dashboard` for one release, so existing Hyprland keybinds don't silently break. Ship a README note with the replacement bindings.
- Mouse: left click → `dashboard`. Middle click → cliphist (unchanged). Right click is now free — leave it unbound or reserve it for a future action; do not have it toggle the same panel.

### 4.4 Layout requirements for the merged panel

Whatever shape Decision D3 selects:
- Notification stack keeps its `notifBump` dynamic-height behaviour and its `ScrollBar`.
- The weather and calendar popups anchor to their triggers inside the new panel, and their mask regions follow.
- Sliders keep `sliderHitSlop` (invisible hit padding) — losing it makes 4px sliders unusable.
- All four power buttons keep their hover colour animation and `Process` commands verbatim.
- The panel's total height must be bounded; if content exceeds it, scroll rather than growing the pill past the screen.

---

## 5. Acceptance criteria

1. Bar renders left→right: 5 workspace pills, clock, fcitx5, CPU, RAM, net-up, net-down, wifi, volume, battery.
2. Clock reads `Aug 2  21:35:32` — English month, no leading zero on the day, 24-hour, ticking every second — and shows English months under a `zh_TW` locale.
3. Over 60 s of idle observation, the pill's left and right edges do not move. Verify at 0–9%, 10–99%, 100% CPU and across a KiB→MiB throughput transition.
4. Clock text centre is within 1px of the pill's horizontal centre (if D1-a), across workspace-count changes and SSID changes.
5. Idle CPU cost of the shell process is not measurably worse than upstream at the same `sysMonitorInterval`. Measure before and after.
6. `qs ipc -p /usr/share/chillpill-shell call dashboard toggle` opens one panel containing every block listed in §4.1.
7. Cliphist, app launcher, all four OSDs, notification popup, media auto-open, wifi panel, calendar popup, and weather popup all still work.
8. No QML warnings on startup (`qs -p ... 2>&1 | grep -i warn`), specifically no null-`item` errors from `weatherPopupLoader`.
9. `sudo ./install.sh --skip-deps` succeeds from clean, including the C++ build.
10. Config changes to `clockFormat`, `sysMonitorInterval`, `maxWorkspaces` take effect without restarting the shell.

---

## 6. Sequencing

Land in this order; each step is independently testable and revertable.

1. `SysMonitor` C++ singleton + CMake wiring. Verify from a throwaway QML file before touching the bar.
2. `Cpu.qml`, `Ram.qml`, `NetUp.qml`, `NetDown.qml` with fixed-width reservation.
3. Clock precision + format + locale.
4. Three-zone bar rewrite and the `implicitWidth` formula.
5. Config schema additions.
6. Panel merge (largest blast radius, last).

---

## 7. Open decisions — needed before step 4 and step 6

**D1 — clock centring.**
(a) True geometric centre via `2 * max(left, right)`: clock is exactly centred, pill ~960px with ~316px dead space on the left.
(b) Sequential middle: clock sits between the two groups in one flow row, pill shrinks to ~615px, clock is *not* on the centre of the screen or the pill.
(c) Fixed-width bar: pill spans the screen minus a margin, groups pin to the edges, clock centred, pill stops being shrink-to-fit in its bar state (still morphs for OSD/panel states).

**D2 — "network out and network download".** Live throughput rate (new `/proc/net/dev` sampling, §3), or today's cumulative up/down totals (existing `nusgmon` integration, refreshed every 5 min)? This spec assumes live rate.

**D3 — merged panel shape.** All 12 blocks in §4.1 in one view means a panel roughly 420×450. Options: single scrolling column; two columns (system/profile left, media/controls/notifications right); or tabbed with the pill height changing per tab. Also: does anything get dropped in the merge?

**D4 — fcitx5 module.** Filename, data source, and what it displays (input-method mode `中`/`英`, or engine name). Needed to spec its reserved width and its DBus migration.

**D5 — media auto-open.** Keep as its own compact transient state, or fold into the merged dashboard?
