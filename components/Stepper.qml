import QtQuick
import qs.Commons
import qs.Ui

// Number input in the kit's control chrome: [−] value [+], plus the scroll
// wheel. Stands in for pomofocus.io's number fields without pulling in the
// platform SpinBox indicators, which no Omarchy theme styles.
Column {
  id: root

  property var t: null
  property string label: ""
  property int value: 0
  property int from: 0
  property int to: 99
  property int stepSize: 1
  property string suffix: ""
  property real fieldWidth: Style.space(112)

  signal modified(int value)

  spacing: Style.spacing.labelGap

  function nudge(steps) {
    var next = Math.max(root.from, Math.min(root.to, root.value + steps * root.stepSize))
    if (next !== root.value) root.modified(next)
  }

  Text {
    textFormat: Text.PlainText
    visible: root.label !== ""
    text: root.label
    color: root.t.dim
    font.family: root.t.fontFamily
    font.pixelSize: Style.font.caption
    font.bold: true
  }

  BorderSurface {
    id: box
    width: root.fieldWidth
    height: Style.spacing.controlHeight
    radius: Style.cornerRadius
    readonly property bool hot: hover.hovered
    color: Style.controlFill(false, hot, root.t.fg, Color.accent)
    borderSpec: Border.controlSpec(hot ? "hover-cursor" : "normal", root.t.fg, Color.accent)

    HoverHandler { id: hover }

    WheelHandler {
      onWheel: function(event) { root.nudge(event.angleDelta.y > 0 ? 1 : -1) }
    }

    PanelActionButton {
      id: minus
      anchors.left: parent.left
      anchors.leftMargin: box.borderLeft + Style.spacing.xxs
      anchors.verticalCenter: parent.verticalCenter
      size: Style.spacing.controlHeight - Style.spacing.sm * 2
      fontSize: Style.font.bodySmall
      iconText: "−"
      foreground: root.t.fg
      fontFamily: root.t.fontFamily
      enabled: root.value > root.from
      onClicked: root.nudge(-1)
    }

    Text {
      textFormat: Text.PlainText
      anchors.centerIn: parent
      text: root.value + root.suffix
      color: root.t.fg
      font.family: root.t.fontFamily
      font.pixelSize: Style.font.body
    }

    PanelActionButton {
      anchors.right: parent.right
      anchors.rightMargin: box.borderRight + Style.spacing.xxs
      anchors.verticalCenter: parent.verticalCenter
      size: minus.size
      fontSize: Style.font.bodySmall
      iconText: "+"
      foreground: root.t.fg
      fontFamily: root.t.fontFamily
      enabled: root.value < root.to
      onClicked: root.nudge(1)
    }
  }
}
