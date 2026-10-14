import QtQuick
import QtQuick.Controls as QQC
import qs.Commons
import qs.Ui
import "../Model.js" as Model

// The add / edit card from pomofocus.io: "What are you working on?", the
// pomodoro estimate (and the actual count when editing), an optional note,
// and Delete / Cancel / Save along the bottom.
BorderSurface {
  id: root

  property var t: null
  property bool editing: false
  property bool canMoveUp: false
  property bool canMoveDown: false

  // The form's values live in a draft object owned by the task list, not in
  // here. A timer finishing mid-edit rebuilds the list (and this card with
  // it); reading the draft back means nothing typed is lost when it does.
  property var draft: ({ title: "", note: "", est: 1, act: 0, noteOpen: false })

  property int est: 1
  property int act: 0
  property bool noteOpen: false

  onEstChanged: draft.est = est
  onActChanged: draft.act = act
  onNoteOpenChanged: draft.noteOpen = noteOpen
  readonly property bool typing: titleField.activeFocus || noteArea.activeFocus

  signal saved(var fields)
  signal canceled()
  signal deleted()
  signal moved(int delta)

  function begin(selectTitle) {
    var d = root.draft
    titleField.text = d.title
    noteArea.text = d.note
    root.est = d.est
    root.act = d.act
    root.noteOpen = d.noteOpen
    Qt.callLater(function() {
      titleField.forceActiveFocus()
      if (selectTitle) titleField.selectAll()
      else titleField.cursorPosition = titleField.text.length
    })
  }

  function save() {
    var title = titleField.text.trim()
    if (title === "") {
      titleField.forceActiveFocus()
      return
    }
    root.saved({ title: title, est: root.est, act: root.act, note: root.noteOpen ? noteArea.text.trim() : "" })
  }

  implicitHeight: form.implicitHeight + footer.height + Style.spacing.huge * 2 + Style.spacing.xl
  radius: Style.cornerRadius
  color: root.t.well
  borderSpec: Border.controlSpec("focus", root.t.fg, Color.accent)

  Keys.onEscapePressed: root.canceled()

  Column {
    id: form
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: Style.spacing.huge
    spacing: Style.spacing.xl

    TextField {
      id: titleField
      width: parent.width
      placeholderText: "What are you working on?"
      foreground: root.t.fg
      font.family: root.t.fontFamily
      font.pixelSize: Style.font.title
      font.bold: true
      maximumLength: 200
      onTextChanged: root.draft.title = text
      onAccepted: root.save()
      Keys.onEscapePressed: root.canceled()
    }

    Row {
      spacing: Style.spacing.lg

      Stepper {
        visible: root.editing
        t: root.t
        label: "ACT"
        value: root.act
        from: 0
        to: 999
        fieldWidth: Style.space(96)
        onModified: function(v) { root.act = v }
      }

      Text {
        visible: root.editing
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Style.spacing.sm
        textFormat: Text.PlainText
        text: "/"
        color: root.t.faint
        font.family: root.t.fontFamily
        font.pixelSize: Style.font.heading
      }

      Stepper {
        t: root.t
        label: "EST POMODOROS"
        value: root.est
        from: 1
        to: 99
        fieldWidth: Style.space(96)
        onModified: function(v) { root.est = v }
      }
    }

    Text {
      visible: !root.noteOpen
      textFormat: Text.PlainText
      text: "+ Add Note"
      color: noteLink.containsMouse ? root.t.fg : root.t.dim
      font.family: root.t.fontFamily
      font.pixelSize: Style.font.bodySmall
      font.bold: true
      font.underline: true

      MouseArea {
        id: noteLink
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          root.noteOpen = true
          Qt.callLater(function() { noteArea.forceActiveFocus() })
        }
      }
    }

    QQC.TextArea {
      id: noteArea
      visible: root.noteOpen
      width: parent.width
      height: Math.max(Style.space(64), implicitHeight)
      placeholderText: "Some notes..."
      placeholderTextColor: root.t.faint
      color: root.t.fg
      selectionColor: Style.selectionFillFor(root.t.fg, Color.accent)
      selectedTextColor: root.t.fg
      font.family: root.t.fontFamily
      font.pixelSize: Style.font.body
      wrapMode: TextEdit.Wrap
      onTextChanged: root.draft.note = text
      leftPadding: Style.spacing.controlPaddingX
      rightPadding: Style.spacing.controlPaddingX
      topPadding: Style.spacing.inputPaddingY
      bottomPadding: Style.spacing.inputPaddingY
      Keys.onEscapePressed: root.canceled()
      Keys.onPressed: function(event) {
        if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && (event.modifiers & Qt.ControlModifier)) {
          root.save()
          event.accepted = true
        }
      }
      background: BorderSurface {
        radius: Style.cornerRadius
        color: Style.controlFill(noteArea.activeFocus, noteArea.hovered, root.t.fg, Color.accent)
        borderSpec: Border.controlSpec(noteArea.activeFocus ? "focus" : (noteArea.hovered ? "hover-cursor" : "normal"), root.t.fg, Color.accent)
      }
    }
  }

  // Footer strip, tinted like pomofocus.io's grey form footer.
  Rectangle {
    id: footer
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.leftMargin: root.borderLeft
    anchors.rightMargin: root.borderRight
    anchors.bottomMargin: root.borderBottom
    height: footerRow.implicitHeight + Style.spacing.lg * 2
    color: Util.alpha(root.t.fg, 0.05)
    radius: Style.cornerRadius

    Row {
      anchors.left: parent.left
      anchors.leftMargin: Style.spacing.lg
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.spacing.xs
      visible: root.editing

      Button {
        text: "Delete"
        foreground: root.t.urgent
        fontFamily: root.t.fontFamily
        fontSize: Style.font.bodySmall
        onClicked: root.deleted()
      }

      PanelActionButton {
        anchors.verticalCenter: parent.verticalCenter
        iconText: Model.glyph("up")
        foreground: root.t.dim
        fontFamily: root.t.fontFamily
        enabled: root.canMoveUp
        tooltipText: "Move up"
        onClicked: root.moved(-1)
      }

      PanelActionButton {
        anchors.verticalCenter: parent.verticalCenter
        iconText: Model.glyph("down")
        foreground: root.t.dim
        fontFamily: root.t.fontFamily
        enabled: root.canMoveDown
        tooltipText: "Move down"
        onClicked: root.moved(1)
      }
    }

    Row {
      id: footerRow
      anchors.right: parent.right
      anchors.rightMargin: Style.spacing.lg
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.spacing.sm

      Button {
        text: "Cancel"
        foreground: root.t.dim
        fontFamily: root.t.fontFamily
        fontSize: Style.font.bodySmall
        onClicked: root.canceled()
      }

      Button {
        text: "Save"
        bordered: true
        selected: true
        foreground: root.t.fg
        fontFamily: root.t.fontFamily
        fontSize: Style.font.bodySmall
        onClicked: root.save()
      }
    }
  }
}
