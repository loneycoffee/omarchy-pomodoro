import QtQuick
import qs.Commons
import qs.Ui
import "../Model.js" as Model

// The pomofocus.io page, top to bottom: progress line, the timer card with
// its three modes and START, the round number and what you are focusing on,
// the task list, and the "Pomos / Finish At" summary.
Column {
  id: root

  property var svc: null
  property var t: null

  // "" while nothing is being edited, "new" while adding, else a task id.
  property string editingId: ""
  property var draft: ({ title: "", note: "", est: 1, act: 0, noteOpen: false })
  property bool menuOpen: false
  // Inside the floating window there is nothing to pop out to.
  property bool floating: false

  readonly property bool typing: !!activeEditor && activeEditor.typing
  property var activeEditor: null

  signal settingsRequested()
  signal reportRequested()
  signal popOutRequested()
  signal confirmRequested(string message, string confirmText, var action)
  signal focusReturned()

  spacing: Style.spacing.xl

  readonly property var tasks: svc ? svc.tasks : []
  readonly property var summary: svc
    ? Model.taskSummary(tasks, svc.profile, svc.mode, svc.remainingMs, svc.pomoCount, svc.running ? svc.now : wallNow)
    : null

  // The service clock only ticks while a round runs; "Finish At" still has to
  // move with the wall clock while the timer sits idle.
  property double wallNow: Date.now()

  Timer {
    interval: 15000
    repeat: true
    running: root.visible
    triggeredOnStart: true
    onTriggered: root.wallNow = Date.now()
  }

  // ------------------------------------------------------------- actions

  function toggleTimer() {
    if (root.svc) root.svc.toggleTimer()
  }

  function requestSkip() {
    if (!root.svc || !root.svc.active) return
    root.confirmRequested("Are you sure you want to finish the round early? The remaining time will not be counted in the report.",
                          "Finish", function() { root.svc.skip() })
  }

  function requestMode(m) {
    if (!root.svc || m === root.svc.mode && !root.svc.active) return
    if (root.svc.running) {
      root.confirmRequested("The timer is still running, are you sure you want to switch?",
                            "Switch", function() { root.svc.setMode(m) })
    } else {
      root.svc.setMode(m)
    }
  }

  function requestReset() {
    if (!root.svc || !root.svc.active) return
    if (root.svc.running) {
      root.confirmRequested("Reset this round back to " + Model.formatClock(root.svc.fullMs) + "?",
                            "Reset", function() { root.svc.reset() })
    } else {
      root.svc.reset()
    }
  }

  function requestResetCount() {
    root.confirmRequested("Do you want to refresh the pomodoro count?", "Refresh",
                          function() { root.svc.resetCount() })
  }

  function beginNew() {
    root.menuOpen = false
    root.draft = { title: "", note: "", est: 1, act: 0, noteOpen: false }
    root.editingId = "new"
  }

  function beginEdit(task) {
    root.menuOpen = false
    root.draft = { title: task.title, note: task.note, est: task.est, act: task.act, noteOpen: task.note !== "" }
    root.editingId = task.id
  }

  function endEdit() {
    root.editingId = ""
    root.activeEditor = null
    root.focusReturned()
  }

  function cancelTransient() {
    if (root.menuOpen) { root.menuOpen = false; return true }
    if (root.editingId !== "") { root.endEdit(); return true }
    return false
  }

  function message() {
    if (!root.svc) return ""
    if (root.svc.activeTask) return root.svc.activeTask.title
    return root.svc.mode === "pomodoro" ? "Time to focus!" : "Time for a break!"
  }

  function wireEditor(editor, taskId, index) {
    editor.draft = root.draft
    editor.editing = taskId !== "new"
    editor.canMoveUp = index > 0
    editor.canMoveDown = index >= 0 && index < root.tasks.length - 1
    editor.begin(taskId !== "new")
    root.activeEditor = editor
    editor.saved.connect(function(fields) {
      if (taskId === "new") root.svc.addTask(fields.title, fields.est, fields.note)
      else root.svc.updateTask(taskId, fields)
      root.endEdit()
    })
    editor.canceled.connect(root.endEdit)
    editor.deleted.connect(function() {
      root.svc.deleteTask(taskId)
      root.endEdit()
    })
    editor.moved.connect(function(delta) { root.svc.moveTask(taskId, delta) })
  }

  Component {
    id: editorComponent
    TaskEditor { t: root.t }
  }

  // --------------------------------------------------------------- header

  Item {
    width: parent.width
    height: Math.max(titleRow.implicitHeight, headerButtons.implicitHeight)

    Row {
      id: titleRow
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.spacing.md

      Text {
        textFormat: Text.PlainText
        anchors.verticalCenter: parent.verticalCenter
        text: Model.glyph(root.svc ? root.svc.mode : "pomodoro")
        color: root.t.mode
        font.family: root.t.fontFamily
        font.pixelSize: Style.font.heading
        Behavior on color { ColorAnimation { duration: 300 } }
      }

      Text {
        textFormat: Text.PlainText
        anchors.verticalCenter: parent.verticalCenter
        text: "Pomodoro"
        color: root.t.fg
        font.family: root.t.fontFamily
        font.pixelSize: Style.font.title
        font.bold: true
      }

      // The active profile, one click from switching it.
      Button {
        anchors.verticalCenter: parent.verticalCenter
        visible: !!root.svc
        text: root.svc ? root.svc.profile.name : ""
        foreground: root.t.dim
        fontFamily: root.t.fontFamily
        fontSize: Style.font.caption
        verticalPadding: Style.spacing.xxs
        horizontalPadding: Style.spacing.md
        bordered: true
        tooltipText: "Profile: click to change"
        onClicked: root.settingsRequested()
      }
    }

    Row {
      id: headerButtons
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.spacing.xxs

      PanelActionButton {
        visible: !root.floating
        iconText: Model.glyph("popout")
        foreground: root.t.dim
        fontFamily: root.t.fontFamily
        tooltipText: "Floating window (w)"
        onClicked: root.popOutRequested()
      }

      PanelActionButton {
        iconText: Model.glyph("report")
        foreground: root.t.dim
        fontFamily: root.t.fontFamily
        tooltipText: "Report"
        onClicked: root.reportRequested()
      }

      PanelActionButton {
        iconText: Model.glyph("settings")
        foreground: root.t.dim
        fontFamily: root.t.fontFamily
        tooltipText: "Settings"
        onClicked: root.settingsRequested()
      }
    }
  }

  // Progress through the round, the thin line under pomofocus.io's header.
  Rectangle {
    width: parent.width
    height: Math.max(2, Style.space(3))
    radius: height / 2
    color: root.t.hairline

    Rectangle {
      width: parent.width * (root.svc ? root.svc.progress : 0)
      height: parent.height
      radius: parent.radius
      color: root.t.mode
      Behavior on color { ColorAnimation { duration: 300 } }
    }
  }

  // ----------------------------------------------------------- timer card

  BorderSurface {
    id: timerCard
    width: parent.width
    height: timerColumn.implicitHeight + Style.spacing.huge * 2 + Style.spacing.md
    radius: Style.cornerRadius
    color: Util.alpha(root.t.mode, 0.10)
    borderSpec: Border.flat(Util.alpha(root.t.mode, 0.35), Style.normalBorderWidth)

    Behavior on color { ColorAnimation { duration: 300 } }

    Column {
      id: timerColumn
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: parent.top
      anchors.topMargin: Style.spacing.huge
      spacing: Style.spacing.md

      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Style.spacing.xs

        Repeater {
          model: Model.MODES

          Button {
            required property string modelData
            text: Model.modeLabel(modelData)
            selected: !!root.svc && root.svc.mode === modelData
            foreground: root.t.fg
            accent: root.t.mode
            fontFamily: root.t.fontFamily
            fontSize: Style.font.body
            verticalPadding: Style.spacing.xs
            onClicked: root.requestMode(modelData)
          }
        }
      }

      Text {
        textFormat: Text.PlainText
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.svc ? root.svc.clockText : "--:--"
        color: !!root.svc && root.svc.paused ? root.t.dim : root.t.fg
        font.family: root.t.fontFamily
        font.pixelSize: Math.round(Style.font.baseSize * 7.5)
        font.bold: true
      }

      Item {
        anchors.horizontalCenter: parent.horizontalCenter
        width: startButton.width + (sideButtonSize + Style.spacing.xl) * 2
        height: startButton.height
        readonly property real sideButtonSize: Style.space(36)

        PanelActionButton {
          anchors.right: startButton.left
          anchors.rightMargin: Style.spacing.xl
          anchors.verticalCenter: parent.verticalCenter
          anchors.verticalCenterOffset: -startButton.depth / 2
          visible: !!root.svc && root.svc.active
          size: parent.sideButtonSize
          iconText: Model.glyph("reset")
          fontSize: Style.font.iconLarge
          foreground: root.t.dim
          hoverColor: root.t.fg
          fontFamily: root.t.fontFamily
          tooltipText: "Reset round (r)"
          onClicked: root.requestReset()
        }

        StartButton {
          id: startButton
          anchors.horizontalCenter: parent.horizontalCenter
          t: root.t
          running: !!root.svc && root.svc.running
          onClicked: root.toggleTimer()
        }

        PanelActionButton {
          anchors.left: startButton.right
          anchors.leftMargin: Style.spacing.xl
          anchors.verticalCenter: parent.verticalCenter
          anchors.verticalCenterOffset: -startButton.depth / 2
          visible: !!root.svc && root.svc.active
          size: parent.sideButtonSize
          iconText: Model.glyph("skip")
          fontSize: Style.font.displayLarge
          foreground: root.t.dim
          hoverColor: root.t.fg
          fontFamily: root.t.fontFamily
          tooltipText: "Finish round (n)"
          onClicked: root.requestSkip()
        }
      }
    }
  }

  // ------------------------------------------------- round + current task

  Column {
    width: parent.width
    spacing: Style.spacing.xs

    Text {
      textFormat: Text.PlainText
      anchors.horizontalCenter: parent.horizontalCenter
      text: root.svc ? "#" + (root.svc.pomoCount + (root.svc.mode === "pomodoro" ? 1 : 0)) : ""
      color: countMouse.containsMouse ? root.t.fg : root.t.dim
      font.family: root.t.fontFamily
      font.pixelSize: Style.font.subtitle

      MouseArea {
        id: countMouse
        anchors.fill: parent
        anchors.margins: -Style.spacing.sm
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.requestResetCount()
      }
    }

    Text {
      textFormat: Text.PlainText
      width: parent.width
      horizontalAlignment: Text.AlignHCenter
      text: root.message()
      color: root.t.fg
      font.family: root.t.fontFamily
      font.pixelSize: Style.font.heading
      wrapMode: Text.Wrap
      maximumLineCount: 2
      elide: Text.ElideRight
    }
  }

  // ----------------------------------------------------------------- tasks

  Item {
    width: parent.width
    height: Math.max(tasksTitle.implicitHeight, tasksMenuButton.height)

    Text {
      id: tasksTitle
      textFormat: Text.PlainText
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: "Tasks"
      color: root.t.fg
      font.family: root.t.fontFamily
      font.pixelSize: Style.font.title
      font.bold: true
    }

    PanelActionButton {
      id: tasksMenuButton
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      iconText: Model.glyph("more")
      foreground: root.menuOpen ? root.t.fg : root.t.dim
      fontFamily: root.t.fontFamily
      bordered: true
      tooltipText: "Task actions"
      onClicked: root.menuOpen = !root.menuOpen
    }
  }

  Rectangle {
    width: parent.width
    height: Math.max(1, Style.space(2))
    color: root.t.hairline
  }

  // The ⋮ menu, inline under the header rather than a floating popup, so it
  // cannot fall off the edge of a small panel.
  BorderSurface {
    visible: root.menuOpen
    width: parent.width
    height: menuColumn.implicitHeight + Style.spacing.sm * 2
    radius: Style.cornerRadius
    color: root.t.well
    borderSpec: Border.controlSpec("normal", root.t.fg, Color.accent)

    Column {
      id: menuColumn
      anchors.fill: parent
      anchors.margins: Style.spacing.sm

      Repeater {
        model: [
          { label: "Clear finished tasks", icon: "check", action: "finished" },
          { label: "Clear act pomodoros", icon: "reset", action: "act" },
          { label: "Clear all tasks", icon: "remove", action: "all" },
          { label: "Refresh pomodoro count", icon: "pomodoro", action: "count" }
        ]

        Button {
          required property var modelData
          width: menuColumn.width
          leftAlign: true
          text: modelData.label
          iconText: Model.glyph(modelData.icon)
          iconSize: Style.font.body
          foreground: modelData.action === "all" ? root.t.urgent : root.t.fg
          fontFamily: root.t.fontFamily
          fontSize: Style.font.body
          onClicked: {
            root.menuOpen = false
            if (modelData.action === "finished") root.svc.clearFinishedTasks()
            else if (modelData.action === "act") root.svc.clearActPomodoros()
            else if (modelData.action === "all")
              root.confirmRequested("Delete every task in the list?", "Delete all", function() { root.svc.clearAllTasks() })
            else root.requestResetCount()
          }
        }
      }
    }
  }

  Column {
    id: taskList
    width: parent.width
    spacing: Style.spacing.md

    Repeater {
      model: root.tasks

      Item {
        id: slot
        required property var modelData
        required property int index
        readonly property bool editing: root.editingId === modelData.id
        width: taskList.width
        height: editing ? (editorLoader.item ? editorLoader.item.implicitHeight : 0) : row.implicitHeight

        TaskRow {
          id: row
          visible: !slot.editing
          width: parent.width
          height: implicitHeight
          t: root.t
          task: slot.modelData
          current: !!root.svc && root.svc.activeTaskId === slot.modelData.id
          onSelectRequested: root.svc.selectTask(slot.modelData.id)
          onToggleRequested: root.svc.toggleTaskDone(slot.modelData.id)
          onEditRequested: root.beginEdit(slot.modelData)
        }

        Loader {
          id: editorLoader
          active: slot.editing
          width: parent.width
          sourceComponent: editorComponent
          onLoaded: root.wireEditor(item, slot.modelData.id, slot.index)
        }
      }
    }

    Loader {
      id: newEditorLoader
      active: root.editingId === "new"
      width: parent.width
      sourceComponent: editorComponent
      onLoaded: root.wireEditor(item, "new", -1)
    }

    DashedButton {
      visible: root.editingId !== "new"
      width: parent.width
      t: root.t
      iconText: Model.glyph("plus")
      text: "Add Task"
      onClicked: root.beginNew()
    }
  }

  // "Pomos: 3/7   Finish At: 16:40 (2.1h)"
  BorderSurface {
    visible: root.tasks.length > 0 && !!root.summary
    width: parent.width
    height: summaryRow.implicitHeight + Style.spacing.xl * 2
    radius: Style.cornerRadius
    color: root.t.well
    borderSpec: Border.flat(root.t.hairline, Style.normalBorderWidth)

    Row {
      id: summaryRow
      anchors.centerIn: parent
      spacing: Style.spacing.huge * 2

      Row {
        spacing: Style.spacing.sm
        Text {
          textFormat: Text.PlainText
          text: "Pomos:"
          color: root.t.dim
          font.family: root.t.fontFamily
          font.pixelSize: Style.font.body
        }
        Text {
          textFormat: Text.PlainText
          text: root.summary ? root.summary.act + "/" + root.summary.est : ""
          color: root.t.fg
          font.family: root.t.fontFamily
          font.pixelSize: Style.font.subtitle
          font.bold: true
        }
      }

      Row {
        spacing: Style.spacing.sm
        visible: !!root.summary && root.summary.owed > 0
        Text {
          textFormat: Text.PlainText
          text: "Finish At:"
          color: root.t.dim
          font.family: root.t.fontFamily
          font.pixelSize: Style.font.body
        }
        Text {
          textFormat: Text.PlainText
          text: root.summary
            ? Model.formatHourMinute(new Date(root.summary.finishAt), root.svc.settings.hourFormat)
              + " (" + root.summary.hours.toFixed(1) + "h)"
            : ""
          color: root.t.fg
          font.family: root.t.fontFamily
          font.pixelSize: Style.font.subtitle
          font.bold: true
        }
      }
    }
  }
}
