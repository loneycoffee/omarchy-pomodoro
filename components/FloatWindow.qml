import QtQuick
import Quickshell
import qs.Commons

// The Pomodoro card as a normal window, for keeping the timer on screen.
// The service owns the one instance; the bar popups keep working beside it,
// since everything renders the same service state.
//
// Hyprland tiles new windows, so float it with a rule in hypr/custom.lua:
//   o.window({ class = "^org.quickshell$", title = "^Pomodoro$" }, { float = true })
FloatingWindow {
  id: win

  property var svc: null

  title: "Pomodoro"
  // Popup backgrounds can be translucent; a window sits over other windows,
  // so keep it solid.
  color: Util.alpha(theme.bg, 1)
  implicitWidth: Style.space(440) + 2 * pad
  implicitHeight: Style.space(640)
  minimumSize: Qt.size(Style.space(360), Style.space(300))

  readonly property real pad: Style.space(18)

  // The host closed us (Super+W, the close button): tell the service, which
  // unloads the window.
  onVisibleChanged: {
    if (!visible && win.svc) win.svc.closeWindow()
  }

  Theme {
    id: theme
    svc: win.svc
  }

  // The same faint mode wash as the popup.
  Rectangle {
    anchors.fill: parent
    color: Util.alpha(theme.mode, content.view === "main" ? 0.06 : 0.0)
    Behavior on color { ColorAnimation { duration: Style.duration(400) } }
  }

  PomodoroContent {
    id: content
    anchors.fill: parent
    anchors.margins: win.pad
    svc: win.svc
    t: theme
    floating: true
    confirmInset: win.pad / 2
    onCloseRequested: if (win.svc) win.svc.closeWindow()
    // "w" in the window docks it back to the bar.
    onPopOutRequested: if (win.svc) win.svc.closeWindow()
  }

  Connections {
    target: win.svc
    function onViewRequested(view) { content.showView(view) }
  }

  Component.onCompleted: {
    content.reset("main")
    Qt.callLater(content.takeFocus)
  }
}
