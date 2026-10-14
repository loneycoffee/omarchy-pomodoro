import QtQuick
import qs.Commons
import qs.Ui
import "../Model.js" as Model

// pomofocus.io's report: hours focused, days accessed, day streak, and the
// last seven days of focus time. Only time spent in pomodoros counts, and
// only the part of a round that actually ran.
Column {
  id: root

  property var svc: null
  property var t: null

  signal backRequested()
  signal confirmRequested(string message, string confirmText, var action)

  spacing: Style.spacing.xl

  // Recomputed whenever the history changes, and on each open, so "Today"
  // follows midnight.
  property double stamp: Date.now()
  // The round in progress counts too, so Today moves while you work.
  readonly property var liveHistory: {
    var h = svc ? Model.cloneJson(svc.history) : {}
    var live = svc ? svc.liveFocusSeconds : 0
    if (live > 0) {
      var key = Model.dayKey(new Date())
      var day = h[key] || { focus: 0, pomos: 0 }
      day.focus += live
      h[key] = day
    }
    return h
  }
  readonly property var stats: Model.report(liveHistory, new Date(stamp))
  readonly property int peak: {
    var m = 0
    for (var i = 0; i < stats.week.length; i++) m = Math.max(m, stats.week[i].minutes)
    return m
  }
  readonly property color barColor: t.modeColor("pomodoro")

  function refresh() { root.stamp = Date.now() }

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
      text: "Report"
      color: root.t.fg
      font.family: root.t.fontFamily
      font.pixelSize: Style.font.title
      font.bold: true
    }
  }

  SectionTitle { t: root.t; text: "ACTIVITY SUMMARY"; glyphName: "report" }

  Row {
    width: parent.width
    spacing: Style.spacing.md
    readonly property real cell: (width - spacing * 2) / 3

    Repeater {
      model: [
        { value: root.stats.hours.toFixed(1), label: "hours focused" },
        { value: String(root.stats.days), label: "days accessed" },
        { value: String(root.stats.streak), label: "day streak" }
      ]

      BorderSurface {
        required property var modelData
        width: parent.cell
        height: tile.implicitHeight + Style.spacing.xl * 2
        radius: Style.cornerRadius
        color: root.t.well
        borderSpec: Border.flat(root.t.hairline, Style.normalBorderWidth)

        Column {
          id: tile
          anchors.centerIn: parent
          spacing: Style.spacing.xs

          Text {
            textFormat: Text.PlainText
            anchors.horizontalCenter: parent.horizontalCenter
            text: modelData.value
            color: root.barColor
            font.family: root.t.fontFamily
            font.pixelSize: Style.font.display
            font.bold: true
          }

          Text {
            textFormat: Text.PlainText
            anchors.horizontalCenter: parent.horizontalCenter
            text: modelData.label
            color: root.t.dim
            font.family: root.t.fontFamily
            font.pixelSize: Style.font.caption
          }
        }
      }
    }
  }

  Text {
    textFormat: Text.PlainText
    text: "Today: " + root.stats.todayPomos + (root.stats.todayPomos === 1 ? " pomodoro, " : " pomodoros, ")
      + Model.formatMinutes(root.stats.todayMinutes) + " focused"
    color: root.t.fg
    font.family: root.t.fontFamily
    font.pixelSize: Style.font.body
  }

  SectionTitle { t: root.t; text: "FOCUS TIME, LAST 7 DAYS"; glyphName: "pomodoro" }

  Item {
    id: chart
    width: parent.width
    height: Style.space(150)
    readonly property real labelHeight: Style.font.caption + Style.spacing.md
    readonly property real valueHeight: Style.font.caption + Style.spacing.sm
    readonly property real plotHeight: height - labelHeight - valueHeight
    readonly property real slot: width / 7

    // Baseline.
    Rectangle {
      x: 0
      y: chart.valueHeight + chart.plotHeight
      width: parent.width
      height: 1
      color: root.t.hairline
    }

    Repeater {
      model: root.stats.week

      Item {
        required property var modelData
        required property int index
        x: index * chart.slot
        width: chart.slot
        height: chart.height

        readonly property real barHeight: root.peak > 0
          ? Math.max(modelData.minutes > 0 ? Style.space(3) : 0, chart.plotHeight * modelData.minutes / root.peak)
          : 0

        Text {
          textFormat: Text.PlainText
          anchors.horizontalCenter: parent.horizontalCenter
          y: chart.valueHeight + chart.plotHeight - parent.barHeight - chart.valueHeight
          visible: modelData.minutes > 0
          text: Model.formatMinutes(modelData.minutes)
          color: root.t.dim
          font.family: root.t.fontFamily
          font.pixelSize: Style.font.caption
        }

        Rectangle {
          anchors.horizontalCenter: parent.horizontalCenter
          y: chart.valueHeight + chart.plotHeight - height
          width: Math.min(Style.space(28), chart.slot * 0.6)
          height: parent.barHeight
          radius: Math.min(Style.cornerRadius, Style.space(4))
          color: modelData.label === "Today" ? root.barColor : Util.alpha(root.barColor, 0.7)
        }

        Text {
          textFormat: Text.PlainText
          anchors.horizontalCenter: parent.horizontalCenter
          y: chart.valueHeight + chart.plotHeight + Style.spacing.sm
          text: modelData.label
          color: modelData.label === "Today" ? root.t.fg : root.t.dim
          font.family: root.t.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: modelData.label === "Today"
        }
      }
    }

    Text {
      textFormat: Text.PlainText
      anchors.centerIn: parent
      visible: root.peak === 0
      text: "No focus time this week yet."
      color: root.t.faint
      font.family: root.t.fontFamily
      font.pixelSize: Style.font.bodySmall
    }
  }

  Item {
    width: parent.width
    height: clearButton.height

    Button {
      id: clearButton
      anchors.right: parent.right
      text: "Clear report"
      foreground: root.t.dim
      fontFamily: root.t.fontFamily
      fontSize: Style.font.bodySmall
      onClicked: root.confirmRequested("Delete all recorded focus time?", "Clear",
                                       function() { root.svc.clearHistory() })
    }
  }
}
