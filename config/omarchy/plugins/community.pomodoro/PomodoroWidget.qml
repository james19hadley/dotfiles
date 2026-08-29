import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "model/PomodoroModel.js" as PomodoroModel

// Pomodoro focus timer in the bar. The whole session lives in a state file
// (endsAt against the wall clock), so it survives shell restarts and every
// per-monitor bar instance renders the same session. Exactly one instance —
// the one on the first screen — runs side effects (phase transitions, DND,
// notifications), so nothing fires twice on multi-monitor setups.
//
// Left click: start / pause / resume. Right click: skip phase.
// Middle click: open interactive controls and history popup.
BarWidget {
  id: root
  moduleName: "community.pomodoro"

  readonly property var config: PomodoroModel.readConfig(settings, session)
  readonly property string stateFile: PomodoroModel.statePath(
    Quickshell.env("XDG_STATE_HOME"), Quickshell.env("HOME"))

  property var session: PomodoroModel.idleState()
  property var undoState: null
  property double nowMs: Date.now()

  readonly property color fg: root.bar ? root.bar.foreground : Color.foreground
  readonly property color dim: Color.muted
  readonly property string fontFamily: root.bar ? root.bar.fontFamily : Style.font.family

  readonly property var historyEntries: {
    var h = root.session.history || {}
    var entries = []
    var keys = Object.keys(h).sort().reverse()
    for (var i = 0; i < keys.length; i++) {
      var k = keys[i]
      var item = h[k]
      var count = typeof item === "number" ? item : (item ? (item.count || 0) : 0)
      var mins = typeof item === "number" ? (item * config.workMinutes) : (item ? (item.minutes || 0) : 0)
      if (k !== root.session.todayDate && count > 0) {
        entries.push({
          date: k,
          count: count,
          minutes: mins,
          formatted: PomodoroModel.formatFocusedTime(mins)
        })
        if (entries.length >= 5) break
      }
    }
    return entries
  }

  // Side-effect leadership: the instance whose window sits on the first
  // screen. Recomputed reactively if screens change.
  readonly property bool leader: {
    var screens = Quickshell.screens || []
    return screens.length === 0 || String(Screen.name) === String(screens[0].name)
  }

  readonly property bool running: session.phase !== "idle" && !PomodoroModel.isPaused(session)
  readonly property real remaining: PomodoroModel.remainingMs(session, nowMs)

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  FileView {
    id: stateReader
    path: root.stateFile
    printErrors: false
    watchChanges: true
    onLoaded: root.session = PomodoroModel.parseState(text())
    onLoadFailed: root.session = PomodoroModel.idleState()
    onFileChanged: reload()
  }

  FileView {
    id: stateWriter
    path: root.stateFile
    printErrors: false
    atomicWrites: true
    // Keep the write-compare cache tracking disk (setText de-dupes).
    onSaved: reload()
  }

  function persist(next) {
    session = next
    stateWriter.setText(PomodoroModel.serializeState(next))
  }

  function recordUndo() {
    undoState = PomodoroModel.cloneState(session)
  }

  function undo() {
    if (undoState !== null) {
      var toRestore = undoState
      undoState = null
      if (toRestore.phase !== "idle" && toRestore.pausedRemainingMs === 0 && toRestore.endsAtMs > 0) {
        var rem = Math.max(1000, toRestore.endsAtMs - nowMs)
        toRestore.endsAtMs = Date.now() + rem
      }
      applyDnd(toRestore)
      persist(toRestore)
    }
  }

  function adjustCount(delta) {
    recordUndo()
    var next = PomodoroModel.adjustTodayCount(session, delta, config.workMinutes, Date.now())
    persist(next)
  }

  function setCount(count) {
    recordUndo()
    var next = PomodoroModel.setTodayCount(session, count, undefined, Date.now())
    persist(next)
  }

  function setWorkDuration(minutes) {
    recordUndo()
    var next = PomodoroModel.cloneState(session)
    next.workMinutes = minutes
    persist(next)
  }

  function setBreakDuration(minutes) {
    recordUndo()
    var next = PomodoroModel.cloneState(session)
    next.breakMinutes = minutes
    next.longBreakMinutes = minutes === 0 ? 0 : Math.max(15, minutes * 3)
    persist(next)
  }

  function toggleBreaks() {
    setBreakDuration(config.breakMinutes === 0 ? 5 : 0)
  }

  // The tick only runs while a session is actively counting down; an idle
  // or paused chip costs nothing.
  Timer {
    running: root.running
    interval: 1000
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      root.nowMs = Date.now()
      if (root.leader && root.remaining <= 0) root.advancePhase()
    }
  }

  // Reconcile a stale on-disk session once at startup (leader only, so the
  // completion side effects fire once).
  Timer {
    running: root.leader && root.session.phase !== "idle"
      && !PomodoroModel.isPaused(root.session)
      && root.session.endsAtMs > 0 && root.session.endsAtMs <= root.nowMs
    interval: 250
    onTriggered: root.advancePhase()
  }

  function advancePhase() {
    var beforePhase = session.phase
    var beforeTodayCount = session.todayCount
    var beforeEndsAtMs = session.endsAtMs
    var resolved = PomodoroModel.resolveState(session, Date.now(), config)
    if (resolved.phase === beforePhase && resolved.endsAtMs === beforeEndsAtMs && PomodoroModel.remainingMs(resolved, Date.now()) > 0) return
    var next = (resolved.phase === beforePhase && resolved.endsAtMs === beforeEndsAtMs)
      ? PomodoroModel.completePhase(resolved, Date.now(), config) : resolved
    applyDnd(next)
    notifyTransition(beforeTodayCount !== next.todayCount ? "" : beforePhase, next)
    persist(next)
  }

  function startOrToggle() {
    recordUndo()
    var now = Date.now()
    if (session.phase === "idle") {
      var started = PomodoroModel.startPhase(session, "work", now, config)
      started.dndWasOn = dndActive()
      applyDnd(started)
      persist(started)
    } else if (PomodoroModel.isPaused(session)) {
      persist(PomodoroModel.resume(session, now))
    } else {
      persist(PomodoroModel.pause(session, now))
    }
  }

  function skipPhase() {
    if (session.phase === "idle") return
    recordUndo()
    var beforeTodayCount = session.todayCount
    var next = PomodoroModel.completePhase(session, Date.now(), config)
    applyDnd(next)
    notifyTransition(beforeTodayCount !== next.todayCount ? "" : session.phase, next)
    persist(next)
  }

  function reset() {
    recordUndo()
    var idle = PomodoroModel.idleState()
    idle.todayCount = session.todayCount
    idle.todayMinutes = session.todayMinutes || 0
    idle.todayDate = session.todayDate
    idle.history = session.history || {}
    idle.workMinutes = session.workMinutes
    idle.breakMinutes = session.breakMinutes
    idle.longBreakMinutes = session.longBreakMinutes
    idle.autoDnd = session.autoDnd
    applyDnd(idle)
    persist(idle)
  }

  // ---- side effects (leader-gated where they would duplicate) --------------
  function dndService() {
    var host = bar && bar.shell && typeof bar.shell.serviceFor === "function" ? bar.shell : null
    return host ? host.serviceFor("omarchy.notifications") : null
  }

  function dndActive() {
    var service = dndService()
    return service ? service.doNotDisturb === true : false
  }

  // DND follows the phase: on during focus, restored to the pre-session
  // state otherwise. Setting the same value twice is harmless, but only the
  // leader drives it so multi-monitor setups act once.
  function applyDnd(state) {
    if (!leader || !config.autoDnd) return
    var service = dndService()
    if (!service || typeof service.setDoNotDisturb !== "function") return
    if (state.phase === "work") service.setDoNotDisturb(true)
    else service.setDoNotDisturb(state.dndWasOn === true)
  }

  function notifyTransition(fromPhase, state) {
    if (!leader || fromPhase === state.phase) return
    var title = PomodoroModel.labelFor(state.phase)
    var body = state.phase === "work"
      ? "Focus for " + config.workMinutes + " minutes (" + state.todayCount + " done today)"
      : (state.phase === "idle" ? "Session ended"
        : "Take " + Math.round(PomodoroModel.phaseDurationMs(state.phase, config) / 60000) + " minutes")
    notifyProcess.command = ["notify-send", "-a", "Pomodoro", title, body]
    notifyProcess.running = true
  }

  Process {
    id: notifyProcess
    command: ["notify-send", "-a", "Pomodoro", "Pomodoro", ""]
  }

  // Scriptable surface: omarchy-shell community.pomodoro toggle|skip|reset|undo|status
  IpcHandler {
    target: "community.pomodoro"

    function toggle(): string {
      root.startOrToggle()
      return root.session.phase
    }

    function skip(): string {
      root.skipPhase()
      return root.session.phase
    }

    function reset(): string {
      root.reset()
      return "idle"
    }

    function undo(): string {
      root.undo()
      return root.session.phase
    }

    function open(): bool {
      popup.open = true
      return true
    }

    function close(): bool {
      popup.open = false
      return false
    }

    function adjustCount(delta: real): int {
      root.adjustCount(delta)
      return root.session.todayCount
    }

    function setCount(count: real): int {
      root.setCount(count)
      return root.session.todayCount
    }

    function status(): string {
      return JSON.stringify({
        phase: root.session.phase,
        paused: PomodoroModel.isPaused(root.session),
        remainingMs: Math.round(root.remaining),
        cycleCount: root.session.cycleCount,
        todayCount: root.session.todayCount,
        todayMinutes: root.session.todayMinutes || 0,
        history: root.session.history || {}
      })
    }
  }

  WidgetButton {
    id: button
    bar: root.bar
    active: root.session.phase === "work" && !PomodoroModel.isPaused(root.session)
    dimmed: PomodoroModel.isPaused(root.session)
    text: root.session.phase === "idle"
      ? PomodoroModel.glyphFor("idle")
      : PomodoroModel.glyphFor(root.session.phase) + " " + PomodoroModel.formatRemaining(root.remaining)
    tooltipText: {
      var count = Number(root.session.todayCount) || 0
      var mins = Number(root.session.todayMinutes) || (count * root.config.workMinutes) || 0
      var timeStr = PomodoroModel.formatFocusedTime(mins)
      if (root.session.phase === "idle") {
        return "Pomodoro (" + count + " done · " + timeStr + " focused) · middle-click opens controls"
      }
      var lbl = PomodoroModel.labelFor(root.session.phase)
      var pausedStr = PomodoroModel.isPaused(root.session) ? " (paused)" : ""
      return lbl + pausedStr + " — " + count + " done (" + timeStr + " focused) today · middle-click opens controls"
    }
    onPressed: function (mouseButton) {
      if (mouseButton === Qt.RightButton) root.skipPhase()
      else if (mouseButton === Qt.MiddleButton) popup.open = !popup.open
      else root.startOrToggle()
    }
  }

  PopupCard {
    id: popup
    anchorItem: button
    bar: root.bar
    open: false
    contentWidth: popup.fittedContentWidth(Style.space(320))
    contentHeight: popup.fittedContentHeight(contentColumn.implicitHeight)

    ColumnLayout {
      id: contentColumn
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      spacing: Style.space(10)

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.space(8)

        Text {
          text: "Pomodoro"
          color: root.fg
          font.family: root.fontFamily
          font.pixelSize: Style.font.title
          font.bold: true
          Layout.fillWidth: true
        }

        Button {
          visible: root.undoState !== null
          iconText: "󰕌"
          tooltipText: "Undo last action"
          horizontalPadding: Style.space(6)
          verticalPadding: Style.space(2)
          fontSize: Style.font.caption
          onClicked: root.undo()
        }

        BorderSurface {
          leftPadding: Style.space(8)
          rightPadding: Style.space(8)
          topPadding: Style.space(2)
          bottomPadding: Style.space(2)
          color: root.session.phase === "work" ? Color.accent : Color.popups.background
          radius: Style.space(4)
          implicitWidth: statusText.implicitWidth + Style.space(16)
          implicitHeight: statusText.implicitHeight + Style.space(6)

          Text {
            id: statusText
            anchors.centerIn: parent
            text: root.session.phase === "work"
              ? (PomodoroModel.isPaused(root.session) ? "Paused" : "Focusing")
              : (root.session.phase === "idle" ? "Idle" : "Break")
            color: root.session.phase === "work" ? Color.background : root.fg
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
          }
        }
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.space(6)

        Text {
          text: root.session.phase === "idle"
            ? (root.config.workMinutes + ":00")
            : PomodoroModel.formatRemaining(root.remaining)
          color: root.fg
          font.family: root.fontFamily
          font.pixelSize: Style.space(26)
          font.bold: true
        }

        Item {
          Layout.fillWidth: true
        }

        Button {
          text: root.session.phase === "idle" ? "Start" : (PomodoroModel.isPaused(root.session) ? "Resume" : "Pause")
          selected: root.session.phase === "work" && !PomodoroModel.isPaused(root.session)
          fontFamily: root.fontFamily
          fontSize: Style.font.caption
          horizontalPadding: Style.space(8)
          onClicked: root.startOrToggle()
        }

        Button {
          visible: root.session.phase !== "idle"
          text: "Skip"
          tooltipText: "Skip to next phase"
          fontFamily: root.fontFamily
          fontSize: Style.font.caption
          horizontalPadding: Style.space(8)
          onClicked: root.skipPhase()
        }

        Button {
          visible: root.session.phase !== "idle"
          text: "Reset"
          tooltipText: "Reset session to idle"
          fontFamily: root.fontFamily
          fontSize: Style.font.caption
          horizontalPadding: Style.space(8)
          onClicked: root.reset()
        }
      }

      Rectangle {
        Layout.fillWidth: true
        height: 1
        color: Color.popups.border
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.space(6)

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(8)

          ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.space(2)

            Text {
              text: "Completed Today"
              color: root.fg
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              font.bold: true
            }

            Text {
              text: "Focused: " + PomodoroModel.formatFocusedTime(root.session.todayMinutes || 0)
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }

          Text {
            text: String(root.session.todayCount)
            color: Color.accent
            font.family: root.fontFamily
            font.pixelSize: Style.font.title
            font.bold: true
          }
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(6)

          Button {
            text: "-1"
            tooltipText: "Decrease count"
            fontFamily: root.fontFamily
            fontSize: Style.font.caption
            Layout.fillWidth: true
            onClicked: root.adjustCount(-1)
          }

          Button {
            text: "+1"
            tooltipText: "Increase count"
            fontFamily: root.fontFamily
            fontSize: Style.font.caption
            Layout.fillWidth: true
            onClicked: root.adjustCount(1)
          }

          Button {
            text: "Set 0"
            tooltipText: "Reset today to 0"
            fontFamily: root.fontFamily
            fontSize: Style.font.caption
            Layout.fillWidth: true
            onClicked: root.setCount(0)
          }
        }
      }

      Rectangle {
        Layout.fillWidth: true
        height: 1
        color: Color.popups.border
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.space(6)

        Text {
          text: "Duration"
          color: root.fg
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(4)

          Repeater {
            model: [15, 20, 25, 30, 45, 50]
            delegate: Button {
              required property int modelData
              text: modelData + "m"
              selected: root.config.workMinutes === modelData
              fontFamily: root.fontFamily
              fontSize: Style.font.caption
              Layout.fillWidth: true
              horizontalPadding: Style.space(4)
              onClicked: root.setWorkDuration(modelData)
            }
          }
        }
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.space(6)

        Text {
          text: "Rest Breaks"
          color: root.fg
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(4)

          Repeater {
            model: [
              { label: "Off", minutes: 0 },
              { label: "3m", minutes: 3 },
              { label: "5m", minutes: 5 },
              { label: "10m", minutes: 10 },
              { label: "15m", minutes: 15 }
            ]
            delegate: Button {
              required property var modelData
              text: modelData.label
              selected: root.config.breakMinutes === modelData.minutes
              fontFamily: root.fontFamily
              fontSize: Style.font.caption
              Layout.fillWidth: true
              horizontalPadding: Style.space(4)
              onClicked: root.setBreakDuration(modelData.minutes)
            }
          }
        }
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.space(4)
        visible: root.historyEntries.length > 0

        Rectangle {
          Layout.fillWidth: true
          height: 1
          color: Color.popups.border
        }

        Text {
          text: "Recent History"
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }

        Repeater {
          model: root.historyEntries
          delegate: RowLayout {
            required property var modelData
            Layout.fillWidth: true
            spacing: Style.space(8)

            Text {
              text: modelData.date
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              Layout.fillWidth: true
            }

            Text {
              text: modelData.formatted + " · " + modelData.count + " done"
              color: root.fg
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
            }
          }
        }
      }
    }
  }
}
