import QtQuick
import QtQuick.Effects
import qs.Commons
import qs.Ui

Item {
  id: root
  property var bar: null
  property var logic: null
  property var hostWidget: null
  readonly property bool hasTrack: logic ? logic.hasTrack : false
  readonly property bool playing: logic ? logic.playing : false
  readonly property bool loading: logic ? logic.loading : false
  readonly property bool hasError: logic ? logic.error !== "" : false
  property real loaderAngle: 0
  readonly property var preferences: logic && logic.data.preferences ? logic.data.preferences : ({})
  readonly property bool showArtist: preferences.showArtist === undefined ? true : Boolean(preferences.showArtist)
  readonly property bool showTitle: preferences.showTitle === undefined ? true : Boolean(preferences.showTitle)
  readonly property bool showCover: preferences.showCover === undefined ? true : Boolean(preferences.showCover)
  readonly property string coverShape: String(preferences.coverShape || "rounded")
  readonly property bool showProgress: preferences.showProgress === undefined ? true : Boolean(preferences.showProgress)
  readonly property string longTitleMode: String(preferences.longTitleMode || "truncate")
  readonly property real informationWidth: {
    var mode = String(preferences.barWidth || "normal")
    if (mode === "compact") return Style.space(140)
    if (mode === "wide") return Style.space(260)
    return Style.space(200)
  }
  readonly property real lyricsWidth: {
    var mode = String(preferences.barWidth || "normal")
    if (mode === "compact") return Style.space(280)
    if (mode === "wide") return Style.space(540)
    return Style.space(420)
  }
  readonly property color foreground: bar ? bar.barForeground : Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property Item coverItem: cover
  readonly property string label: {
    if (hasError) return "Ошибка Яндекс Музыки — нажмите, чтобы открыть"
    if (loading && !hasTrack) return "Яндекс Музыка загружается…"
    if (!hasTrack) return "Я.Музыка"
    var artist = String(logic.data.artist || "")
    var title = String(logic.data.title || "")
    return artist ? artist + " — " + title : title
  }

  // Position clock for smooth lyric synchronization and progress interpolation
  property double positionClockMs: Date.now()
  readonly property real displayPosition: {
    var pos = Number(logic && logic.data ? logic.data.position || 0 : 0)
    var observedAt = Number(logic && logic.data ? logic.data.positionObservedAt || 0 : 0)
    if (root.playing && observedAt > 0) {
      var elapsed = Math.max(0, positionClockMs / 1000 - observedAt)
      pos += Math.min(3, elapsed)
    }
    var dur = Number(logic && logic.data ? logic.data.duration || 0 : 0)
    return Math.max(0, dur > 0 ? Math.min(dur, pos) : pos)
  }

  Timer {
    id: positionTimer
    interval: 80
    running: root.playing && root.hasTrack
    repeat: true
    onTriggered: root.positionClockMs = Date.now()
  }

  readonly property var lyricsLines: logic && logic.lyricsData && logic.lyricsData.lines ? logic.lyricsData.lines : []
  readonly property bool syncedLyricsAvailable: logic && logic.lyricsData && logic.lyricsData.synced === true && lyricsLines.length > 0

  function currentLyricsIndex() {
    if (!syncedLyricsAvailable) return -1
    var current = -1
    var pos = root.displayPosition
    for (var i = 0; i < lyricsLines.length; i++) {
      var t = Number(lyricsLines[i].time || 0)
      if (t <= pos + 0.05) current = i
      else break
    }
    return current
  }

  readonly property int activeLyricIndex: currentLyricsIndex()
  readonly property string targetLyricText: {
    if (!syncedLyricsAvailable) return ""
    var idx = activeLyricIndex
    if (idx >= 0 && idx < lyricsLines.length) {
      return String(lyricsLines[idx].text || "").trim()
    }
    return ""
  }

  implicitWidth: controls.width + Style.space(12)
  implicitHeight: bar ? bar.barSize : Style.bar.sizeHorizontal

  Row {
    id: controls
    anchors.centerIn: parent
    spacing: Style.space(6)

    // Album art / Cover image
    BorderSurface {
      id: cover
      visible: root.showCover
      width: Style.space(20); height: Style.space(20)
      anchors.verticalCenter: parent.verticalCenter
      radius: root.coverShape === "circle" ? width / 2
        : (root.coverShape === "square" ? 0 : Style.space(2))
      color: Style.normalFillFor(root.foreground, Color.accent)
      borderSpec: Border.none()

      Rectangle {
        id: coverMask
        anchors.fill: parent
        visible: false
        layer.enabled: true
        radius: cover.radius
        color: "white"
      }
      Image {
        anchors.fill: parent; source: root.logic && root.logic.data.artUrl ? root.logic.data.artUrl : ""
        fillMode: Image.PreserveAspectCrop; asynchronous: true; visible: source !== ""
        layer.enabled: true; layer.smooth: true
        layer.effect: MultiEffect {
          maskEnabled: true; maskSource: coverMask
          maskThresholdMin: .3; maskSpreadAtMin: .3
        }
      }
      Text {
        textFormat: Text.PlainText
        anchors.centerIn: parent; visible: !root.logic || !root.logic.data.artUrl
        text: "󰝚"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption
      }
      Rectangle {
        anchors.fill: parent
        visible: root.hasError && !root.loading
        radius: cover.radius
        color: Qt.rgba(0, 0, 0, .55)
      }
      Rectangle {
        anchors.fill: parent
        visible: root.loading
        radius: cover.radius
        color: Qt.rgba(0, 0, 0, .58)
      }
      Rectangle {
        anchors.centerIn: parent
        visible: root.loading
        width: Style.space(14); height: width; radius: width / 2
        color: "transparent"
        border.width: Style.spacing.hairline
        border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, .25)
      }
      Canvas {
        anchors.centerIn: parent
        visible: root.loading
        width: Style.space(14); height: width
        antialiasing: true
        rotation: root.loaderAngle
        onPaint: {
          var context = getContext("2d")
          context.clearRect(0, 0, width, height)
          context.beginPath()
          context.arc(width / 2, height / 2, width / 2 - Style.space(1.3),
            -Math.PI / 2, Math.PI * .85, false)
          context.lineWidth = Style.space(1.7)
          context.lineCap = "round"
          context.strokeStyle = Color.accent
          context.stroke()
        }
      }
      Text {
        textFormat: Text.PlainText
        anchors.centerIn: parent
        visible: root.hasError && !root.loading
        text: "󰀪"; color: Color.urgent
        font.family: root.fontFamily; font.pixelSize: Style.font.caption
      }

      // Smooth darkening overlay when playback is paused
      Rectangle {
        id: pauseDimmer
        anchors.fill: parent
        radius: cover.radius
        color: Qt.rgba(0, 0, 0, .45)
        opacity: (root.hasTrack && !root.playing && !root.loading && !root.hasError) ? 1.0 : 0.0
        visible: opacity > 0
        Behavior on opacity {
          NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }
      }

      // Smooth pause badge overlay
      Text {
        textFormat: Text.PlainText
        anchors.centerIn: parent
        text: "󰏤"
        color: "white"
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        opacity: (root.hasTrack && !root.playing && !root.loading && !root.hasError) ? 1.0 : 0.0
        scale: (root.hasTrack && !root.playing && !root.loading && !root.hasError) ? 1.0 : 0.75
        visible: opacity > 0
        Behavior on opacity {
          NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }
        Behavior on scale {
          NumberAnimation { duration: 180; easing.type: Easing.OutBack }
        }
      }

      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: if (root.logic) root.logic.toggle()
        onEntered: if (root.bar) root.bar.showTooltip(parent, "Открыть Яндекс Музыку")
        onExited: if (root.bar) root.bar.hideTooltip(parent)
      }
    }

    // Fallback icon when cover is hidden
    Item {
      visible: !root.showCover && !labelSlot.visible
      width: Style.space(24); height: root.implicitHeight
      Text {
        textFormat: Text.PlainText
        anchors.centerIn: parent
        text: "󰝚"; color: root.foreground
        font.family: root.fontFamily; font.pixelSize: Style.font.icon
      }
      MouseArea {
        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        onClicked: if (root.logic) root.logic.toggle()
        onEntered: if (root.bar) root.bar.showTooltip(parent, "Открыть Яндекс Музыку")
        onExited: if (root.bar) root.bar.hideTooltip(parent)
      }
    }

    // Like Button (Empty or Full Heart)
    Item {
      id: likeButton
      visible: root.hasTrack
      width: Style.space(26); height: root.implicitHeight

      Text {
        textFormat: Text.PlainText
        anchors.centerIn: parent
        text: root.logic && root.logic.data && root.logic.data.liked ? "󰋑" : "󰋕"
        color: root.logic && root.logic.data && root.logic.data.liked ? Color.accent : root.foreground
        opacity: root.logic && root.logic.data && root.logic.data.liked ? 1.0 : (likeMouseArea.containsMouse ? 0.9 : 0.6)
        font.family: root.fontFamily
        font.pixelSize: Style.font.icon
      }

      MouseArea {
        id: likeMouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: if (root.logic) root.logic.action("like")
        onEntered: if (root.bar) root.bar.showTooltip(parent, root.logic && root.logic.data && root.logic.data.liked ? "Удалить из понравившихся" : "Мне нравится")
        onExited: if (root.bar) root.bar.hideTooltip(parent)
      }
    }

    // Track Title / Artist Label Slot
    Item {
      id: labelSlot
      visible: root.showArtist || root.showTitle
      width: root.showTitle ? root.informationWidth : Math.min(root.informationWidth, Style.space(105))
      height: root.implicitHeight
      clip: true

      Text {
        textFormat: Text.PlainText
        id: trackInfoLabel
        anchors.verticalCenter: parent.verticalCenter
        width: root.longTitleMode === "scroll" ? implicitWidth : parent.width
        text: {
          if (!root.hasTrack) return "Я.Музыка"
          var parts = []
          var artist = root.logic ? String(root.logic.data.artist || "") : ""
          var title = root.logic ? String(root.logic.data.title || "") : ""
          if (root.showArtist && artist) parts.push(artist)
          if (root.showTitle && title) parts.push(title)
          return parts.join(" — ")
        }
        color: root.foreground; font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        elide: root.longTitleMode === "scroll" ? Text.ElideNone : Text.ElideRight
      }

      SequentialAnimation {
        id: trackInfoMarquee
        running: root.longTitleMode === "scroll" && root.hasTrack
          && trackInfoLabel.implicitWidth > labelSlot.width
        loops: Animation.Infinite
        PauseAnimation { duration: 1000 }
        NumberAnimation {
          target: trackInfoLabel; property: "x"
          from: 0; to: Math.min(0, labelSlot.width - trackInfoLabel.implicitWidth)
          duration: Math.max(1200, (trackInfoLabel.implicitWidth - labelSlot.width) * 22)
          easing.type: Easing.InOutSine
        }
        PauseAnimation { duration: 700 }
        NumberAnimation {
          target: trackInfoLabel; property: "x"; to: 0
          duration: 350; easing.type: Easing.OutCubic
        }
      }
      Connections {
        target: trackInfoMarquee
        function onRunningChanged() { if (!trackInfoMarquee.running) trackInfoLabel.x = 0 }
      }
    }

    // Separator between Title and Lyrics
    Item {
      id: separatorItem
      visible: root.hasTrack && root.syncedLyricsAvailable
      width: Style.space(10)
      height: root.implicitHeight

      Text {
        textFormat: Text.PlainText
        anchors.centerIn: parent
        text: "│"
        color: root.foreground
        opacity: 0.25
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
      }
    }

    // Synced Lyrics Slot with Smooth Bezier-Curve Transition Animations
    Item {
      id: lyricsSlot
      visible: root.hasTrack && root.syncedLyricsAvailable
      width: root.lyricsWidth
      height: root.implicitHeight
      clip: true

      property string currentDisplayedText: ""
      property string pendingText: {
        if (!root.syncedLyricsAvailable) return ""
        if (root.targetLyricText !== "") return root.targetLyricText
        return "♪"
      }

      onPendingTextChanged: {
        if (pendingText === currentDisplayedText) return
        if (lyricTransition.running) {
          lyricTransition.stop()
        }
        if (currentDisplayedText === "") {
          currentDisplayedText = pendingText
          lyricLabel.opacity = 1
          lyricLabel.y = (lyricsSlot.height - lyricLabel.implicitHeight) / 2
        } else {
          lyricTransition.restart()
        }
      }

      Text {
        textFormat: Text.PlainText
        id: lyricLabel
        anchors.left: parent.left
        y: (parent.height - implicitHeight) / 2
        width: Math.min(implicitWidth, parent.width)
        text: lyricsSlot.currentDisplayedText !== "" ? lyricsSlot.currentDisplayedText : "♪"
        color: lyricsSlot.currentDisplayedText !== "" ? Color.accent : root.foreground
        opacity: lyricsSlot.currentDisplayedText !== "" ? 1.0 : 0.4
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        font.weight: Font.Medium
        elide: Text.ElideRight
      }

      SequentialAnimation {
        id: lyricTransition
        // Smooth slide up & fade out old line
        ParallelAnimation {
          NumberAnimation {
            target: lyricLabel
            property: "opacity"
            to: 0
            duration: 120
            easing.type: Easing.InQuad
          }
          NumberAnimation {
            target: lyricLabel
            property: "y"
            to: ((lyricsSlot.height - lyricLabel.implicitHeight) / 2) - Style.space(6)
            duration: 120
            easing.type: Easing.InQuad
          }
        }
        ScriptAction {
          script: {
            lyricsSlot.currentDisplayedText = lyricsSlot.pendingText
            lyricLabel.y = ((lyricsSlot.height - lyricLabel.implicitHeight) / 2) + Style.space(6)
          }
        }
        // Smooth slide into place & fade in new line using Bezier (OutCubic) curve
        ParallelAnimation {
          NumberAnimation {
            target: lyricLabel
            property: "opacity"
            to: lyricsSlot.currentDisplayedText !== "" ? 1.0 : 0.4
            duration: 220
            easing.type: Easing.OutCubic
          }
          NumberAnimation {
            target: lyricLabel
            property: "y"
            to: (lyricsSlot.height - lyricLabel.implicitHeight) / 2
            duration: 220
            easing.type: Easing.OutCubic
          }
        }
      }
    }
  }

  // Mouse Area covering Track Title and Lyrics area with Waybar-lyrics mouse controls:
  // - Left click: Play / Pause toggle
  // - Right click: Next track
  // - Middle click: Previous track
  // - Wheel Up: Seek next lyric line (or +5s)
  // - Wheel Down: Seek previous lyric line (or -5s)
  MouseArea {
    id: playbackMouseArea
    visible: labelSlot.visible || (lyricsSlot && lyricsSlot.visible)
    x: controls.x + labelSlot.x
    y: 0
    width: {
      var w = labelSlot.width
      if (separatorItem.visible) w += separatorItem.width + controls.spacing
      if (lyricsSlot.visible) w += lyricsSlot.width + controls.spacing
      return w
    }
    height: root.height
    z: 10
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

    onClicked: function(mouse) {
      if (!root.logic) return
      if (mouse.button === Qt.LeftButton) {
        root.logic.action("pause")
      } else if (mouse.button === Qt.RightButton) {
        root.logic.action("next")
      } else if (mouse.button === Qt.MiddleButton) {
        root.logic.action("previous")
      }
    }

    onWheel: function(wheel) {
      wheel.accepted = true
      if (!root.logic || !root.hasTrack) return
      var lyrics = root.lyricsLines
      var pos = root.displayPosition
      var dur = Number(root.logic.data ? root.logic.data.duration || 0 : 0)

      if (wheel.angleDelta.y > 0) {
        // Scroll Up -> Seek next lyric line
        if (root.syncedLyricsAvailable && lyrics.length > 0) {
          var nextTime = -1
          for (var i = 0; i < lyrics.length; i++) {
            var t = Number(lyrics[i].time || 0)
            if (t > pos + 0.3) {
              nextTime = t
              break
            }
          }
          if (nextTime >= 0) {
            root.logic.action("seek", Math.round(nextTime))
            return
          }
        }
        var targetForward = Math.min(dur > 0 ? dur : pos + 5, pos + 5)
        root.logic.action("seek", Math.round(targetForward))
      } else if (wheel.angleDelta.y < 0) {
        // Scroll Down -> Seek previous lyric line
        if (root.syncedLyricsAvailable && lyrics.length > 0) {
          var prevTime = -1
          for (var j = lyrics.length - 1; j >= 0; j--) {
            var pt = Number(lyrics[j].time || 0)
            if (pt < pos - 0.5) {
              prevTime = pt
              break
            }
          }
          if (prevTime >= 0) {
            root.logic.action("seek", Math.round(prevTime))
            return
          }
        }
        var targetBack = Math.max(0, pos - 5)
        root.logic.action("seek", Math.round(targetBack))
      }
    }

    onEntered: if (root.bar) {
      var tooltip = root.label
      if (root.targetLyricText !== "") {
        tooltip += "\n[Текст] " + root.targetLyricText
      }
      tooltip += "\nЛКМ: Пауза/Плей | ПКМ: След. | СКМ: Пред. | Колесо: Перемотка строк"
      root.bar.showTooltip(root, tooltip)
    }
    onExited: if (root.bar) root.bar.hideTooltip(root)
  }

  // Cover loader animation timer
  Timer {
    interval: 16
    repeat: true
    running: root.loading
    onTriggered: root.loaderAngle = (root.loaderAngle + 7.2) % 360
  }

  // Playback Progress Bar (interpolated position)
  Rectangle {
    visible: root.hasTrack && root.showProgress
    anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
    height: Style.space(2); color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, .15)
    Rectangle {
      width: parent.width * (root.logic
        ? Math.min(1, root.displayPosition / Math.max(1, Number(root.logic.data.duration || 1)))
        : 0)
      height: parent.height; color: Color.accent
    }
  }
}
