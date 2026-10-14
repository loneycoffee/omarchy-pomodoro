import QtQuick
import qs.Commons

// pomofocus.io's START button: a raised key that sits pressed in while the
// timer runs. Filled with the mode color rather than white so it belongs to
// the theme; the label takes whichever of the theme's background and
// foreground reads best on it.
Item {
  id: root

  property var t: null
  property bool running: false

  signal clicked()

  readonly property int depth: Style.space(6)
  readonly property bool down: mouse.pressed || root.running

  implicitWidth: Style.space(200)
  implicitHeight: Style.space(52) + depth

  Rectangle {
    width: parent.width
    height: parent.height - root.depth
    y: root.depth
    radius: Style.cornerRadius
    color: Qt.darker(root.t.mode, 1.7)
    visible: !root.down
  }

  Rectangle {
    id: face
    width: parent.width
    height: parent.height - root.depth
    y: root.down ? root.depth : 0
    radius: Style.cornerRadius
    color: mouse.containsMouse && !root.down ? Qt.lighter(root.t.mode, 1.06) : root.t.mode

    Behavior on y { NumberAnimation { duration: 70; easing.type: Easing.OutQuad } }
    Behavior on color { ColorAnimation { duration: 200 } }

    Text {
      textFormat: Text.PlainText
      anchors.centerIn: parent
      text: root.running ? "PAUSE" : "START"
      color: root.t.modeInk
      font.family: root.t.fontFamily
      font.pixelSize: Math.round(Style.font.display * 0.92)
      font.bold: true
      font.letterSpacing: Style.space(2)
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
