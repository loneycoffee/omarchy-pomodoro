import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "Model.js" as Model
import "components"

// Bar entry and popup for the Pomodoro plugin.
//
// The bar shows the mode glyph and, while a round is going, the time left in
// the mode's color. Left click opens the pomofocus.io-style panel, right click
// starts or pauses without opening anything.
//
// There is one of these per monitor; all of them render the same service.
// Summon from a keybinding with:  omarchy-shell shell toggle loneycoffee.pomodoro
Panel {
  id: root

  moduleName: "loneycoffee.pomodoro"
  // The service owns the plugin's IPC target; one per bar would collide.
  manageIpc: false

  readonly property string pluginId: "loneycoffee.pomodoro"

  // ---------------------------------------------------------- the service

  property var svc: null

  function bindService() {
    if (root.svc) return
    var host = root.bar && root.bar.shell ? root.bar.shell : null
    if (!host || typeof host.serviceFor !== "function") return
    root.svc = host.serviceFor(root.pluginId)
  }

  onBarChanged: bindService()

  // The service may mount after the bar, and is rebuilt on plugin hot-reload.
  Timer {
    interval: 250
    repeat: true
    running: !root.svc
    onTriggered: root.bindService()
  }

  readonly property bool ready: !!root.svc && root.svc.loaded

  Theme {
    id: theme
    svc: root.svc
    fontFamily: root.bar && root.bar.fontFamily ? root.bar.fontFamily : Style.font.family
  }

  // ------------------------------------------------------------ bar button

  readonly property bool showTime: {
    if (!root.ready || root.vertical) return false
    var style = root.svc.settings.barLabel
    if (style === "icon") return false
    if (style === "always") return true
    return root.svc.active
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: Model.glyph(root.ready ? root.svc.mode : "pomodoro") + (root.showTime ? " " + root.svc.clockText : "")
    foreground: !root.ready ? (root.bar ? root.bar.barForeground : Color.foreground)
      : root.svc.running ? theme.mode
      : root.svc.paused ? Util.alpha(root.bar ? root.bar.barForeground : Color.foreground, 0.55)
      : (root.bar ? root.bar.barForeground : Color.foreground)
    tooltipText: {
      if (!root.ready) return "Pomodoro"
      var s = Model.modeLabel(root.svc.mode) + " " + root.svc.clockText
      if (root.svc.running) s += " · running"
      else if (root.svc.paused) s += " · paused"
      if (root.svc.activeTask) s += "\n" + root.svc.activeTask.title
      return s + "\nLeft: open · Right: start / pause"
    }
    onPressed: function(b) {
      if (b === Qt.RightButton) {
        if (root.svc) root.svc.toggleTimer()
        return
      }
      root.toggle()
    }
  }

  // ------------------------------------------------------------- the panel

  property string view: "main"   // main | settings | report
  property string pendingView: ""

  Connections {
    target: root.svc
    function onViewRequested(view) {
      if (root.opened) root.showView(view)
      else root.pendingView = view
    }
  }

  readonly property bool typing: mainView.typing || settingsView.typing

  function open() {
    root.view = root.pendingView !== "" ? root.pendingView : "main"
    root.pendingView = ""
    flick.contentY = 0
    reportView.refresh()
    root.controller.show()
  }

  function close() {
    confirm.dismiss()
    mainView.cancelTransient()
    root.controller.hide()
  }

  function showView(v) {
    confirm.dismiss()
    mainView.cancelTransient()
    root.view = v
    if (v === "report") reportView.refresh()
    flick.contentY = 0
    keyCatcher.forceActiveFocus()
  }

  function askConfirm(message, confirmText, action) {
    confirm.message = message
    confirm.confirmText = confirmText
    confirm.action = action
    confirm.selectedIndex = 1
    confirm.opened = true
  }

  function handleKey(text) {
    if (!root.ready) return
    if (root.view !== "main") return
    switch (text) {
    case "n": mainView.requestSkip(); break
    case "r": mainView.requestReset(); break
    case "1": mainView.requestMode("pomodoro"); break
    case "2": mainView.requestMode("short"); break
    case "3": mainView.requestMode("long"); break
    case "a": mainView.beginNew(); break
    case "e": if (root.svc.activeTask) mainView.beginEdit(root.svc.activeTask); break
    case "s": root.showView("settings"); break
    case "p": root.showView("report"); break
    }
  }

  KeyboardPanel {
    id: popup
    anchorItem: button
    bar: root.bar
    owner: root
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: popup.fittedContentWidth(Style.space(440))
    contentHeight: popup.fittedContentHeight(
      root.view === "settings" ? settingsView.implicitHeight
      : root.view === "report" ? reportView.implicitHeight
      : mainView.implicitHeight)

    // Wash the card in the mode color, faintly, the way pomofocus.io turns
    // its whole page red, teal or blue.
    Rectangle {
      anchors.fill: parent
      anchors.margins: -popup.padding
      radius: Style.cornerRadius
      color: Util.alpha(theme.mode, root.view === "main" ? 0.06 : 0.0)
      Behavior on color { ColorAnimation { duration: 400 } }
    }

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: root.typing

      onCloseRequested: {
        if (confirm.opened) { confirm.dismiss(); return }
        if (mainView.cancelTransient()) return
        if (root.view !== "main") { root.showView("main"); return }
        root.close()
      }
      onActivateRequested: {
        if (confirm.opened) {
          if (confirm.selectedIndex === 0) confirm.dismiss()
          else confirm.accept()
          return
        }
        if (root.view === "main" && root.svc) root.svc.toggleTimer()
      }
      onMoveRequested: function(dx, dy) {
        if (confirm.opened) {
          if (dx !== 0) confirm.selectedIndex = confirm.selectedIndex === 0 ? 1 : 0
          return
        }
        if (root.view === "main" && dy !== 0 && root.svc) root.svc.cycleTask(dy)
        else if (dy !== 0) flick.flick(0, dy > 0 ? -1200 : 1200)
      }
      onDeleteRequested: {
        if (confirm.opened || root.view !== "main" || !root.svc || !root.svc.activeTask) return
        root.svc.toggleTaskDone(root.svc.activeTask.id)
      }
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(text) {
        if (confirm.opened) return
        root.handleKey(text)
      }

      Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: root.view === "settings" ? settingsView.implicitHeight
          : root.view === "report" ? reportView.implicitHeight
          : mainView.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        MainView {
          id: mainView
          visible: root.view === "main"
          width: flick.width
          svc: root.svc
          t: theme
          onSettingsRequested: root.showView("settings")
          onReportRequested: root.showView("report")
          onConfirmRequested: function(message, confirmText, action) { root.askConfirm(message, confirmText, action) }
          onFocusReturned: keyCatcher.forceActiveFocus()
        }

        SettingsView {
          id: settingsView
          visible: root.view === "settings"
          width: flick.width
          svc: root.svc
          t: theme
          onBackRequested: root.showView("main")
          onConfirmRequested: function(message, confirmText, action) { root.askConfirm(message, confirmText, action) }
        }

        ReportView {
          id: reportView
          visible: root.view === "report"
          width: flick.width
          svc: root.svc
          t: theme
          onBackRequested: root.showView("main")
          onConfirmRequested: function(message, confirmText, action) { root.askConfirm(message, confirmText, action) }
        }
      }

      Text {
        anchors.centerIn: parent
        visible: !root.ready
        textFormat: Text.PlainText
        text: "Starting the Pomodoro service…"
        color: theme.dim
        font.family: theme.fontFamily
        font.pixelSize: Style.font.body
      }

      ConfirmDialog {
        id: confirm
        anchors.fill: parent
        anchors.margins: -popup.padding / 2
        property var action: null
        cancelText: "Cancel"
        background: Color.popups.background
        foreground: theme.fg
        selectedText: theme.mode
        fontFamily: theme.fontFamily

        function dismiss() {
          confirm.opened = false
          confirm.action = null
        }

        function accept() {
          var fn = confirm.action
          confirm.dismiss()
          if (typeof fn === "function") fn()
        }

        onCanceled: dismiss()
        onConfirmed: accept()
      }
    }
  }
}
