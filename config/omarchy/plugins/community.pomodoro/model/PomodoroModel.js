// Pomodoro engine model. Loaded by both the QML widget and the Node test
// harness, so it must stay dependency-free.
//
// The whole session lives in a small state object persisted to a state file:
//   { phase, endsAtMs, pausedRemainingMs, cycleCount, todayCount, todayDate,
//     dndWasOn }
// Remaining time derives from endsAtMs against the wall clock, so a shell
// restart mid-session resumes exactly; a session that fully elapsed while
// the shell was down still counts.

var PHASES = ["idle", "work", "break", "longBreak"]

var DEFAULTS = {
  workMinutes: 20,
  breakMinutes: 0,
  longBreakMinutes: 0,
  cyclesPerLong: 4,
  autoDnd: true
}

function idleState() {
  return {
    phase: "idle",
    endsAtMs: 0,
    pausedRemainingMs: 0,
    cycleCount: 0,
    todayCount: 0,
    todayDate: "",
    dndWasOn: false,
    history: {}
  }
}

// Read widget settings with validation; invalid values fall back.
function readConfig(settings, state) {
  var s = settings || {}
  var st = state || {}
  function minutes(value, fallback, allowZero) {
    var n = Number(value)
    var min = allowZero ? 0 : 1
    return isFinite(n) && n >= min && n <= 240 ? Math.floor(n) : fallback
  }
  var cycles = Number(s.cyclesPerLong)

  var baseWork = s.workMinutes !== undefined ? minutes(s.workMinutes, DEFAULTS.workMinutes, false) : DEFAULTS.workMinutes
  var work = st.workMinutes !== undefined ? minutes(st.workMinutes, baseWork, false) : baseWork

  var baseBreak = s.breakMinutes !== undefined ? minutes(s.breakMinutes, DEFAULTS.breakMinutes, true) : DEFAULTS.breakMinutes
  var brk = st.breakMinutes !== undefined ? minutes(st.breakMinutes, baseBreak, true) : baseBreak

  var baseLongBreak = s.longBreakMinutes !== undefined ? minutes(s.longBreakMinutes, DEFAULTS.longBreakMinutes, true) : DEFAULTS.longBreakMinutes
  var longBrk = st.longBreakMinutes !== undefined ? minutes(st.longBreakMinutes, baseLongBreak, true) : baseLongBreak

  return {
    workMinutes: work,
    breakMinutes: brk,
    longBreakMinutes: longBrk,
    cyclesPerLong: isFinite(cycles) && cycles >= 1 && cycles <= 12 ? Math.floor(cycles) : DEFAULTS.cyclesPerLong,
    autoDnd: st.autoDnd !== undefined ? st.autoDnd === true : (s.autoDnd === false ? false : DEFAULTS.autoDnd)
  }
}

function phaseDurationMs(phase, config) {
  if (phase === "work") return config.workMinutes * 60000
  if (phase === "break") return config.breakMinutes * 60000
  if (phase === "longBreak") return config.longBreakMinutes * 60000
  return 0
}

// The phase that follows a completed one. Completing work increments the
// cycle; every cyclesPerLong-th work earns the long break.
function nextPhase(completedPhase, cycleCountAfter, config) {
  if (completedPhase === "work") {
    var isLong = cycleCountAfter % config.cyclesPerLong === 0
    if (isLong && config.longBreakMinutes > 0) return "longBreak"
    if (!isLong && config.breakMinutes > 0) return "break"
    if (isLong && config.breakMinutes > 0) return "break"
    return "work"
  }
  return "work"
}

function dayKey(nowMs) {
  var d = new Date(Number(nowMs))
  var pad = function (n) { return n < 10 ? "0" + n : String(n) }
  return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate())
}

// Roll the daily counter when the date changes; harmless on same-day calls.
function withToday(state, nowMs) {
  var key = dayKey(nowMs)
  if (state.todayDate === key) return state
  var next = cloneState(state)
  if (state.todayDate && state.todayCount > 0) {
    if (!next.history) next.history = {}
    next.history[state.todayDate] = state.todayCount
  }
  next.todayDate = key
  next.todayCount = (next.history && next.history[key]) || 0
  return next
}

function cloneState(state) {
  var next = {
    phase: state.phase,
    endsAtMs: state.endsAtMs,
    pausedRemainingMs: state.pausedRemainingMs,
    cycleCount: state.cycleCount,
    todayCount: state.todayCount,
    todayDate: state.todayDate,
    dndWasOn: state.dndWasOn === true,
    history: state.history ? Object.assign({}, state.history) : {}
  }
  if (state.workMinutes !== undefined) next.workMinutes = state.workMinutes
  if (state.breakMinutes !== undefined) next.breakMinutes = state.breakMinutes
  if (state.longBreakMinutes !== undefined) next.longBreakMinutes = state.longBreakMinutes
  if (state.autoDnd !== undefined) next.autoDnd = state.autoDnd
  return next
}

function setTodayCount(state, count, nowMs) {
  var next = withToday(state, nowMs)
  next.todayCount = Math.max(0, Math.floor(Number(count) || 0))
  if (!next.history) next.history = {}
  next.history[next.todayDate] = next.todayCount
  return next
}

function adjustTodayCount(state, delta, nowMs) {
  var cur = Number(state.todayCount) || 0
  return setTodayCount(state, cur + delta, nowMs)
}

// Start a phase now.
function startPhase(state, phase, nowMs, config) {
  var next = withToday(state, nowMs)
  next.phase = phase
  next.endsAtMs = Number(nowMs) + phaseDurationMs(phase, config)
  next.pausedRemainingMs = 0
  return next
}

function pause(state, nowMs) {
  if (state.phase === "idle" || state.pausedRemainingMs > 0) return state
  var next = cloneState(state)
  next.pausedRemainingMs = Math.max(1, state.endsAtMs - Number(nowMs))
  next.endsAtMs = 0
  return next
}

function resume(state, nowMs) {
  if (state.phase === "idle" || state.pausedRemainingMs <= 0) return state
  var next = cloneState(state)
  next.endsAtMs = Number(nowMs) + state.pausedRemainingMs
  next.pausedRemainingMs = 0
  return next
}

function isPaused(state) {
  return state.phase !== "idle" && state.pausedRemainingMs > 0
}

function remainingMs(state, nowMs) {
  if (state.phase === "idle") return 0
  if (isPaused(state)) return state.pausedRemainingMs
  return Math.max(0, state.endsAtMs - Number(nowMs))
}

// Advance past a completed phase. Returns the new state; the caller reads
// state.phase to decide side effects (DND, notification).
function completePhase(state, nowMs, config) {
  var next = withToday(state, nowMs)
  if (next.phase === "idle") return next
  if (next.phase === "work") {
    next.cycleCount = next.cycleCount + 1
    next.todayCount = next.todayCount + 1
    if (!next.history) next.history = {}
    next.history[next.todayDate] = next.todayCount
  }
  var following = nextPhase(next.phase, next.cycleCount, config)
  return startPhase(next, following, nowMs, config)
}

// Reconcile persisted state against the wall clock after a load: a running
// phase whose end passed while we were away completes (possibly several
// times), so the chip never resurrects a stale countdown.
function resolveState(state, nowMs, config) {
  var next = withToday(state, nowMs)
  var guard = 0
  while (next.phase !== "idle" && !isPaused(next)
      && next.endsAtMs > 0 && next.endsAtMs <= Number(nowMs) && guard < 64) {
    next = completePhase(next, next.endsAtMs, config)
    guard += 1
  }
  return next
}

// Validated parse of the state file; anything malformed is a fresh idle.
function parseState(text) {
  var parsed = null
  if (typeof text === "string" && text.length > 0) {
    try { parsed = JSON.parse(text) } catch (error) { parsed = null }
  }
  if (parsed === null || typeof parsed !== "object" || Array.isArray(parsed)) return idleState()
  var state = idleState()
  if (PHASES.indexOf(parsed.phase) !== -1) state.phase = parsed.phase
  var numbers = ["endsAtMs", "pausedRemainingMs", "cycleCount", "todayCount"]
  for (var i = 0; i < numbers.length; i++) {
    var value = Number(parsed[numbers[i]])
    if (isFinite(value) && value >= 0) state[numbers[i]] = value
  }
  if (typeof parsed.todayDate === "string") state.todayDate = parsed.todayDate
  state.dndWasOn = parsed.dndWasOn === true
  if (parsed.history && typeof parsed.history === "object" && !Array.isArray(parsed.history)) {
    state.history = parsed.history
  }
  if (isFinite(Number(parsed.workMinutes)) && Number(parsed.workMinutes) >= 1) {
    state.workMinutes = Math.floor(Number(parsed.workMinutes))
  }
  if (isFinite(Number(parsed.breakMinutes)) && Number(parsed.breakMinutes) >= 0) {
    state.breakMinutes = Math.floor(Number(parsed.breakMinutes))
  }
  if (isFinite(Number(parsed.longBreakMinutes)) && Number(parsed.longBreakMinutes) >= 0) {
    state.longBreakMinutes = Math.floor(Number(parsed.longBreakMinutes))
  }
  if (parsed.autoDnd !== undefined) {
    state.autoDnd = parsed.autoDnd === true
  }
  return state
}

function serializeState(state) {
  var obj = {
    phase: state.phase,
    endsAtMs: state.endsAtMs,
    pausedRemainingMs: state.pausedRemainingMs,
    cycleCount: state.cycleCount,
    todayCount: state.todayCount,
    todayDate: state.todayDate,
    dndWasOn: state.dndWasOn === true,
    history: state.history || {}
  }
  if (state.workMinutes !== undefined) obj.workMinutes = state.workMinutes
  if (state.breakMinutes !== undefined) obj.breakMinutes = state.breakMinutes
  if (state.longBreakMinutes !== undefined) obj.longBreakMinutes = state.longBreakMinutes
  if (state.autoDnd !== undefined) obj.autoDnd = state.autoDnd
  return JSON.stringify(obj, null, 2) + "\n"
}

function statePath(xdgStateHome, home) {
  var base = typeof xdgStateHome === "string" && xdgStateHome.trim().length > 0
    ? xdgStateHome.trim()
    : String(home == null ? "" : home) + "/.local/state"
  return base + "/omarchy/pomodoro.json"
}

function formatRemaining(ms) {
  var total = Math.ceil(Math.max(0, Number(ms)) / 1000)
  var minutes = Math.floor(total / 60)
  var seconds = total % 60
  return minutes + ":" + (seconds < 10 ? "0" + seconds : String(seconds))
}

function glyphFor(phase) {
  if (phase === "work") return "󰔟"
  if (phase === "break" || phase === "longBreak") return "󰅶"
  return "󱎫"
}

function labelFor(phase) {
  if (phase === "work") return "Focus"
  if (phase === "break") return "Break"
  if (phase === "longBreak") return "Long break"
  return "Pomodoro"
}

if (typeof module !== "undefined") {
  module.exports = {
    PHASES: PHASES,
    DEFAULTS: DEFAULTS,
    idleState: idleState,
    readConfig: readConfig,
    phaseDurationMs: phaseDurationMs,
    nextPhase: nextPhase,
    dayKey: dayKey,
    startPhase: startPhase,
    pause: pause,
    resume: resume,
    isPaused: isPaused,
    remainingMs: remainingMs,
    completePhase: completePhase,
    resolveState: resolveState,
    parseState: parseState,
    serializeState: serializeState,
    statePath: statePath,
    formatRemaining: formatRemaining,
    glyphFor: glyphFor,
    labelFor: labelFor,
    setTodayCount: setTodayCount,
    adjustTodayCount: adjustTodayCount,
    cloneState: cloneState
  }
}
