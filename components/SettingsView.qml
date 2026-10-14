import QtQuick
import qs.Commons
import qs.Ui
import "../Model.js" as Model

// pomofocus.io's settings sheet, plus profiles: named timer setups (Classic
// 25/5/15, Deep Work 50/10/30, your own) that you switch between with one
// click. The Timer section edits the selected profile; everything below it
// applies to all of them.
Column {
  id: root

  property var svc: null
  property var t: null

  readonly property bool typing: nameField.activeFocus
  readonly property var settings: svc ? svc.settings : Model.defaultSettings()
  readonly property var profile: svc ? svc.profile : Model.defaultProfiles()[0]

  signal backRequested()
  signal confirmRequested(string message, string confirmText, var action)

  spacing: Style.spacing.xl

  function syncName() {
    if (!nameField.activeFocus) nameField.text = root.profile.name
  }

  onProfileChanged: syncName()
  Component.onCompleted: syncName()

  function commitName() {
    if (root.svc && nameField.text.trim() !== "") root.svc.renameProfile(root.profile.id, nameField.text)
    else nameField.text = root.profile.name
  }

  // ---------------------------------------------------------------- header

  Item {
    width: parent.width
    height: backButton.height

    PanelActionButton {
      id: backButton
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      iconText: Model.glyph("back")
      foreground: root.t.dim
      hoverColor: root.t.fg
      fontFamily: root.t.fontFamily
      tooltipText: "Back (Esc)"
      onClicked: root.backRequested()
    }

    Text {
      textFormat: Text.PlainText
      anchors.left: backButton.right
      anchors.leftMargin: Style.spacing.md
      anchors.verticalCenter: parent.verticalCenter
      text: "Settings"
      color: root.t.fg
      font.family: root.t.fontFamily
      font.pixelSize: Style.font.title
      font.bold: true
    }
  }

  // -------------------------------------------------------------- profiles

  SectionTitle { t: root.t; text: "PROFILES"; glyphName: "pomodoro" }

  Flow {
    width: parent.width
    spacing: Style.spacing.sm

    Repeater {
      model: root.svc ? root.svc.profiles : []

      Button {
        required property var modelData
        text: modelData.name
        tooltipText: modelData.pomodoro + " / " + modelData.short + " / " + modelData.long + " min"
        selected: modelData.id === root.profile.id
        bordered: true
        foreground: root.t.fg
        accent: root.t.mode
        fontFamily: root.t.fontFamily
        fontSize: Style.font.bodySmall
        onClicked: root.svc.selectProfile(modelData.id)
      }
    }

    Button {
      text: "New"
      iconText: Model.glyph("plus")
      iconSize: Style.font.body
      bordered: true
      foreground: root.t.dim
      fontFamily: root.t.fontFamily
      fontSize: Style.font.bodySmall
      tooltipText: "Copy the selected profile"
      onClicked: {
        root.svc.addProfile()
        Qt.callLater(function() {
          nameField.forceActiveFocus()
          nameField.selectAll()
        })
      }
    }
  }

  Row {
    width: parent.width
    spacing: Style.spacing.sm

    TextField {
      id: nameField
      width: parent.width - deleteProfile.width - parent.spacing
      placeholderText: "Profile name"
      foreground: root.t.fg
      font.family: root.t.fontFamily
      maximumLength: 32
      onAccepted: {
        root.commitName()
        focus = false
      }
      onActiveFocusChanged: if (!activeFocus) root.commitName()
      Keys.onEscapePressed: {
        text = root.profile.name
        focus = false
      }
    }

    PanelActionButton {
      id: deleteProfile
      anchors.verticalCenter: parent.verticalCenter
      size: nameField.height
      iconText: Model.glyph("remove")
      foreground: root.t.dim
      hoverColor: root.t.urgent
      fontFamily: root.t.fontFamily
      enabled: !!root.svc && root.svc.profiles.length > 1
      tooltipText: "Delete this profile"
      onClicked: root.confirmRequested("Delete the profile “" + root.profile.name + "”?", "Delete",
                                       function() { root.svc.deleteProfile(root.profile.id) })
    }
  }

  // ----------------------------------------------------------------- timer

  SectionTitle { t: root.t; text: "TIMER"; glyphName: "pomodoro" }

  Text {
    textFormat: Text.PlainText
    text: "Time (minutes) for “" + root.profile.name + "”"
    color: root.t.fg
    font.family: root.t.fontFamily
    font.pixelSize: Style.font.subtitle
    font.bold: true
  }

  Row {
    width: parent.width
    spacing: Style.spacing.lg
    readonly property real cell: (width - spacing * 2) / 3

    Stepper {
      t: root.t
      label: "POMODORO"
      fieldWidth: parent.cell
      value: root.profile.pomodoro
      from: 1
      to: 240
      onModified: function(v) { root.svc.setProfileValue("pomodoro", v) }
    }
    Stepper {
      t: root.t
      label: "SHORT BREAK"
      fieldWidth: parent.cell
      value: root.profile.short
      from: 1
      to: 120
      onModified: function(v) { root.svc.setProfileValue("short", v) }
    }
    Stepper {
      t: root.t
      label: "LONG BREAK"
      fieldWidth: parent.cell
      value: root.profile.long
      from: 1
      to: 180
      onModified: function(v) { root.svc.setProfileValue("long", v) }
    }
  }

  Toggle {
    width: parent.width
    label: "Auto Start Breaks"
    description: "Start the break as soon as a pomodoro ends."
    checked: root.profile.autoStartBreaks
    foreground: root.t.fg
    accent: root.t.mode
    fontFamily: root.t.fontFamily
    onClicked: root.svc.setProfileValue("autoStartBreaks", !checked)
  }

  Toggle {
    width: parent.width
    label: "Auto Start Pomodoros"
    description: "Start the next pomodoro as soon as a break ends."
    checked: root.profile.autoStartPomodoros
    foreground: root.t.fg
    accent: root.t.mode
    fontFamily: root.t.fontFamily
    onClicked: root.svc.setProfileValue("autoStartPomodoros", !checked)
  }

  SettingLine {
    t: root.t
    width: parent.width
    label: "Long Break interval"
    description: "Pomodoros before a long break."

    Stepper {
      t: root.t
      value: root.profile.longInterval
      from: 1
      to: 12
      onModified: function(v) { root.svc.setProfileValue("longInterval", v) }
    }
  }

  // ----------------------------------------------------------------- tasks

  SectionTitle { t: root.t; text: "TASK"; glyphName: "check" }

  Toggle {
    width: parent.width
    label: "Auto Check Tasks"
    description: "Check a task off once its act pomodoros reach the estimate."
    checked: root.settings.autoCheckTasks
    foreground: root.t.fg
    accent: root.t.mode
    fontFamily: root.t.fontFamily
    onClicked: root.svc.setSetting("autoCheckTasks", !checked)
  }

  Toggle {
    width: parent.width
    label: "Auto Switch Tasks"
    description: "Move on to the next unchecked task when the current one is checked."
    checked: root.settings.autoSwitchTasks
    foreground: root.t.fg
    accent: root.t.mode
    fontFamily: root.t.fontFamily
    onClicked: root.svc.setSetting("autoSwitchTasks", !checked)
  }

  // ----------------------------------------------------------------- sound

  SectionTitle { t: root.t; text: "SOUND"; glyphName: "short" }

  ChipGroup {
    t: root.t
    width: parent.width
    label: "ALARM SOUND"
    options: Model.ALARM_SOUNDS
    value: root.settings.alarmSound
    onChanged: function(v) {
      root.svc.setSetting("alarmSound", v)
      root.svc.previewAlarm(v)
    }
  }

  Row {
    spacing: Style.spacing.lg

    Stepper {
      t: root.t
      label: "VOLUME"
      suffix: "%"
      value: root.settings.alarmVolume
      from: 0
      to: 100
      stepSize: 10
      onModified: function(v) {
        root.svc.setSetting("alarmVolume", v)
        previewDebounce.restart()
      }
    }

    Stepper {
      t: root.t
      label: "REPEAT"
      suffix: "×"
      value: root.settings.alarmRepeat
      from: 1
      to: 10
      onModified: function(v) { root.svc.setSetting("alarmRepeat", v) }
    }
  }

  Timer {
    id: previewDebounce
    interval: 350
    onTriggered: root.svc.previewAlarm(root.settings.alarmSound)
  }

  ChipGroup {
    t: root.t
    width: parent.width
    label: "TICKING SOUND"
    options: Model.TICKING_SOUNDS
    value: root.settings.tickingSound
    onChanged: function(v) {
      root.svc.setSetting("tickingSound", v)
      if (v !== "none") root.svc.previewTicking()
    }
  }

  Stepper {
    t: root.t
    label: "TICKING VOLUME"
    suffix: "%"
    value: root.settings.tickingVolume
    from: 0
    to: 100
    stepSize: 10
    onModified: function(v) {
      root.svc.setSetting("tickingVolume", v)
      if (root.settings.tickingSound !== "none") root.svc.previewTicking()
    }
  }

  // ---------------------------------------------------------- notification

  SectionTitle { t: root.t; text: "NOTIFICATION"; glyphName: "long" }

  Toggle {
    width: parent.width
    label: "Desktop notifications"
    description: "Announce the end of every round through Omarchy's notifications."
    checked: root.settings.notifications
    foreground: root.t.fg
    accent: root.t.mode
    fontFamily: root.t.fontFamily
    onClicked: root.svc.setSetting("notifications", !checked)
  }

  SettingLine {
    t: root.t
    width: parent.width
    label: "Reminder"
    description: "Notify this many minutes before a pomodoro ends. 0 is off."

    Stepper {
      t: root.t
      suffix: " min"
      value: root.settings.reminderMinutes
      from: 0
      to: 60
      onModified: function(v) { root.svc.setSetting("reminderMinutes", v) }
    }
  }

  // --------------------------------------------------------------- display

  SectionTitle { t: root.t; text: "DISPLAY"; glyphName: "settings" }

  ChipGroup {
    t: root.t
    width: parent.width
    label: "MODE COLORS"
    options: [
      { value: "palette", label: "Theme red / cyan / blue" },
      { value: "accent", label: "Theme accent" }
    ]
    value: root.settings.colorStyle
    onChanged: function(v) { root.svc.setSetting("colorStyle", v) }
  }

  ChipGroup {
    t: root.t
    width: parent.width
    label: "HOUR FORMAT"
    options: [{ value: "24", label: "24-hour" }, { value: "12", label: "12-hour" }]
    value: root.settings.hourFormat
    onChanged: function(v) { root.svc.setSetting("hourFormat", v) }
  }

  ChipGroup {
    t: root.t
    width: parent.width
    label: "BAR LABEL"
    options: [
      { value: "active", label: "Time while active" },
      { value: "always", label: "Always show time" },
      { value: "icon", label: "Icon only" }
    ]
    value: root.settings.barLabel
    onChanged: function(v) { root.svc.setSetting("barLabel", v) }
  }

  Item { width: 1; height: Style.spacing.sm }
}
