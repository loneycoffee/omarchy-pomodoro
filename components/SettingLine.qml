import QtQuick
import qs.Commons

// Label and description on the left, a control (the default child) on the
// right: the row shape every pomofocus.io setting uses.
Item {
  id: root

  property var t: null
  property string label: ""
  property string description: ""

  default property alias control: controlHolder.children

  implicitHeight: Math.max(textColumn.implicitHeight, controlHolder.childrenRect.height)

  Column {
    id: textColumn
    anchors.left: parent.left
    anchors.right: controlHolder.left
    anchors.rightMargin: Style.spacing.lg
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.spacing.xs

    Text {
      textFormat: Text.PlainText
      width: parent.width
      text: root.label
      color: root.t.fg
      font.family: root.t.fontFamily
      font.pixelSize: Style.font.subtitle
      font.bold: true
      elide: Text.ElideRight
    }

    Text {
      textFormat: Text.PlainText
      width: parent.width
      visible: root.description !== ""
      text: root.description
      color: root.t.dim
      font.family: root.t.fontFamily
      font.pixelSize: Style.font.caption
      wrapMode: Text.Wrap
    }
  }

  Item {
    id: controlHolder
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    width: childrenRect.width
    height: childrenRect.height
  }
}
