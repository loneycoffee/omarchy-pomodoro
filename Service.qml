import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model

// The Pomodoro engine, mounted once for the shell.
//
// Omarchy builds one bar per monitor, so the timer cannot live on the widget:
// two screens would run two clocks. Everything stateful lives here and the
// bar widgets only render it and call in.
//
// The round is stored as an absolute end time rather than a countdown, so
// suspend, a plugin hot-reload or a shell restart cannot make it drift; the
// file under ~/.local/state is re-read on load and the round picks up where
// the wall clock says it is.
Item {
  id: root
  width: 0
  height: 0
  visible: false

  // Host injection.
  property var shell: null
  property var manifest: null
  property string omarchyPath: ""

  readonly property string pluginId: "loneycoffee.pomodoro"
  readonly property string home: Quickshell.env("HOME")
  readonly property string pluginDir: Qt.resolvedUrl(".").toString().replace(/^file:\/\//, "")
  readonly property string stateDir: home + "/.local/state/omarchy/plugins/" + pluginId
  readonly property string statePath: stateDir + "/state.json"
  readonly property string soundScript: pluginDir + "bin/pomodoro-sound"

  // ------------------------------------------------------------------ state

  property bool loaded: false
  property var st: Model.defaultState()
  property double now: Date.now()

  readonly property string mode: st.mode
  readonly property bool running: st.running
  readonly property var tasks: st.tasks
  readonly property var settings: st.settings
  readonly property var profiles: st.profiles
  readonly property int pomoCount: st.pomoCount
  readonly property string activeTaskId: st.activeTaskId
  readonly property var history: st.history

  readonly property var profile: {
    for (var i = 0; i < st.profiles.length; i++)
      if (st.profiles[i].id === st.activeProfileId) return st.profiles[i]
    return st.profiles[0]
  }

  readonly property var activeTask: {
    for (var i = 0; i < st.tasks.length; i++)
      if (st.tasks[i].id === st.activeTaskId) return st.tasks[i]
    return null
  }

  readonly property double fullMs: Model.durationMs(profile, mode)
  readonly property bool paused: !running && st.pausedRemaining > 0
  readonly property bool active: running || paused
  readonly property double totalMs: active && st.roundTotal > 0 ? st.roundTotal : fullMs
  readonly property double remainingMs: running
    ? Math.max(0, st.endsAt - now)
    : (st.pausedRemaining > 0 ? st.pausedRemaining : fullMs)
  readonly property real progress: totalMs > 0 ? Math.max(0, Math.min(1, 1 - remainingMs / totalMs)) : 0
  readonly property string clockText: Model.formatClock(remainingMs)

  // Focus seconds of the segment running now, not yet credited to history.
  readonly property double liveFocusSeconds: running && mode === "pomodoro" && st.segmentStartedAt > 0
    ? Math.max(0, (Math.min(now, st.endsAt) - st.segmentStartedAt) / 1000) : 0

  // The palette of the current Omarchy theme. Read here so every bar shares
  // one copy, and re-read whenever `omarchy theme set` rewrites theme.name.
  property var palette: Model.parsePalette("")

  signal roundFinished(string finishedMode, string nextMode)
  // Asks the bar panels to show a view (main | settings | report).
  signal viewRequested(string view)

  // -------------------------------------------------------------- mutation

  // State is replaced, never edited in place, so every binding on `st`
  // re-evaluates. The objects are small; a copy per user action is nothing.
  function mutate(fn) {
    var next = Model.cloneJson(root.st)
    fn(next)
    root.st = next
    root.scheduleSave()
  }

  function findProfile(s) {
    for (var i = 0; i < s.profiles.length; i++)
      if (s.profiles[i].id === s.activeProfileId) return s.profiles[i]
    return s.profiles[0]
  }

  function findTaskIndex(s, id) {
    for (var i = 0; i < s.tasks.length; i++)
      if (s.tasks[i].id === id) return i
    return -1
  }

  // Credit the focus time of the segment that is ending to today's report.
  // Only pomodoro time counts, and never past the round's own end.
  function creditFocus(s, untilMs) {
    if (s.mode !== "pomodoro" || !s.running || !(s.segmentStartedAt > 0)) return
    var end = Math.min(untilMs, s.endsAt)
    var seconds = Math.max(0, (end - s.segmentStartedAt) / 1000)
    if (seconds <= 0) return
    var key = Model.dayKey(new Date(end))
    var day = s.history[key] || { focus: 0, pomos: 0 }
    day.focus = Math.round((day.focus + seconds) * 10) / 10
    s.history[key] = day
  }

  function clearRound(s) {
    s.running = false
    s.endsAt = 0
    s.pausedRemaining = -1
    s.roundTotal = 0
    s.segmentStartedAt = 0
    s.reminded = false
  }

  function beginRound(s, remaining, total) {
    var t = Date.now()
    s.running = true
    s.endsAt = t + remaining
    s.pausedRemaining = -1
    s.roundTotal = total
    s.segmentStartedAt = t
  }

  function selectNextOpenTask(s, afterIndex) {
    var n = s.tasks.length
    for (var k = 1; k <= n; k++) {
      var t = s.tasks[(afterIndex + k) % n]
      if (!t.done) { s.activeTaskId = t.id; return }
    }
    s.activeTaskId = ""
  }

  // ----------------------------------------------------------------- timer

  function start() {
    if (!root.loaded || root.running) return
    var fresh = !(root.st.pausedRemaining > 0)
    var full = root.fullMs
    mutate(function(s) {
      if (fresh) beginRound(s, full, full)
      else beginRound(s, s.pausedRemaining, s.roundTotal > 0 ? s.roundTotal : full)
      if (fresh) s.reminded = false
    })
    root.now = Date.now()
  }

  function pause() {
    if (!root.running) return
    var t = Date.now()
    mutate(function(s) {
      creditFocus(s, t)
      var remaining = Math.max(1000, s.endsAt - t)
      s.running = false
      s.endsAt = 0
      s.segmentStartedAt = 0
      s.pausedRemaining = remaining
    })
  }

  function toggleTimer() {
    if (root.running) root.pause()
    else root.start()
  }

  function reset() {
    var t = Date.now()
    mutate(function(s) {
      creditFocus(s, t)
      clearRound(s)
    })
  }

  function setMode(m) {
    if (Model.MODES.indexOf(m) < 0) return
    var t = Date.now()
    mutate(function(s) {
      creditFocus(s, t)
      clearRound(s)
      s.mode = m
    })
  }

  // Finish the round now. `early` is the skip button: the round still counts
  // toward the pomodoro number and the task, as on pomofocus.io, but only the
  // minutes actually spent go into the report, and no alarm rings.
  function complete(early, quiet) {
    var t = Date.now()
    var finished = root.st.mode
    var next = "pomodoro"
    var autoStart = false
    var taskTitle = ""
    mutate(function(s) {
      creditFocus(s, t)
      var p = findProfile(s)
      if (s.mode === "pomodoro") {
        s.pomoCount += 1
        var key = Model.dayKey(new Date(Math.min(t, s.endsAt > 0 ? s.endsAt : t)))
        var day = s.history[key] || { focus: 0, pomos: 0 }
        day.pomos += 1
        s.history[key] = day

        var idx = findTaskIndex(s, s.activeTaskId)
        if (idx >= 0 && !s.tasks[idx].done) {
          var task = s.tasks[idx]
          task.act += 1
          if (s.settings.autoCheckTasks && task.act >= task.est) {
            task.done = true
            if (s.settings.autoSwitchTasks) selectNextOpenTask(s, idx)
          }
        }
        next = Model.breakAfter(s.pomoCount, p.longInterval)
        autoStart = p.autoStartBreaks
      } else {
        next = "pomodoro"
        autoStart = p.autoStartPomodoros
      }
      clearRound(s)
      s.mode = next
      if (autoStart) {
        var full = Model.durationMs(p, next)
        beginRound(s, full, full)
      }
      var at = findTaskIndex(s, s.activeTaskId)
      taskTitle = at >= 0 ? s.tasks[at].title : ""
    })
    root.now = Date.now()

    if (!early && !quiet) {
      root.playAlarm()
      if (finished === "pomodoro") {
        root.notify(next === "long" ? "Time for a long break!" : "Time for a break!",
                    "Pomodoro #" + root.st.pomoCount + " done. " + Model.modeLabel(next) + ": "
                      + Math.round(Model.durationMs(root.profile, next) / 60000) + " min"
                      + (autoStart ? ", already running." : "."),
                    next)
      } else {
        root.notify("Time to focus!", taskTitle !== "" ? taskTitle : "Break is over.", "pomodoro")
      }
    }
    root.roundFinished(finished, next)
  }

  // Only a round that has started can be finished early; skipping an idle
  // pomodoro would count one that never happened.
  function skip() {
    if (!root.loaded || !root.active) return
    root.complete(true, true)
  }

  function resetCount() {
    mutate(function(s) { s.pomoCount = 0 })
  }

  Timer {
    id: ticker
    interval: 250
    repeat: true
    running: root.running
    triggeredOnStart: true
    onTriggered: {
      root.now = Date.now()
      root.checkRound()
    }
  }

  function checkRound() {
    if (!root.running) return
    var left = root.st.endsAt - Date.now()
    if (left <= 0) {
      // Long past the end means the shell was not running when it rang
      // (restart, crash, or a suspend that outlived the round): count the
      // round, but do not go off at someone who has walked away.
      root.complete(false, left < -5 * 60000)
      return
    }
    var reminder = root.settings.reminderMinutes
    if (reminder > 0 && root.mode === "pomodoro" && !root.st.reminded
        && left <= reminder * 60000 && root.st.roundTotal > reminder * 60000) {
      mutate(function(s) { s.reminded = true })
      root.notify(reminder + (reminder === 1 ? " minute" : " minutes") + " left",
                  root.activeTask ? root.activeTask.title : "Pomodoro #" + (root.pomoCount + 1), "pomodoro")
    }
  }

  // ----------------------------------------------------------------- tasks

  function addTask(title, est, note) {
    var t = Model.normalizeTask({ title: title, est: est, note: note, act: 0, done: false })
    if (!t) return ""
    mutate(function(s) {
      s.tasks.push(t)
      if (findTaskIndex(s, s.activeTaskId) < 0) s.activeTaskId = t.id
    })
    return t.id
  }

  function updateTask(id, fields) {
    mutate(function(s) {
      var i = findTaskIndex(s, id)
      if (i < 0) return
      var merged = s.tasks[i]
      for (var k in fields) merged[k] = fields[k]
      var t = Model.normalizeTask(merged)
      if (t) s.tasks[i] = t
    })
  }

  function deleteTask(id) {
    mutate(function(s) {
      var i = findTaskIndex(s, id)
      if (i < 0) return
      s.tasks.splice(i, 1)
      if (s.activeTaskId === id) {
        s.activeTaskId = ""
        if (s.tasks.length > 0) selectNextOpenTask(s, i - 1)
      }
    })
  }

  function toggleTaskDone(id) {
    mutate(function(s) {
      var i = findTaskIndex(s, id)
      if (i < 0) return
      var task = s.tasks[i]
      task.done = !task.done
      if (task.done && s.activeTaskId === id && s.settings.autoSwitchTasks) selectNextOpenTask(s, i)
    })
  }

  function selectTask(id) {
    mutate(function(s) {
      if (findTaskIndex(s, id) >= 0) s.activeTaskId = id
    })
  }

  // Walk the selection through the list (keyboard j/k in the panel).
  function cycleTask(delta) {
    var n = root.st.tasks.length
    if (n === 0) return
    var i = 0
    for (var k = 0; k < n; k++) if (root.st.tasks[k].id === root.st.activeTaskId) i = k + delta
    i = ((i % n) + n) % n
    root.selectTask(root.st.tasks[i].id)
  }

  function moveTask(id, delta) {
    mutate(function(s) {
      var i = findTaskIndex(s, id)
      var j = i + delta
      if (i < 0 || j < 0 || j >= s.tasks.length) return
      var t = s.tasks[i]
      s.tasks[i] = s.tasks[j]
      s.tasks[j] = t
    })
  }

  function clearFinishedTasks() {
    mutate(function(s) {
      s.tasks = s.tasks.filter(function(t) { return !t.done })
      if (findTaskIndex(s, s.activeTaskId) < 0) s.activeTaskId = s.tasks.length > 0 ? s.tasks[0].id : ""
    })
  }

  function clearActPomodoros() {
    mutate(function(s) {
      for (var i = 0; i < s.tasks.length; i++) s.tasks[i].act = 0
    })
  }

  function clearAllTasks() {
    mutate(function(s) {
      s.tasks = []
      s.activeTaskId = ""
    })
  }

  // -------------------------------------------------------------- settings

  function setSetting(key, value) {
    mutate(function(s) {
      s.settings[key] = value
      s.settings = Model.normalizeSettings(s.settings)
    })
  }

  function setProfileValue(key, value) {
    mutate(function(s) {
      var p = findProfile(s)
      p[key] = value
      var i = s.profiles.indexOf(p)
      s.profiles[i] = Model.normalizeProfile(p, p)
    })
  }

  function selectProfile(id) {
    mutate(function(s) {
      for (var i = 0; i < s.profiles.length; i++)
        if (s.profiles[i].id === id) s.activeProfileId = id
    })
  }

  function selectProfileByName(name) {
    var wanted = String(name || "").trim().toLowerCase()
    for (var i = 0; i < root.st.profiles.length; i++) {
      if (root.st.profiles[i].name.toLowerCase() === wanted) {
        root.selectProfile(root.st.profiles[i].id)
        return true
      }
    }
    return false
  }

  // A new profile starts as a copy of the current one, which is what you
  // want when the reason for it is "the same, but with longer breaks".
  function addProfile() {
    var id = ""
    mutate(function(s) {
      var base = findProfile(s)
      var copy = Model.normalizeProfile(base, base)
      copy.id = Model.uid()
      var n = s.profiles.length + 1
      copy.name = "Profile " + n
      s.profiles.push(copy)
      s.activeProfileId = copy.id
      id = copy.id
    })
    return id
  }

  function renameProfile(id, name) {
    var clean = String(name || "").trim()
    if (!clean) return
    mutate(function(s) {
      for (var i = 0; i < s.profiles.length; i++)
        if (s.profiles[i].id === id) s.profiles[i].name = clean.slice(0, 32)
    })
  }

  function deleteProfile(id) {
    if (root.st.profiles.length <= 1) return
    mutate(function(s) {
      s.profiles = s.profiles.filter(function(p) { return p.id !== id })
      if (s.activeProfileId === id) s.activeProfileId = s.profiles[0].id
    })
  }

  function clearHistory() {
    mutate(function(s) { s.history = {} })
  }

  // ----------------------------------------------------------------- sound

  // One process per channel. Starting a new sound on a busy channel stops the
  // old one first; the replacement is launched once it has actually exited.
  Process {
    id: alarmProc
    property var pending: null
    onRunningChanged: {
      if (running || !pending) return
      command = pending
      pending = null
      running = true
    }
  }

  function playSound(file, volume, repeat) {
    if (!file) return
    var cmd = [root.soundScript, "play", root.pluginDir + file, String(volume), String(repeat || 1)]
    if (alarmProc.running) {
      alarmProc.pending = cmd
      alarmProc.running = false
    } else {
      alarmProc.command = cmd
      alarmProc.running = true
    }
  }

  function playAlarm() {
    root.playSound(Model.alarmFile(root.settings.alarmSound), root.settings.alarmVolume, root.settings.alarmRepeat)
  }

  function previewAlarm(name) {
    root.playSound(Model.alarmFile(name), root.settings.alarmVolume, 1)
  }

  // Ticking plays while a pomodoro runs. A short preview plays the loop for
  // a few seconds when the sound is picked in settings.
  property bool tickPreview: false
  readonly property string tickingFile: Model.tickingFile(root.settings.tickingSound)
  readonly property var tickCommand: {
    if (!root.loaded || root.tickingFile === "") return null
    if (!root.tickPreview && !(root.running && root.mode === "pomodoro")) return null
    return [root.soundScript, "loop", root.pluginDir + root.tickingFile, String(root.settings.tickingVolume)]
  }
  onTickCommandChanged: syncTicking()

  Process {
    id: tickProc
    property var wanted: null
    property double startedAt: 0
    onRunningChanged: {
      if (running) return
      // A loop that dies within a second of starting is broken (missing
      // file); restarting it would spin.
      if (!wanted || Date.now() - startedAt < 1000) return
      command = wanted
      startedAt = Date.now()
      running = true
    }
  }

  function syncTicking() {
    var cmd = root.tickCommand
    tickProc.wanted = cmd
    if (tickProc.running) {
      if (cmd && JSON.stringify(cmd) === JSON.stringify(tickProc.command)) return
      tickProc.startedAt = 0
      tickProc.running = false
    } else if (cmd) {
      tickProc.command = cmd
      tickProc.startedAt = Date.now()
      tickProc.running = true
    }
  }

  function previewTicking() {
    root.tickPreview = true
    tickPreviewTimer.restart()
  }

  Timer {
    id: tickPreviewTimer
    interval: 3500
    onTriggered: root.tickPreview = false
  }

  // ---------------------------------------------------------- notification

  function notify(headline, body, glyphMode) {
    if (!root.settings.notifications) return
    var script = 'if command -v omarchy-notification-send >/dev/null 2>&1; then '
      + 'exec omarchy-notification-send --app-name Pomodoro -u normal -g "$1" "$2" "$3"; '
      + 'else exec notify-send -a Pomodoro "$2" "$3"; fi'
    Quickshell.execDetached(["sh", "-c", script, "pomodoro-notify", Model.glyph(glyphMode || "pomodoro"), headline, body])
  }

  // ----------------------------------------------------------- persistence

  Process {
    id: mkdirProc
    command: ["mkdir", "-p", root.stateDir]
  }

  FileView {
    id: stateFile
    path: root.statePath
    watchChanges: false
    atomicWrites: true
    printErrors: false
    onLoaded: root.hydrate(text())
    onLoadFailed: root.hydrate("")
  }

  function hydrate(raw) {
    if (root.loaded) return
    root.st = Model.normalizeState(raw)
    root.now = Date.now()
    root.loaded = true
    // A round that ended while nobody was here is settled now.
    if (root.running) root.checkRound()
    syncTicking()
  }

  Timer {
    id: saveTimer
    interval: 120
    onTriggered: root.flush()
  }

  function scheduleSave() {
    if (root.loaded) saveTimer.restart()
  }

  function flush() {
    stateFile.setText(JSON.stringify(root.st, null, 2) + "\n")
  }

  FileView {
    id: paletteFile
    path: root.home + "/.local/state/omarchy/current/theme/colors.toml"
    watchChanges: false
    printErrors: false
    onLoaded: root.palette = Model.parsePalette(text())
    onLoadFailed: root.palette = Model.parsePalette("")
  }

  // `omarchy theme set` replaces the whole theme directory and then rewrites
  // theme.name, so the name file is the signal and colors.toml is re-read.
  FileView {
    path: root.home + "/.local/state/omarchy/current/theme.name"
    watchChanges: true
    printErrors: false
    onFileChanged: {
      reload()
      paletteFile.reload()
    }
  }

  Component.onCompleted: mkdirProc.running = true

  Component.onDestruction: {
    if (saveTimer.running) root.flush()
  }

  // ------------------------------------------------------------------- IPC
  //
  //   omarchy-shell loneycoffee.pomodoro toggle        start / pause
  //   omarchy-shell loneycoffee.pomodoro skip          finish the round now
  //   omarchy-shell loneycoffee.pomodoro mode short    pomodoro | short | long
  //   omarchy-shell loneycoffee.pomodoro addTask "Write report"
  //   omarchy-shell loneycoffee.pomodoro status        JSON for scripts
  //   omarchy-shell loneycoffee.pomodoro show settings open the panel on a view
  //   omarchy-shell shell toggle loneycoffee.pomodoro  open the panel
  IpcHandler {
    target: "loneycoffee.pomodoro"

    function toggle(): void { root.toggleTimer() }
    function start(): void { root.start() }
    function pause(): void { root.pause() }
    function skip(): void { root.skip() }
    function reset(): void { root.reset() }
    function mode(name: string): string {
      if (Model.MODES.indexOf(name) < 0) return "unknown mode: " + name + " (pomodoro|short|long)"
      root.setMode(name)
      return "ok"
    }
    function profile(name: string): string {
      return root.selectProfileByName(name) ? "ok" : "unknown profile: " + name
    }
    function addTask(title: string): string {
      return root.addTask(title, 1, "") !== "" ? "ok" : "empty title"
    }
    function show(view: string): string {
      var v = view === "" ? "main" : view
      if (["main", "settings", "report"].indexOf(v) < 0) return "unknown view: " + view + " (main|settings|report)"
      root.viewRequested(v)
      if (root.shell && typeof root.shell.isPluginOpen === "function" && root.shell.isPluginOpen(root.pluginId)) return "ok"
      return root.shell && root.shell.summon(root.pluginId, "") ? "ok" : "panel unavailable"
    }
    function status(): string {
      return JSON.stringify({
        mode: root.mode,
        state: root.running ? "running" : (root.paused ? "paused" : "idle"),
        remaining: root.clockText,
        remainingSeconds: Math.ceil(root.remainingMs / 1000),
        pomodoro: root.pomoCount + (root.mode === "pomodoro" ? 1 : 0),
        profile: root.profile.name,
        task: root.activeTask ? root.activeTask.title : ""
      })
    }
  }
}
