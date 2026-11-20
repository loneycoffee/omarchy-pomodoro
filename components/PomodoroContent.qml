import QtQuick
import qs.Commons
import qs.Ui
import "../Model.js" as Model

// Everything inside the Pomodoro card: the main, settings and report views,
// the keyboard handling and the confirm dialog. The bar popup and the
// floating window both host one of these, so the two stay identical.
Item {
  id: root

  property var svc: null
  property var t: null
  // True inside the floating window: hides the pop-out button.
  property bool floating: false
  // How far the confirm dialog reaches past the content, to cover the
  // host's padding.
  property real confirmInset: 0

  property string view: "main"   // main | settings | report

  readonly property bool ready: !!root.svc && root.svc.loaded
  readonly property bool typing: mainView.typing || settingsView.typing
  readonly property Item focusItem: keyCatcher
  readonly property real viewHeight: root.view === "settings" ? settingsView.implicitHeight
    : root.view === "report" ? reportView.implicitHeight
    : mainView.implicitHeight

  signal closeRequested()
  signal tabRequested(int direction)
  signal popOutRequested()

  // Start fresh on a view: used when the host opens.
  function reset(v) {
    root.dismiss()
    root.view = v || "main"
    flick.contentY = 0
    reportView.refresh()
  }

  function dismiss() {
    confirm.dismiss()
    mainView.cancelTransient()
  }

  function showView(v) {
    root.dismiss()
    root.view = v
    if (v === "report") reportView.refresh()
    flick.contentY = 0
    keyCatcher.forceActiveFocus()
  }

  function takeFocus() { keyCatcher.forceActiveFocus() }

  function askConfirm(message, confirmText, action) {
    confirm.message = message
    confirm.confirmText = confirmText
    confirm.action = action
    confirm.selectedIndex = 1
    confirm.opened = true
  }

  function handleKey(text) {
    if (!root.ready) return
    if (text === "w") { root.popOutRequested(); return }
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

  PanelKeyCatcher {
    id: keyCatcher
    anchors.fill: parent
    blocked: root.typing

    onCloseRequested: {
      if (confirm.opened) { confirm.dismiss(); return }
      if (mainView.cancelTransient()) return
      if (root.view !== "main") { root.showView("main"); return }
      root.closeRequested()
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
    onTabRequested: function(direction) { root.tabRequested(direction) }
    onTextKey: function(text) {
      if (confirm.opened) return
      root.handleKey(text)
    }

    Flickable {
      id: flick
      anchors.fill: parent
      contentWidth: width
      contentHeight: root.viewHeight
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      interactive: contentHeight > height

      MainView {
        id: mainView
        visible: root.view === "main"
        width: flick.width
        svc: root.svc
        t: root.t
        floating: root.floating
        onSettingsRequested: root.showView("settings")
        onReportRequested: root.showView("report")
        onPopOutRequested: root.popOutRequested()
        onConfirmRequested: function(message, confirmText, action) { root.askConfirm(message, confirmText, action) }
        onFocusReturned: keyCatcher.forceActiveFocus()
      }

      SettingsView {
        id: settingsView
        visible: root.view === "settings"
        width: flick.width
        svc: root.svc
        t: root.t
        onBackRequested: root.showView("main")
        onConfirmRequested: function(message, confirmText, action) { root.askConfirm(message, confirmText, action) }
      }

      ReportView {
        id: reportView
        visible: root.view === "report"
        width: flick.width
        svc: root.svc
        t: root.t
        onBackRequested: root.showView("main")
        onConfirmRequested: function(message, confirmText, action) { root.askConfirm(message, confirmText, action) }
      }
    }

    Text {
      anchors.centerIn: parent
      visible: !root.ready
      textFormat: Text.PlainText
      text: "Starting the Pomodoro service…"
      color: root.t.dim
      font.family: root.t.fontFamily
      font.pixelSize: Style.font.body
    }

    ConfirmDialog {
      id: confirm
      anchors.fill: parent
      anchors.margins: -root.confirmInset
      property var action: null
      cancelText: "Cancel"
      background: Color.popups.background
      foreground: root.t.fg
      selectedText: root.t.mode
      fontFamily: root.t.fontFamily

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
