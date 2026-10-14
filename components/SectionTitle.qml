import QtQuick
import qs.Commons
import "../Model.js" as Model

// Section heading for the settings sheet: glyph, small caps label, and a
// rule across the panel, the way pomofocus.io separates Timer / Task / Sound.
Column {
  id: root

  property var t: null
  property string text: ""
  property string glyphName: ""

  width: parent ? parent.width : implicitWidth
  spacing: Style.spacing.md
  topPadding: Style.spacing.md

  Rectangle {
    width: parent.width
    height: 1
    color: root.t.hairline
  }

  Row {
    spacing: Style.spacing.md

    Text {
      textFormat: Text.PlainText
      anchors.verticalCenter: parent.verticalCenter
      visible: root.glyphName !== ""
      text: Model.glyph(root.glyphName)
      color: root.t.faint
      font.family: root.t.fontFamily
      font.pixelSize: Style.font.body
    }

    Text {
      textFormat: Text.PlainText
      anchors.verticalCenter: parent.verticalCenter
      text: root.text
      color: root.t.faint
      font.family: root.t.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
      font.letterSpacing: 1
    }
  }
}
