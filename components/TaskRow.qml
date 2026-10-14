import QtQuick
import qs.Commons
import qs.Ui
import "../Model.js" as Model

// One task, as pomofocus.io draws it: a check circle, the title, act/est
// pomodoros and an edit button, with a bar down the left edge on the task
// the timer is counting for. Clicking the row makes it that task.
BorderSurface {
  id: root

  property var t: null
  property var task: null
  property bool current: false
  property bool cursor: false

  signal selectRequested()
  signal toggleRequested()
  signal editRequested()

  readonly property bool hot: rowHover.hovered || cursor

  implicitHeight: Math.max(Style.space(46), textColumn.implicitHeight + Style.spacing.xl * 2 + borderTop + borderBottom)
  radius: Style.cornerRadius
  color: current ? Util.alpha(root.t.mode, 0.10) : (hot ? Style.hoverFillFor(root.t.fg, Color.accent) : root.t.well)
  borderSpec: Border.controlSpec(hot ? "hover-cursor" : "normal", root.t.fg, Color.accent)

  Behavior on color { ColorAnimation { duration: 120 } }

  HoverHandler { id: rowHover }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: root.selectRequested()
  }

  // The marker for the task the timer is counting for.
  Rectangle {
    visible: root.current
    anchors.left: parent.left
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    anchors.leftMargin: root.borderLeft
    anchors.topMargin: root.borderTop
    anchors.bottomMargin: root.borderBottom
    width: Style.space(5)
    radius: Math.min(Style.cornerRadius, width / 2)
    color: root.t.mode
  }

  Item {
    id: body
    anchors.fill: parent
    anchors.leftMargin: root.borderLeft + Style.spacing.xl + Style.space(4)
    anchors.rightMargin: root.borderRight + Style.spacing.sm
    anchors.topMargin: Math.max(root.borderTop + Style.spacing.xl, Math.round((root.height - textColumn.implicitHeight) / 2))
    anchors.bottomMargin: root.borderBottom + Style.spacing.xl
    implicitHeight: textColumn.implicitHeight

    FontMetrics {
      id: titleMetrics
      font: titleText.font
    }

    // Centered on the first line of the title, so a wrapped title or a note
    // grows downward without dragging the check and the counts with it.
    PanelActionButton {
      id: check
      anchors.left: parent.left
      anchors.top: parent.top
      anchors.topMargin: Math.round((titleMetrics.height - height) / 2)
      iconText: Model.glyph(root.task.done ? "check" : "unchecked")
      foreground: root.task.done ? root.t.mode : root.t.faint
      hoverColor: root.t.mode
      fontFamily: root.t.fontFamily
      fontSize: Style.font.heading
      tooltipText: root.task.done ? "Mark as not done" : "Mark as done"
      onClicked: root.toggleRequested()
    }

    Column {
      id: textColumn
      anchors.left: check.right
      anchors.leftMargin: Style.spacing.md
      anchors.right: counts.left
      anchors.rightMargin: Style.spacing.md
      anchors.top: parent.top
      spacing: Style.spacing.sm

      Text {
        id: titleText
        textFormat: Text.PlainText
        width: parent.width
        text: root.task.title
        color: root.task.done ? root.t.faint : root.t.fg
        font.family: root.t.fontFamily
        font.pixelSize: Style.font.subtitle
        font.bold: true
        font.strikeout: root.task.done
        wrapMode: Text.Wrap
        maximumLineCount: 3
        elide: Text.ElideRight
      }

      BorderSurface {
        visible: root.task.note !== ""
        width: parent.width
        height: noteText.implicitHeight + Style.spacing.md * 2
        radius: Style.cornerRadius
        color: Util.alpha(root.t.paletteColor("yellow", Color.accent), 0.12)

        Text {
          id: noteText
          textFormat: Text.PlainText
          anchors.fill: parent
          anchors.margins: Style.spacing.md
          text: root.task.note
          color: root.t.dim
          font.family: root.t.fontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.Wrap
        }
      }
    }

    Row {
      id: counts
      anchors.right: parent.right
      anchors.verticalCenter: check.verticalCenter
      spacing: Style.spacing.sm

      Text {
        textFormat: Text.PlainText
        anchors.verticalCenter: parent.verticalCenter
        text: root.task.act + "/" + root.task.est
        color: root.t.faint
        font.family: root.t.fontFamily
        font.pixelSize: Style.font.body
        font.bold: true
      }

      PanelActionButton {
        anchors.verticalCenter: parent.verticalCenter
        iconText: Model.glyph("more")
        foreground: root.t.dim
        fontFamily: root.t.fontFamily
        tooltipText: "Edit task"
        onClicked: root.editRequested()
      }
    }
  }
}
