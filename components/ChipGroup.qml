import QtQuick
import qs.Commons
import qs.Ui

// Pick-one row of kit Buttons that wraps onto a second line when the options
// outgrow the panel, which the kit's ButtonGroup (a single Row) cannot do.
Column {
  id: root

  property var t: null
  property string label: ""
  property var options: []      // [{ value, label }]
  property string value: ""

  signal changed(string value)

  spacing: Style.spacing.labelGap

  Text {
    textFormat: Text.PlainText
    visible: root.label !== ""
    text: root.label
    color: root.t.dim
    font.family: root.t.fontFamily
    font.pixelSize: Style.font.caption
    font.bold: true
  }

  Flow {
    width: root.width
    spacing: Style.spacing.sm

    Repeater {
      model: root.options

      Button {
        required property var modelData
        text: modelData.label
        selected: modelData.value === root.value
        bordered: true
        foreground: root.t.fg
        fontFamily: root.t.fontFamily
        fontSize: Style.font.bodySmall
        verticalPadding: Style.spacing.xs + 1
        onClicked: root.changed(modelData.value)
      }
    }
  }
}
