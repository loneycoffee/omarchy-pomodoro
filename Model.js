.pragma library

// Pure helpers for the Pomodoro plugin: defaults, state normalization, time
// formatting, the "finish at" estimate, the report, and the theme palette.
// Nothing here touches QML objects, so the service and every bar instance
// share one definition of how the timer behaves.

var MODES = ["pomodoro", "short", "long"]

var MODE_LABELS = {
  pomodoro: "Pomodoro",
  short: "Short Break",
  long: "Long Break"
}

// Material Design glyphs from the Nerd Font every Omarchy theme ships. Kept
// as code points so the source survives editors that mangle private-use
// characters.
var GLYPHS = {
  pomodoro: 0xf051b,  // md-timer_outline
  short: 0xf0176,     // md-coffee
  long: 0xf0092,      // md-beach
  play: 0xf040a,
  pause: 0xf03e4,
  skip: 0xf04ad,
  reset: 0xf0450,
  settings: 0xf08bb,  // md-cog_outline
  report: 0xf0128,    // md-chart_bar
  back: 0xf004d,
  check: 0xf05e0,     // md-check_circle
  unchecked: 0xf0130, // md-checkbox_blank_circle_outline
  more: 0xf01d9,      // md-dots_vertical
  plus: 0xf0415,
  minus: 0xf0374,
  edit: 0xf03eb,
  remove: 0xf09e7,    // md-delete_outline
  note: 0xf11d7,
  close: 0xf0156,
  up: 0xf0143,
  down: 0xf0140
}

function glyph(name) {
  var cp = GLYPHS[name]
  return cp ? String.fromCodePoint(cp) : ""
}

function modeLabel(mode) {
  return MODE_LABELS[mode] || MODE_LABELS.pomodoro
}

var ALARM_SOUNDS = [
  { value: "bell", label: "Bell" },
  { value: "kitchen", label: "Kitchen" },
  { value: "digital", label: "Digital" },
  { value: "chime", label: "Chime" },
  { value: "wood", label: "Wood" },
  { value: "none", label: "None" }
]

var TICKING_SOUNDS = [
  { value: "none", label: "None" },
  { value: "tick-slow", label: "Ticking Slow" },
  { value: "tick-fast", label: "Ticking Fast" },
  { value: "noise-white", label: "White Noise" },
  { value: "noise-brown", label: "Brown Noise" }
]

function alarmFile(name) {
  return name && name !== "none" ? "sounds/alarm-" + name + ".wav" : ""
}

function tickingFile(name) {
  return name && name !== "none" ? "sounds/" + name + ".wav" : ""
}

// ------------------------------------------------------------------ defaults

function uid() {
  return Date.now().toString(36) + Math.random().toString(36).slice(2, 8)
}

function makeProfile(name, pomodoro, shortBreak, longBreak, interval) {
  return {
    id: uid(),
    name: name,
    pomodoro: pomodoro,
    short: shortBreak,
    long: longBreak,
    longInterval: interval,
    autoStartBreaks: false,
    autoStartPomodoros: false
  }
}

function defaultProfiles() {
  var classic = makeProfile("Classic", 25, 5, 15, 4)
  var deep = makeProfile("Deep Work", 50, 10, 30, 3)
  return [classic, deep]
}

function defaultSettings() {
  return {
    autoCheckTasks: false,
    autoSwitchTasks: true,
    alarmSound: "bell",
    alarmVolume: 60,
    alarmRepeat: 1,
    tickingSound: "none",
    tickingVolume: 40,
    notifications: true,
    reminderMinutes: 0,
    hourFormat: "24",
    colorStyle: "palette",
    barLabel: "active"
  }
}

function defaultState() {
  var profiles = defaultProfiles()
  return {
    version: 1,
    mode: "pomodoro",
    running: false,
    endsAt: 0,
    pausedRemaining: -1,
    roundTotal: 0,
    segmentStartedAt: 0,
    pomoCount: 0,
    reminded: false,
    tasks: [],
    activeTaskId: "",
    profiles: profiles,
    activeProfileId: profiles[0].id,
    settings: defaultSettings(),
    history: {}
  }
}

function clampInt(value, min, max, fallback) {
  var n = parseInt(value, 10)
  if (!isFinite(n)) return fallback
  return Math.max(min, Math.min(max, n))
}

function normalizeProfile(p, fallback) {
  var base = fallback || makeProfile("Profile", 25, 5, 15, 4)
  if (!p || typeof p !== "object") return base
  return {
    id: typeof p.id === "string" && p.id ? p.id : uid(),
    name: typeof p.name === "string" && p.name.trim() ? p.name.trim() : base.name,
    pomodoro: clampInt(p.pomodoro, 1, 240, base.pomodoro),
    short: clampInt(p.short, 1, 120, base.short),
    long: clampInt(p.long, 1, 180, base.long),
    longInterval: clampInt(p.longInterval, 1, 12, base.longInterval),
    autoStartBreaks: p.autoStartBreaks === true,
    autoStartPomodoros: p.autoStartPomodoros === true
  }
}

function normalizeTask(t) {
  if (!t || typeof t !== "object") return null
  var title = typeof t.title === "string" ? t.title.trim() : ""
  if (!title) return null
  return {
    id: typeof t.id === "string" && t.id ? t.id : uid(),
    title: title,
    note: typeof t.note === "string" ? t.note : "",
    est: clampInt(t.est, 1, 99, 1),
    act: clampInt(t.act, 0, 999, 0),
    done: t.done === true
  }
}

function pickOption(value, options, fallback) {
  for (var i = 0; i < options.length; i++)
    if (options[i].value === value) return value
  return fallback
}

function normalizeSettings(s) {
  var d = defaultSettings()
  if (!s || typeof s !== "object") return d
  return {
    autoCheckTasks: typeof s.autoCheckTasks === "boolean" ? s.autoCheckTasks : d.autoCheckTasks,
    autoSwitchTasks: typeof s.autoSwitchTasks === "boolean" ? s.autoSwitchTasks : d.autoSwitchTasks,
    alarmSound: pickOption(s.alarmSound, ALARM_SOUNDS, d.alarmSound),
    alarmVolume: clampInt(s.alarmVolume, 0, 100, d.alarmVolume),
    alarmRepeat: clampInt(s.alarmRepeat, 1, 10, d.alarmRepeat),
    tickingSound: pickOption(s.tickingSound, TICKING_SOUNDS, d.tickingSound),
    tickingVolume: clampInt(s.tickingVolume, 0, 100, d.tickingVolume),
    notifications: typeof s.notifications === "boolean" ? s.notifications : d.notifications,
    reminderMinutes: clampInt(s.reminderMinutes, 0, 60, d.reminderMinutes),
    hourFormat: s.hourFormat === "12" ? "12" : "24",
    colorStyle: s.colorStyle === "accent" ? "accent" : "palette",
    barLabel: (s.barLabel === "always" || s.barLabel === "icon") ? s.barLabel : "active"
  }
}

// Accepts whatever was on disk and returns a complete, valid state. Unknown
// keys are dropped; anything malformed falls back to its default rather than
// taking the whole file down with it.
function normalizeState(raw) {
  var d = defaultState()
  var s = raw
  if (typeof raw === "string") {
    try { s = JSON.parse(raw) } catch (e) { s = null }
  }
  if (!s || typeof s !== "object") return d

  var profiles = []
  if (Array.isArray(s.profiles)) {
    for (var i = 0; i < s.profiles.length; i++) profiles.push(normalizeProfile(s.profiles[i]))
  }
  if (profiles.length === 0) profiles = d.profiles
  var activeProfileId = profiles[0].id
  for (var j = 0; j < profiles.length; j++)
    if (profiles[j].id === s.activeProfileId) activeProfileId = s.activeProfileId

  var tasks = []
  if (Array.isArray(s.tasks)) {
    for (var k = 0; k < s.tasks.length; k++) {
      var t = normalizeTask(s.tasks[k])
      if (t) tasks.push(t)
    }
  }
  var activeTaskId = ""
  for (var m = 0; m < tasks.length; m++)
    if (tasks[m].id === s.activeTaskId) activeTaskId = s.activeTaskId

  var history = {}
  if (s.history && typeof s.history === "object") {
    for (var key in s.history) {
      if (!/^\d{4}-\d{2}-\d{2}$/.test(key)) continue
      var h = s.history[key] || {}
      history[key] = {
        focus: Math.max(0, Number(h.focus) || 0),
        pomos: clampInt(h.pomos, 0, 10000, 0)
      }
    }
  }

  var mode = MODES.indexOf(s.mode) >= 0 ? s.mode : "pomodoro"
  var running = s.running === true && Number(s.endsAt) > 0
  return {
    version: 1,
    mode: mode,
    running: running,
    endsAt: running ? Number(s.endsAt) : 0,
    pausedRemaining: running ? -1 : (Number(s.pausedRemaining) > 0 ? Number(s.pausedRemaining) : -1),
    roundTotal: Math.max(0, Number(s.roundTotal) || 0),
    segmentStartedAt: running ? Math.max(0, Number(s.segmentStartedAt) || 0) : 0,
    pomoCount: clampInt(s.pomoCount, 0, 100000, 0),
    reminded: s.reminded === true,
    tasks: tasks,
    activeTaskId: activeTaskId,
    profiles: profiles,
    activeProfileId: activeProfileId,
    settings: normalizeSettings(s.settings),
    history: history
  }
}

function cloneJson(value) {
  return JSON.parse(JSON.stringify(value))
}

// ---------------------------------------------------------------- time math

function durationMs(profile, mode) {
  var p = profile || {}
  var minutes = mode === "short" ? p.short : (mode === "long" ? p.long : p.pomodoro)
  return Math.max(1, Number(minutes) || 1) * 60000
}

// Minutes keep counting past 59 (90:00, not 1:30:00), as on pomofocus.io.
function formatClock(ms) {
  var total = Math.max(0, Math.ceil(ms / 1000))
  var minutes = Math.floor(total / 60)
  var seconds = total % 60
  return (minutes < 10 ? "0" : "") + minutes + ":" + (seconds < 10 ? "0" : "") + seconds
}

function pad2(n) {
  return (n < 10 ? "0" : "") + n
}

function dayKey(date) {
  var d = date || new Date()
  return d.getFullYear() + "-" + pad2(d.getMonth() + 1) + "-" + pad2(d.getDate())
}

function formatHourMinute(date, hourFormat) {
  var h = date.getHours()
  var m = pad2(date.getMinutes())
  if (hourFormat === "12") {
    var suffix = h < 12 ? "am" : "pm"
    var h12 = h % 12
    if (h12 === 0) h12 = 12
    return h12 + ":" + m + suffix
  }
  return pad2(h) + ":" + m
}

// The mode that follows a finished pomodoro, given how many are done now.
function breakAfter(pomoCount, interval) {
  var n = Math.max(1, interval || 4)
  return pomoCount > 0 && pomoCount % n === 0 ? "long" : "short"
}

// "Pomos: act/est" and "Finish At" for the task list footer. The estimate
// walks the pomodoros still owed by unchecked tasks, alternating with the
// breaks the profile will insert between them, starting from where the
// current round actually is.
function taskSummary(tasks, profile, mode, remainingMs, pomoCount, nowMs) {
  var act = 0, est = 0, owed = 0
  for (var i = 0; i < tasks.length; i++) {
    act += tasks[i].act
    est += tasks[i].est
    if (!tasks[i].done) owed += Math.max(0, tasks[i].est - tasks[i].act)
  }

  var ms = 0
  var count = pomoCount
  var left = owed
  if (left > 0) {
    if (mode === "pomodoro") {
      ms += remainingMs
      left--
      count++
      if (left > 0) ms += durationMs(profile, breakAfter(count, profile.longInterval))
    } else {
      ms += remainingMs
    }
    while (left > 0) {
      ms += durationMs(profile, "pomodoro")
      left--
      count++
      if (left > 0) ms += durationMs(profile, breakAfter(count, profile.longInterval))
    }
  }

  return {
    act: act,
    est: est,
    owed: owed,
    finishAt: nowMs + ms,
    hours: ms / 3600000
  }
}

// --------------------------------------------------------------- the report

function report(history, now) {
  var today = now || new Date()
  var totalFocus = 0
  var days = 0
  for (var key in history) {
    var h = history[key]
    totalFocus += h.focus
    if (h.focus > 0 || h.pomos > 0) days++
  }

  // A streak still counts today before the first pomodoro of the day; it is
  // broken only by a whole day with nothing in it.
  var streak = 0
  var cursor = new Date(today.getFullYear(), today.getMonth(), today.getDate())
  var first = history[dayKey(cursor)]
  if (!first || (first.focus <= 0 && first.pomos <= 0)) cursor.setDate(cursor.getDate() - 1)
  for (;;) {
    var entry = history[dayKey(cursor)]
    if (!entry || (entry.focus <= 0 && entry.pomos <= 0)) break
    streak++
    cursor.setDate(cursor.getDate() - 1)
  }

  var week = []
  var names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
  for (var i = 6; i >= 0; i--) {
    var d = new Date(today.getFullYear(), today.getMonth(), today.getDate() - i)
    var e = history[dayKey(d)] || { focus: 0, pomos: 0 }
    week.push({
      key: dayKey(d),
      label: i === 0 ? "Today" : names[d.getDay()],
      minutes: Math.round(e.focus / 60),
      pomos: e.pomos
    })
  }
  var todayEntry = history[dayKey(today)] || { focus: 0, pomos: 0 }

  return {
    hours: totalFocus / 3600,
    days: days,
    streak: streak,
    week: week,
    todayMinutes: Math.round(todayEntry.focus / 60),
    todayPomos: todayEntry.pomos
  }
}

function formatMinutes(minutes) {
  if (minutes < 60) return minutes + "m"
  var h = Math.floor(minutes / 60)
  var m = minutes % 60
  return h + "h" + (m > 0 ? " " + pad2(m) + "m" : "")
}

// ------------------------------------------------------------ theme palette

// The named colors a theme's colors.toml defines (red, cyan, blue, ...), with
// the terminal slots as fallback for themes that only ship color0..color15.
function parsePalette(raw) {
  var named = {}
  var lines = String(raw || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    var match = lines[i].match(/^\s*([A-Za-z0-9_-]+)\s*=\s*["']?(#[0-9A-Fa-f]{6})/)
    if (match) named[match[1]] = match[2]
  }
  function pick(names) {
    for (var j = 0; j < names.length; j++) if (named[names[j]]) return named[names[j]]
    return ""
  }
  return {
    red: pick(["red", "color1", "bright_red", "color9"]),
    green: pick(["green", "color2"]),
    yellow: pick(["yellow", "color3"]),
    blue: pick(["blue", "color4", "bright_blue", "color12"]),
    cyan: pick(["cyan", "color6", "bright_cyan", "color14"]),
    magenta: pick(["magenta", "color5"])
  }
}
