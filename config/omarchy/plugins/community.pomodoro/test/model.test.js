const assert = require('node:assert/strict')
const model = require('../model/PomodoroModel.js')

const config = model.readConfig({})
const T0 = Date.parse('2026-08-02T10:00:00')

// ---- config validation ------------------------------------------------------

assert.deepEqual(config, {
  workMinutes: 20, breakMinutes: 0, longBreakMinutes: 0, cyclesPerLong: 4, autoDnd: true
})
assert.equal(model.readConfig({ workMinutes: 50 }).workMinutes, 50)
assert.equal(model.readConfig({ workMinutes: 0 }).workMinutes, 20, 'zero workMinutes is invalid')
assert.equal(model.readConfig({ workMinutes: 'x' }).workMinutes, 20)
assert.equal(model.readConfig({ breakMinutes: 0 }).breakMinutes, 0, 'zero break is valid')
assert.equal(model.readConfig({ breakMinutes: 5 }).breakMinutes, 5)
assert.equal(model.readConfig({ breakMinutes: -1 }).breakMinutes, 0, 'negative is invalid')
assert.equal(model.readConfig({ longBreakMinutes: 0 }).longBreakMinutes, 0, 'zero longBreak is valid')
assert.equal(model.readConfig({ cyclesPerLong: 99 }).cyclesPerLong, 4, 'out of range')
assert.equal(model.readConfig({ autoDnd: false }).autoDnd, false)

// ---- session flow (standard with breaks) ------------------------------------

const standardConfig = model.readConfig({
  workMinutes: 25, breakMinutes: 5, longBreakMinutes: 15, cyclesPerLong: 4
})

let s = model.startPhase(model.idleState(), 'work', T0, standardConfig)
assert.equal(s.phase, 'work')
assert.equal(model.remainingMs(s, T0), 25 * 60000)
assert.equal(model.remainingMs(s, T0 + 60000), 24 * 60000)
assert.equal(model.formatRemaining(model.remainingMs(s, T0 + 60000)), '24:00')
assert.equal(model.formatRemaining(model.remainingMs(s, T0 + 61000)), '23:59')
assert.equal(model.formatRemaining(model.remainingMs(s, T0)), '25:00')

// Pause freezes the remainder; resume restores it against the new clock.
s = model.pause(s, T0 + 5 * 60000)
assert.equal(model.isPaused(s), true)
assert.equal(model.remainingMs(s, T0 + 60 * 60000), 20 * 60000, 'paused time does not drain')
s = model.resume(s, T0 + 60 * 60000)
assert.equal(model.isPaused(s), false)
assert.equal(model.remainingMs(s, T0 + 60 * 60000), 20 * 60000)

// Completing work increments cycle and today, then starts the break.
s = model.startPhase(model.idleState(), 'work', T0, standardConfig)
s = model.completePhase(s, T0 + 25 * 60000, standardConfig)
assert.equal(s.phase, 'break')
assert.equal(s.cycleCount, 1)
assert.equal(s.todayCount, 1)

// Every fourth work earns the long break.
let s4 = model.idleState()
for (let i = 0; i < 4; i++) {
  s4 = model.startPhase(s4, 'work', T0, standardConfig)
  s4 = model.completePhase(s4, T0 + 1000, standardConfig)
  if (i < 3) {
    assert.equal(s4.phase, 'break', `cycle ${i + 1} takes a short break`)
    s4 = model.completePhase(s4, T0 + 2000, standardConfig)
    assert.equal(s4.phase, 'work')
  }
}
assert.equal(s4.phase, 'longBreak')
assert.equal(s4.todayCount, 4)

// Breaks do not increment counters.
const afterBreak = model.completePhase(s4, T0 + 3000, standardConfig)
assert.equal(afterBreak.phase, 'work')
assert.equal(afterBreak.todayCount, 4)

// ---- session flow (no-breaks / back-to-back work) ---------------------------

let snb = model.startPhase(model.idleState(), 'work', T0, config)
assert.equal(snb.phase, 'work')
assert.equal(model.remainingMs(snb, T0), 20 * 60000)
snb = model.completePhase(snb, T0 + 20 * 60000, config)
assert.equal(snb.phase, 'work', 'completing work immediately starts next work')
assert.equal(snb.cycleCount, 1)
assert.equal(snb.todayCount, 1)
assert.equal(model.remainingMs(snb, T0 + 20 * 60000), 20 * 60000)

// ---- restart reconciliation -------------------------------------------------

// A work session that fully elapsed while the shell was down completes into
// its break, and the counters advance exactly once.
s = model.startPhase(model.idleState(), 'work', T0, standardConfig)
let resolved = model.resolveState(s, T0 + 26 * 60000, standardConfig)
assert.equal(resolved.phase, 'break')
assert.equal(resolved.todayCount, 1)
assert.equal(model.remainingMs(resolved, T0 + 26 * 60000), 4 * 60000,
  'the break started when the work actually ended')

// Under no-breaks mode, an elapsed work session seamlessly advances to the next work session.
let snbElapsed = model.startPhase(model.idleState(), 'work', T0, config)
let resolvedNb = model.resolveState(snbElapsed, T0 + 25 * 60000, config)
assert.equal(resolvedNb.phase, 'work')
assert.equal(resolvedNb.todayCount, 1)
assert.equal(model.remainingMs(resolvedNb, T0 + 25 * 60000), 15 * 60000,
  'the 2nd work started when the 1st ended')

// Long absence chains through several phases without runaway.
resolved = model.resolveState(s, T0 + 3 * 60 * 60000, config)
assert.notEqual(resolved.phase, 'idle')
assert.ok(resolved.cycleCount >= 3, 'multiple cycles completed while away')

// A paused session never advances.
s = model.pause(model.startPhase(model.idleState(), 'work', T0, config), T0 + 1000)
resolved = model.resolveState(s, T0 + 9 * 60 * 60000, config)
assert.equal(model.isPaused(resolved), true)

// The daily counter resets on a new day.
s = model.startPhase(model.idleState(), 'work', T0, config)
s = model.completePhase(s, T0 + 1000, config)
assert.equal(s.todayCount, 1)
const nextDay = model.withTodayTest ? null : model.resolveState(
  model.startPhase(s, 'work', T0 + 24 * 60 * 60000, config),
  T0 + 24 * 60 * 60000 + 1, config)
assert.equal(nextDay.todayCount, 0, 'a new day starts the counter fresh')

// ---- persistence ------------------------------------------------------------

const roundTrip = model.parseState(model.serializeState(s4))
assert.deepEqual(roundTrip, s4)
for (const bad of [null, '', 'not json', '[]', '{"phase":"nap"}']) {
  assert.equal(model.parseState(bad).phase, 'idle', `${JSON.stringify(bad)} is a fresh idle`)
}
assert.equal(model.parseState('{"phase":"work","endsAtMs":-5}').endsAtMs, 0,
  'negative numbers are rejected')

assert.equal(model.statePath(null, '/home/u'), '/home/u/.local/state/omarchy/pomodoro.json')
assert.equal(model.statePath('/custom', '/home/u'), '/custom/omarchy/pomodoro.json')

// ---- display helpers --------------------------------------------------------

assert.equal(model.formatRemaining(0), '0:00')
assert.equal(model.formatRemaining(61000), '1:01')
assert.ok(model.glyphFor('work').length > 0)
// ---- interactive manual count adjustments ---------------------------------

let adjState = model.idleState()
adjState = model.adjustTodayCount(adjState, 1, T0)
assert.equal(adjState.todayCount, 1)
adjState = model.adjustTodayCount(adjState, 2, T0)
assert.equal(adjState.todayCount, 3)
adjState = model.adjustTodayCount(adjState, -1, T0)
assert.equal(adjState.todayCount, 2)
adjState = model.setTodayCount(adjState, 0, T0)
assert.equal(adjState.todayCount, 0)

console.log('ok - pomodoro model')
