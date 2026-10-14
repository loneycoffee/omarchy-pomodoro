import QtQuick
import qs.Commons

// Colors and type for the Pomodoro panel, derived from the active Omarchy
// theme. Popup surfaces come from the theme's shell.toml like every other
// panel; the three modes take the theme's own red, cyan and blue, the way
// pomofocus.io paints its three modes, so the panel recolors with
// `omarchy theme set` instead of carrying a palette of its own.
QtObject {
  id: root

  property var svc: null
  property string fontFamily: Style.font.family

  readonly property color fg: Color.popups.text
  readonly property color bg: Color.popups.background
  readonly property color dim: Util.alpha(fg, 0.62)
  readonly property color faint: Util.alpha(fg, 0.38)
  readonly property color hairline: Util.alpha(fg, 0.12)
  readonly property color well: Util.alpha(fg, 0.05)
  readonly property color urgent: Color.urgent

  readonly property bool useAccent: !!svc && svc.settings.colorStyle === "accent"
  readonly property var palette: svc ? svc.palette : ({})

  function paletteColor(name, fallback) {
    var v = palette && palette[name] ? palette[name] : ""
    return v !== "" ? v : fallback
  }

  function modeColor(mode) {
    if (useAccent) return Color.accent
    if (mode === "short") return paletteColor("cyan", paletteColor("green", Color.accent))
    if (mode === "long") return paletteColor("blue", Color.accent)
    return paletteColor("red", Color.urgent)
  }

  readonly property color mode: modeColor(svc ? svc.mode : "pomodoro")

  function luminance(c) {
    function ch(v) { return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4) }
    return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b)
  }

  // Text that stays readable on a filled mode color: whichever of the theme's
  // own background and foreground is further from it.
  function inkOn(c) {
    var l = luminance(c)
    var a = Color.background, b = Color.foreground
    return Math.abs(luminance(a) - l) >= Math.abs(luminance(b) - l) ? a : b
  }

  readonly property color modeInk: root.inkOn(root.mode)
}
