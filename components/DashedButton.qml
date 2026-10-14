import QtQuick
import qs.Commons

// The dashed "Add Task" slot at the foot of pomofocus.io's task list, drawn
// in the theme's foreground at low alpha so it reads on light and dark
// themes alike.
Item {
  id: root

  property var t: null
  property string text: ""
  property string iconText: ""
  property bool hasCursor: false

  signal clicked()

  readonly property bool hot: mouse.containsMouse || hasCursor

  implicitHeight: Style.space(54)

  Rectangle {
    anchors.fill: parent
    radius: Style.cornerRadius
    color: root.hot ? Style.hoverFillFor(root.t.fg, Color.accent) : "transparent"
    Behavior on color { ColorAnimation { duration: 100 } }
  }

  Canvas {
    id: dashes
    anchors.fill: parent
    readonly property color stroke: root.hot ? root.t.dim : root.t.faint
    readonly property real r: Math.min(Style.cornerRadius, height / 2)
    onStrokeChanged: requestPaint()
    onRChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      var w = Math.max(2, Style.space(2))
      ctx.lineWidth = w
      ctx.strokeStyle = stroke
      ctx.setLineDash([3, 2])
      var x = w / 2, y = w / 2, cw = width - w, ch = height - w
      ctx.beginPath()
      ctx.moveTo(x + r, y)
      ctx.lineTo(x + cw - r, y)
      ctx.arcTo(x + cw, y, x + cw, y + r, r)
      ctx.lineTo(x + cw, y + ch - r)
      ctx.arcTo(x + cw, y + ch, x + cw - r, y + ch, r)
      ctx.lineTo(x + r, y + ch)
      ctx.arcTo(x, y + ch, x, y + ch - r, r)
      ctx.lineTo(x, y + r)
      ctx.arcTo(x, y, x + r, y, r)
      ctx.closePath()
      ctx.stroke()
    }
  }

  Row {
    anchors.centerIn: parent
    spacing: Style.spacing.md

    Text {
      textFormat: Text.PlainText
      anchors.verticalCenter: parent.verticalCenter
      visible: root.iconText !== ""
      text: root.iconText
      color: root.hot ? root.t.fg : root.t.dim
      font.family: root.t.fontFamily
      font.pixelSize: Style.font.heading
    }

    Text {
      textFormat: Text.PlainText
      anchors.verticalCenter: parent.verticalCenter
      text: root.text
      color: root.hot ? root.t.fg : root.t.dim
      font.family: root.t.fontFamily
      font.pixelSize: Style.font.subtitle
      font.bold: true
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
  }
}
