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
// starts or pauses without opening anything, middle click toggles the
// floating window.
//
// There is one of these per monitor; all of them render the same service.
// Summon from a keybinding with:  omarchy-shell shell toggle pomodoro
Panel {
  id: root

  moduleName: "pomodoro"
  // The service owns the plugin's IPC target; one per bar would collide.
  manageIpc: false

  readonly property string pluginId: "pomodoro"

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
      return s + "\nLeft: open · Right: start / pause · Middle: floating window"
    }
    onPressed: function(b) {
      if (b === Qt.RightButton) {
        if (root.svc) root.svc.toggleTimer()
        return
      }
      if (b === Qt.MiddleButton) {
        if (root.svc) root.svc.toggleWindow()
        return
      }
      root.toggle()
    }
  }

  // ------------------------------------------------------------- the panel

  property string pendingView: ""

  Connections {
    target: root.svc
    function onViewRequested(view) {
      if (root.opened) content.showView(view)
      else root.pendingView = view
    }
  }

  function open() {
    content.reset(root.pendingView !== "" ? root.pendingView : "main")
    root.pendingView = ""
    root.controller.show()
  }

  function close() {
    content.dismiss()
    root.controller.hide()
  }

  KeyboardPanel {
    id: popup
    anchorItem: button
    bar: root.bar
    owner: root
    open: root.opened
    focusTarget: content.focusItem
    contentWidth: popup.fittedContentWidth(Style.space(440))
    contentHeight: popup.fittedContentHeight(content.viewHeight)

    // Wash the card in the mode color, faintly, the way pomofocus.io turns
    // its whole page red, teal or blue.
    Rectangle {
      anchors.fill: parent
      anchors.margins: -popup.padding
      radius: Style.cornerRadius
      color: Util.alpha(theme.mode, content.view === "main" ? 0.06 : 0.0)
      Behavior on color { ColorAnimation { duration: 400 } }
    }

    PomodoroContent {
      id: content
      anchors.fill: parent
      svc: root.svc
      t: theme
      confirmInset: popup.padding / 2
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      // Hand the card over to the floating window.
      onPopOutRequested: {
        root.close()
        if (root.svc) root.svc.openWindow()
      }
    }
  }
}
