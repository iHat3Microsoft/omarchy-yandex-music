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
  property bool likePending: false
  property bool likeFlash: false
  property bool likeError: false
  property bool navSpinner: false
  property real wheelAccumulator: 0
  readonly property var preferences: logic && logic.snapshot.preferences ? logic.snapshot.preferences : ({})
  readonly property bool showControls: preferences.showControls === undefined ? true : Boolean(preferences.showControls)
  readonly property bool signedOut: logic ? logic.snapshot.authenticated === false : false
  readonly property bool errorState: hasError && !loading && !signedOut && !hasTrack
  readonly property bool showTime: preferences.showTime === undefined ? false : Boolean(preferences.showTime)
  readonly property bool showLike: preferences.showLike === undefined ? false : Boolean(preferences.showLike)
  readonly property bool dimmed: hasTrack && !playing && !loading
  readonly property bool showVolume: preferences.showVolume === undefined ? true : Boolean(preferences.showVolume)
  readonly property bool showArtist: preferences.showArtist === undefined ? true : Boolean(preferences.showArtist)
  readonly property bool showTitle: preferences.showTitle === undefined ? true : Boolean(preferences.showTitle)
  readonly property bool showCover: preferences.showCover === undefined ? true : Boolean(preferences.showCover)
  readonly property string coverShape: String(preferences.coverShape || "rounded")
  readonly property bool showProgress: preferences.showProgress === undefined ? true : Boolean(preferences.showProgress)
  readonly property string longTitleMode: String(preferences.longTitleMode || "truncate")
  readonly property bool showBarLyrics: Boolean(preferences.showBarLyrics)
  readonly property bool barMouseControls: Boolean(preferences.barMouseControls)
  readonly property real informationWidth: {
    var mode = String(preferences.barWidth || "normal")
    if (mode === "compact") return Style.space(170)
    if (mode === "wide") return Style.space(310)
    return Style.space(230)
  }
  readonly property real lyricsMaxWidth: {
    var mode = String(preferences.lyricsWidthMode || "auto")
    if (mode === "compact") return Style.space(240)
    if (mode === "normal") return Style.space(400)
    if (mode === "wide") return Style.space(600)
    if (mode === "full") return Style.space(1200)

    // "auto" mode: dynamically compute space up to the center of the bar
    var screenW = (root.bar && root.bar.width > 0) ? root.bar.width
      : (typeof Screen !== "undefined" && Screen.width > 0 ? Screen.width : 1920)
    var centerX = screenW / 2
    var globalX = 0
    try {
      if (root.visible && root.width > 0) {
        var pt = root.mapToItem(null, 0, 0)
        if (pt && typeof pt.x === "number") globalX = pt.x
      }
    } catch (e) {}

    if (globalX >= 0 && globalX < centerX) {
      var beforeLyrics = separatorItem.x > 0 ? (separatorItem.x + separatorItem.width + Style.space(8)) : Style.space(200)
      var maxFit = centerX - globalX - beforeLyrics - Style.space(20)
      if (maxFit > Style.space(160)) return maxFit
    }

    var barMode = String(preferences.barWidth || "normal")
    if (barMode === "compact") return Style.space(240)
    if (barMode === "wide") return Style.space(600)
    return Style.space(450)
  }
  readonly property int maxLyricChars: {
    var lines = root.lyricsLines
    if (!lines || lines.length === 0) return 0
    var m = 0
    for (var i = 0; i < lines.length; i++) {
      var len = String(lines[i].text || "").trim().length
      if (len > m) m = len
    }
    return m
  }
  readonly property real lyricsWidth: {
    if (!root.syncedLyricsAvailable) return 0
    var charW = Style.space(7.8)
    var computed = maxLyricChars > 0 ? (maxLyricChars * charW + Style.space(16)) : lyricsMaxWidth
    return Math.min(lyricsMaxWidth, Math.max(Style.space(160), computed))
  }
  readonly property Item coverItem: cover.visible ? cover : (labelSlot.visible ? labelSlot : root)

  property double positionClockMs: Date.now()
  readonly property real displayPosition: {
    var pos = Number(logic && logic.snapshot ? logic.snapshot.position || 0 : 0)
    var observedAt = Number(logic && logic.snapshot ? logic.snapshot.positionObservedAt || 0 : 0)
    if (root.playing && observedAt > 0) {
      var elapsed = Math.max(0, positionClockMs / 1000 - observedAt)
      pos += Math.min(3, elapsed)
    }
    var dur = Number(logic && logic.snapshot ? logic.snapshot.duration || 0 : 0)
    return Math.max(0, dur > 0 ? Math.min(dur, pos) : pos)
  }

  Timer {
    id: positionTimer
    interval: 80
    running: root.playing && root.hasTrack && root.showBarLyrics
    repeat: true
    onTriggered: root.positionClockMs = Date.now()
  }

  readonly property var lyricsData: (logic && logic.snapshot && logic.snapshot.lyrics) ? logic.snapshot.lyrics : null
  readonly property var lyricsLines: (lyricsData && lyricsData.lines) ? lyricsData.lines : []
  readonly property bool lyricsAvailable: lyricsData && lyricsData.available === true && lyricsLines.length > 0 && String(lyricsData.trackId || "") === String(logic.snapshot.trackId || "")
  readonly property bool syncedLyricsAvailable: lyricsAvailable && lyricsData.synced === true

  function currentLyricsIndex() {
    if (!syncedLyricsAvailable) return -1
    var pos = root.displayPosition
    var current = -1
    for (var i = 0; i < lyricsLines.length; i++) {
      var t = Number(lyricsLines[i].time || 0)
      if (t <= pos) current = i
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
  readonly property color foreground: bar ? bar.barForeground : Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property string errorText: logic && logic.snapshot.version === undefined
    ? "Нет связи с сервисом" : "Ошибка Яндекс Музыки"
  readonly property string label: {
    if (signedOut) return "Войти в Яндекс Музыку"
    if (hasError) return "Ошибка Яндекс Музыки — нажмите, чтобы открыть"
    if (loading && !hasTrack) return "Яндекс Музыка загружается…"
    if (!hasTrack) return "Я.Музыка"
    var artist = String(logic.snapshot.artist || "")
    var title = String(logic.snapshot.title || "")
    return artist ? artist + " — " + title : title
  }

  function navigating() {
    navSpinner = true
    navSpinnerTimer.restart()
  }
  function toggleLike() {
    if (!logic || likePending) return
    likeError = false
    likePending = true
    likeTimeout.restart()
    logic.transport("toggleLike")
  }
  function formatTime(value) {
    var seconds = Math.max(0, Math.round(Number(value || 0)))
    return Math.floor(seconds / 60) + ":" + String(seconds % 60).padStart(2, "0")
  }
  function queueVolume(value) { if (logic) logic.queueVolume(value) }
  function changeVolumeFromWheel(delta) {
    if (!logic || delta === 0) return false
    var wheel = Util.wheelSteps(wheelAccumulator, delta)
    wheelAccumulator = wheel.remainder
    if (wheel.steps === 0) return false
    queueVolume(Number(logic.snapshot.volume || 0) + wheel.steps * 5)
    return true
  }

  implicitWidth: controls.width + Style.space(12)
  implicitHeight: bar ? bar.barSize : Style.bar.sizeHorizontal

  Row {
    id: controls
    anchors.centerIn: parent
    height: root.height
    spacing: Style.space(5)

    Item {
      id: signedOutSlot
      visible: root.signedOut
      width: signedOutRow.width + Style.space(12); height: root.implicitHeight
      Row {
        id: signedOutRow
        anchors.centerIn: parent
        spacing: Style.space(8)
        LucideIcon {
          anchors.verticalCenter: parent.verticalCenter
          name: "log-in"; color: Color.accent; size: Style.space(14)
        }
        Text {
          textFormat: Text.PlainText
          anchors.verticalCenter: parent.verticalCenter
          text: "Войти в Яндекс Музыку"; color: Color.accent
          font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall
        }
      }
      MouseArea {
        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        onClicked: if (root.logic) root.logic.toggle()
        onEntered: if (root.bar) root.bar.showTooltip(parent, "Открыть вход в Яндекс Музыку")
        onExited: if (root.bar) root.bar.hideTooltip(parent)
      }
    }

    Item {
      id: errorSlot
      visible: root.errorState && !root.signedOut
      width: errorRow.width + Style.space(12); height: root.implicitHeight
      Row {
        id: errorRow
        anchors.centerIn: parent
        spacing: Style.space(8)
        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          width: Style.space(7); height: width; radius: width / 2; color: Color.urgent
        }
        Text {
          textFormat: Text.PlainText
          anchors.verticalCenter: parent.verticalCenter
          text: root.errorText; color: Color.urgent
          font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall
        }
      }
      MouseArea {
        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        onClicked: if (root.logic) root.logic.toggle()
        onEntered: if (root.bar) root.bar.showTooltip(parent, "Ошибка Яндекс Музыки — нажмите, чтобы открыть")
        onExited: if (root.bar) root.bar.hideTooltip(parent)
      }
    }

    Row {
      id: transportRow
      visible: root.showControls && !root.signedOut && !root.errorState
      anchors.verticalCenter: parent.verticalCenter
      height: parent.height
      spacing: Style.space(2)
      BarButton {
        bar: root.bar; foreground: root.foreground; filled: true
        name: "skip-back"; tooltip: "Предыдущий (P)"; enabled: root.hasTrack
        onClicked: { root.navigating(); root.logic.transport("previousTrack") }
      }
      BarButton {
        bar: root.bar; foreground: root.foreground; filled: true
        name: root.playing ? "pause" : "play"
        tooltip: root.playing ? "Пауза (Space)" : "Продолжить (Space)"; enabled: root.hasTrack
        onClicked: root.logic.transport("togglePlayback")
      }
      BarButton {
        bar: root.bar; foreground: root.foreground; filled: true
        name: "skip-forward"; tooltip: "Следующий (N)"; enabled: root.hasTrack
        onClicked: { root.navigating(); root.logic.transport("nextTrack") }
      }
      Item { width: Style.space(6); height: 1 }
    }

    Item {
      visible: !root.showCover && !labelSlot.visible && !root.signedOut && !root.errorState
      width: Style.space(24); height: root.implicitHeight
      LucideIcon {
        anchors.centerIn: parent
        name: "audio-lines"; color: Color.accent; size: Style.space(16)
      }
      MouseArea {
        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        onClicked: if (root.logic) root.logic.toggle()
        onEntered: if (root.bar) root.bar.showTooltip(parent, "Открыть Яндекс Музыку")
        onExited: if (root.bar) root.bar.hideTooltip(parent)
      }
    }

    BorderSurface {
      id: cover
      visible: root.showCover && !root.signedOut && !root.errorState
      width: Style.space(20); height: Style.space(20)
      anchors.verticalCenter: parent.verticalCenter
      radius: root.coverShape === "circle" ? width / 2
        : (root.coverShape === "square" ? 0 : Style.space(2))
      color: Style.normalFillFor(root.foreground, Color.accent)
      borderSpec: Border.none()
      opacity: root.dimmed ? .5 : 1
      Rectangle {
        id: coverMask
        anchors.fill: parent
        visible: false
        layer.enabled: true
        radius: cover.radius
        color: "white"
      }
      Image {
        anchors.fill: parent; source: root.logic && root.logic.snapshot.artUrl ? root.logic.snapshot.artUrl : ""
        fillMode: Image.PreserveAspectCrop; asynchronous: true; visible: source !== ""
        layer.enabled: true; layer.smooth: true
        layer.effect: MultiEffect {
          maskEnabled: true; maskSource: coverMask
          maskThresholdMin: .3; maskSpreadAtMin: .3
        }
      }
      LucideIcon {
        anchors.centerIn: parent; visible: !root.logic || !root.logic.snapshot.artUrl
        glyph: "󰝚"; color: root.foreground; fontFamily: root.fontFamily; size: Style.font.caption
      }
      Rectangle {
        anchors.fill: parent
        visible: root.hasError && !root.loading
        radius: cover.radius
        color: Qt.rgba(0, 0, 0, .55)
      }
      Rectangle {
        anchors.fill: parent
        visible: root.loading || root.navSpinner
        radius: cover.radius
        color: Qt.rgba(0, 0, 0, .58)
      }
      Rectangle {
        anchors.centerIn: parent
        visible: root.loading || root.navSpinner
        width: Style.space(14); height: width; radius: width / 2
        color: "transparent"
        border.width: Style.spacing.hairline
        border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, .25)
      }
      Canvas {
        anchors.centerIn: parent
        visible: root.loading || root.navSpinner
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
      LucideIcon {
        anchors.centerIn: parent
        visible: root.hasError && !root.loading
        glyph: "󰀪"; color: Color.urgent
        fontFamily: root.fontFamily; size: Style.font.caption
      }
    }

    Item {
      id: labelSlot
      visible: (root.showArtist || root.showTitle) && !root.signedOut && !root.errorState
      width: {
        var baseW = root.showTitle ? root.informationWidth : Math.min(root.informationWidth, Style.space(105))
        if (root.showBarLyrics && root.syncedLyricsAvailable) return Math.min(baseW, Style.space(130))
        return baseW
      }
      height: root.implicitHeight
      clip: true
      opacity: root.dimmed ? .5 : 1

      Text {
        textFormat: Text.PlainText
        id: trackInfoLabel
        anchors.verticalCenter: parent.verticalCenter
        width: root.longTitleMode === "scroll" ? implicitWidth : parent.width
        text: {
          if (!root.hasTrack) return "Я.Музыка"
          if (root.loading) return "Подключение потока…"
          var parts = []
          var artist = root.logic ? String(root.logic.snapshot.artist || "") : ""
          var title = root.logic ? String(root.logic.snapshot.title || "") : ""
          if (root.showArtist && artist) parts.push(artist)
          if (root.showTitle && title) parts.push(title)
          return parts.join(" — ")
        }
        color: root.loading ? root.foreground : root.foreground; font.family: root.fontFamily
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

    BarButton {
      id: likeButton
      z: 15
      visible: root.showLike && root.hasTrack && !root.signedOut && !root.errorState
      anchors.verticalCenter: parent.verticalCenter
      bar: root.bar; foreground: root.foreground
      readonly property bool liked: root.logic ? root.logic.snapshot.liked === true : false
      readonly property bool shownLiked: root.likePending ? !liked : liked
      name: "heart"
      filled: shownLiked
      iconColor: shownLiked ? Color.accent : root.foreground
      iconOpacity: root.likePending ? .5 : 1
      flash: root.likeFlash
      errorDot: root.likeError
      tooltip: shownLiked ? "Убрать из любимого (L)" : "Нравится (L)"
      onClicked: root.toggleLike()
    }

    Text {
      id: showTimeText
      textFormat: Text.PlainText
      visible: root.showTime && root.hasTrack && !root.signedOut && !root.errorState
      anchors.verticalCenter: parent.verticalCenter
      text: formatTime(Number(root.logic ? root.logic.snapshot.position || 0 : 0)) + " / "
        + formatTime(Number(root.logic ? root.logic.snapshot.duration || 0 : 0))
      color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, .55)
      font.family: root.fontFamily; font.pixelSize: Style.font.caption
    }

    Item {
      id: separatorItem
      visible: root.showBarLyrics && root.hasTrack && root.syncedLyricsAvailable && !root.signedOut && !root.errorState
      width: Style.space(8)
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

    Item {
      id: lyricsSlot
      visible: root.showBarLyrics && root.hasTrack && root.syncedLyricsAvailable && !root.signedOut && !root.errorState
      width: root.lyricsWidth
      height: root.implicitHeight
      clip: true

      property string currentDisplayedText: ""
      property string pendingText: root.targetLyricText

      onPendingTextChanged: {
        if (pendingText === currentDisplayedText) return
        if (lyricTransition.running) lyricTransition.stop()
        if (currentDisplayedText === "") {
          currentDisplayedText = pendingText
          lyricLabel.opacity = 1
          lyricLabel.y = (lyricsSlot.height - lyricLabel.implicitHeight) / 2
        } else {
          lyricTransition.restart()
        }
      }

      Item {
        id: waveHolder
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: lyricsSlot.width
        height: Style.space(20)
        visible: lyricsSlot.currentDisplayedText === "" || lyricsSlot.currentDisplayedText === "♪"

        Canvas {
          id: waveCanvas
          anchors.fill: parent
          antialiasing: true

          property real phase: 0
          readonly property real waveAmp: root.playing ? 1.0 : 0.15

          Timer {
            interval: 25
            running: root.playing && waveHolder.visible
            repeat: true
            onTriggered: {
              waveCanvas.phase += 0.07
              waveCanvas.requestPaint()
            }
          }

          function topY(x, w, h) {
            var baseLine = h - Style.space(2)
            var taperRight = x > (w - Style.space(16)) ? Math.max(0, (w - x) / Style.space(16)) : 1.0
            var waveH = (
              Math.sin(x * 0.038 + waveCanvas.phase) * Style.space(4.5) +
              Math.sin(x * 0.082 + waveCanvas.phase * 1.5) * Style.space(2.8) +
              Math.sin(x * 0.016 - waveCanvas.phase * 0.7) * Style.space(2.0)
            ) * waveAmp * taperRight
            return Math.max(Style.space(2), baseLine - Style.space(3) - Math.max(-Style.space(1), waveH))
          }

          function waveFill(ctx, targetX, h, fillStyle) {
            var base = h - Style.space(2)
            var step = 4
            ctx.beginPath()
            ctx.moveTo(0, base)
            ctx.lineTo(0, topY(0, targetX, h))
            for (var x = step; x <= targetX; x += step) {
              ctx.lineTo(x, topY(x, targetX, h))
            }
            ctx.lineTo(targetX, base)
            ctx.closePath()
            ctx.fillStyle = fillStyle
            ctx.fill()
          }

          onPaint: {
            var ctx = getContext("2d")
            var w = width
            var h = height
            if (w <= 0 || h <= 0) return
            ctx.clearRect(0, 0, w, h)

            var col = Color.accent
            var r = Math.round(col.r * 255)
            var g = Math.round(col.g * 255)
            var b = Math.round(col.b * 255)
            var targetX = w - Style.space(2)

            // Solid filled wave silhouette exactly matching screenshot
            var waveStyle = "rgba(" + r + "," + g + "," + b + ", 0.70)"
            waveFill(ctx, targetX, h, waveStyle)

            // Crisp top crest line for sharpness
            ctx.beginPath()
            ctx.lineWidth = Style.space(1.5)
            ctx.strokeStyle = "rgba(" + r + "," + g + "," + b + ", 0.95)"
            ctx.lineCap = "round"
            ctx.lineJoin = "round"
            var step = 4
            for (var x2 = 0; x2 <= targetX; x2 += step) {
              var y2 = topY(x2, targetX, h)
              if (x2 === 0) ctx.moveTo(x2, y2)
              else ctx.lineTo(x2, y2)
            }
            ctx.stroke()
          }
        }
      }

      Text {
        textFormat: Text.PlainText
        id: lyricLabel
        visible: lyricsSlot.currentDisplayedText !== "" && lyricsSlot.currentDisplayedText !== "♪"
        anchors.left: parent.left
        y: (parent.height - implicitHeight) / 2
        width: Math.min(implicitWidth, parent.width)
        text: lyricsSlot.currentDisplayedText
        color: Color.accent
        opacity: 1.0
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        font.weight: Font.Medium
        elide: root.longTitleMode === "scroll" ? Text.ElideNone : Text.ElideRight
      }

      SequentialAnimation {
        id: lyricMarquee
        running: root.longTitleMode === "scroll" && !lyricTransition.running
          && lyricLabel.implicitWidth > lyricsSlot.width
        loops: Animation.Infinite
        PauseAnimation { duration: 900 }
        NumberAnimation {
          target: lyricLabel; property: "x"
          from: 0; to: Math.min(0, lyricsSlot.width - lyricLabel.implicitWidth)
          duration: Math.max(1200, (lyricLabel.implicitWidth - lyricsSlot.width) * 20)
          easing.type: Easing.InOutSine
        }
        PauseAnimation { duration: 600 }
        NumberAnimation {
          target: lyricLabel; property: "x"; to: 0
          duration: 300; easing.type: Easing.OutCubic
        }
      }
      Connections {
        target: lyricTransition
        function onRunningChanged() { if (lyricTransition.running) lyricLabel.x = 0 }
      }

      SequentialAnimation {
        id: lyricTransition
        ParallelAnimation {
          NumberAnimation {
            target: lyricLabel; property: "opacity"; to: 0; duration: 120; easing.type: Easing.InQuad
          }
          NumberAnimation {
            target: lyricLabel; property: "y"
            to: ((lyricsSlot.height - lyricLabel.implicitHeight) / 2) - Style.space(6)
            duration: 120; easing.type: Easing.InQuad
          }
        }
        ScriptAction {
          script: {
            lyricsSlot.currentDisplayedText = lyricsSlot.pendingText
            lyricLabel.x = 0
            lyricLabel.y = ((lyricsSlot.height - lyricLabel.implicitHeight) / 2) + Style.space(6)
          }
        }
        ParallelAnimation {
          NumberAnimation {
            target: lyricLabel; property: "opacity"
            to: lyricsSlot.currentDisplayedText !== "" ? 1.0 : 0.4
            duration: 220; easing.type: Easing.OutCubic
          }
          NumberAnimation {
            target: lyricLabel; property: "y"
            to: (lyricsSlot.height - lyricLabel.implicitHeight) / 2
            duration: 220; easing.type: Easing.OutCubic
          }
        }
      }
    }

    Item {
      id: volumeSlot
      visible: root.showVolume && !root.signedOut && !root.errorState
      width: Style.space(24) + Style.space(6) + Style.space(64) + Style.space(8) + Style.space(30)
      height: root.height
      enabled: !root.hasError
      opacity: root.hasError ? .35 : 1

      readonly property real volumeValue: Math.max(0, Math.min(100,
        Number(root.logic ? root.logic.snapshot.volume || 0 : 0)))
      readonly property bool muted: root.logic ? root.logic.snapshot.muted === true : false
      readonly property bool zoneHot: zoneHover.hovered || volumeMouse.containsMouse || volumeButton.containsMouse
      property bool dragging: false
      property real dragValue: 0
      property bool flashing: false
      readonly property real shownValue: dragging ? dragValue : volumeValue

      HoverHandler { id: zoneHover }

      BarButton {
        id: volumeButton
        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
        bar: root.bar; foreground: root.foreground
        iconColor: volumeSlot.muted ? Color.accent : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, .7)
        name: volumeSlot.muted ? "volume-x" : (volumeSlot.volumeValue < 34 ? "volume-1" : "volume-2")
        filled: false
        tooltip: volumeSlot.muted ? "Включить звук · ЛКМ" : "Выкл. звук · ЛКМ"
        onClicked: root.logic.transport("toggleMute")
        onWheel: function(wheel) { volumeSlot.handleWheel(wheel) }
      }

      function handleWheel(wheel) {
        if (!root.logic || wheel.angleDelta.y === 0) return
        root.changeVolumeFromWheel(wheel.angleDelta.y)
        flashing = true
        flashTimer.restart()
        wheel.accepted = true
      }

      Timer { id: flashTimer; interval: 600; onTriggered: volumeSlot.flashing = false }

      Item {
        id: volumeTrackArea
        anchors.left: volumeButton.right; anchors.leftMargin: Style.space(6)
        anchors.verticalCenter: parent.verticalCenter
        width: Style.space(64); height: parent.height

        Rectangle {
          id: volumeTrack
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width
          height: volumeSlot.zoneHot || volumeSlot.dragging ? Style.space(4) : Style.space(3)
          radius: volumeSlot.zoneHot || volumeSlot.dragging ? height / 2 : 0
          color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, .14)
          Rectangle {
            width: parent.width * volumeSlot.shownValue / 100
            height: parent.height; radius: parent.radius
            color: volumeSlot.dragging ? Color.accent
              : (volumeSlot.muted ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, .4)
                : root.foreground)
          }
          Rectangle {
            visible: (volumeSlot.zoneHot || volumeSlot.dragging) && !volumeSlot.muted
            x: Math.max(0, Math.min(parent.width, parent.width * volumeSlot.shownValue / 100)) - width / 2
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(10); height: width; radius: width / 2
            color: volumeSlot.dragging ? Color.accent : root.foreground
          }
        }

        MouseArea {
          id: volumeMouse
          anchors.fill: parent
          hoverEnabled: true
          preventStealing: true
          cursorShape: Qt.PointingHandCursor
          function ratio(x) { return Math.max(0, Math.min(100, Math.round(x / Math.max(1, width) * 100))) }
          // The bar host owns press/move, so a drag usually arrives as a plain
          // click; both paths apply the value when the button is released.
          onPressed: function(mouse) { volumeSlot.dragging = true; volumeSlot.dragValue = ratio(mouse.x) }
          onPositionChanged: function(mouse) { if (pressed) volumeSlot.dragValue = ratio(mouse.x) }
          onReleased: function(mouse) {
            if (volumeSlot.dragging) root.queueVolume(ratio(mouse.x))
            volumeSlot.dragging = false
          }
          onCanceled: volumeSlot.dragging = false
          onClicked: function(mouse) { root.queueVolume(ratio(mouse.x)) }
          onWheel: function(wheel) { volumeSlot.handleWheel(wheel) }
          onEntered: if (root.bar && !volumeSlot.dragging) root.bar.showTooltip(volumeTrackArea,
            "Громкость " + Math.round(volumeSlot.volumeValue) + "% — колесо ±5%, клик — в точку")
          onExited: if (root.bar) root.bar.hideTooltip(volumeTrackArea)
        }
      }

      Text {
        textFormat: Text.PlainText
        id: volumePercent
        anchors.left: volumeTrackArea.right; anchors.leftMargin: Style.space(8)
        anchors.verticalCenter: parent.verticalCenter
        text: root.hasError ? "—" : (volumeSlot.muted ? "mute"
          : Math.round(volumeSlot.shownValue) + "%")
        color: volumeSlot.dragging || volumeSlot.flashing || volumeSlot.muted ? Color.accent
          : (volumeSlot.zoneHot ? root.foreground
            : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, .55))
        font.family: root.fontFamily; font.pixelSize: Style.font.caption
        Behavior on color { ColorAnimation { duration: 120 } }
      }
    }
  }

  Rectangle {
    visible: infoArea.containsMouse && infoArea.visible
    x: infoArea.x; y: infoArea.y; width: infoArea.width; height: infoArea.height
    color: Style.hoverFillFor(root.foreground, Color.accent)
  }
  MouseArea {
    id: infoArea
    visible: (cover.visible || labelSlot.visible) && !root.signedOut && !root.errorState
    x: controls.x + (cover.visible ? cover.x : labelSlot.x) - Style.space(4)
    y: 0
    width: {
      var startX = cover.visible ? cover.x : labelSlot.x
      var endX = lyricsSlot.visible ? (lyricsSlot.x + lyricsSlot.width)
        : (showTimeText.visible ? (showTimeText.x + showTimeText.width)
          : (likeButton.visible ? (likeButton.x + likeButton.width) : (labelSlot.x + labelSlot.width)))
      return (endX - startX) + Style.space(8)
    }
    height: root.height
    z: 10
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    cursorShape: Qt.PointingHandCursor
    onClicked: function(mouse) {
      if (!root.logic) return
      if (root.barMouseControls) {
        var onCover = cover.visible && mouse.x < (labelSlot.x - cover.x + Style.space(4))
        if (onCover) {
          root.logic.toggle()
          return
        }
        if (mouse.button === Qt.LeftButton) {
          if (root.hasTrack) root.logic.transport("togglePlayback")
        } else if (mouse.button === Qt.RightButton) {
          if (root.hasTrack) { root.navigating(); root.logic.transport("nextTrack") }
        } else if (mouse.button === Qt.MiddleButton) {
          if (root.hasTrack) { root.navigating(); root.logic.transport("previousTrack") }
        }
      } else {
        if (mouse.button === Qt.RightButton) {
          if (root.hasTrack) root.logic.transport("togglePlayback")
        } else {
          root.logic.toggle()
        }
      }
    }
    function isOverLyrics(xPos) {
      if (!lyricsSlot.visible || !root.syncedLyricsAvailable) return false
      var lyricsStartX = controls.x + lyricsSlot.x
      var currentX = infoArea.x + xPos
      return currentX >= lyricsStartX
    }

    onWheel: function(wheel) {
      if (!root.logic || wheel.angleDelta.y === 0) return
      wheel.accepted = true
      if (root.barMouseControls) {
        if (!root.hasTrack) return
        var pos = root.displayPosition
        var dur = Number(root.logic.snapshot.duration || 0)
        var overLyrics = isOverLyrics(wheel.x)

        if (wheel.angleDelta.y > 0) {
          // Scroll Up:
          // If over synced lyrics -> seek to next lyric line
          if (overLyrics && root.lyricsLines.length > 0) {
            var nextTime = -1
            for (var i = 0; i < root.lyricsLines.length; i++) {
              var t = Number(root.lyricsLines[i].time || 0)
              if (t > pos + 0.3) { nextTime = t; break }
            }
            if (nextTime >= 0) {
              root.logic.transport("seek", Math.round(nextTime))
              return
            }
          }
          // Otherwise (over title, cover, or rest of bar) -> seek +5s
          var targetForward = Math.min(dur > 0 ? dur : pos + 5, pos + 5)
          root.logic.transport("seek", Math.round(targetForward))
        } else {
          // Scroll Down:
          // If over synced lyrics -> seek to previous lyric line
          if (overLyrics && root.lyricsLines.length > 0) {
            var prevTime = -1
            for (var j = root.lyricsLines.length - 1; j >= 0; j--) {
              var pt = Number(root.lyricsLines[j].time || 0)
              if (pt < pos - 0.5) { prevTime = pt; break }
            }
            if (prevTime >= 0) {
              root.logic.transport("seek", Math.round(prevTime))
              return
            }
          }
          // Otherwise (over title, cover, or rest of bar) -> seek -5s
          var targetBack = Math.max(0, pos - 5)
          root.logic.transport("seek", Math.round(targetBack))
        }
      } else {
        root.changeVolumeFromWheel(wheel.angleDelta.y)
      }
    }
    onEntered: if (root.bar) {
      if (root.barMouseControls && root.hasTrack) {
        var tip = root.label
        if (root.targetLyricText !== "") tip += "\n[Текст] " + root.targetLyricText
        tip += "\nОбложка: меню · ЛКМ: пауза · ПКМ: след. · СКМ: пред. · колесо: ±5 сек (над текстом: по строкам)"
        root.bar.showTooltip(root, tip)
      } else {
        root.bar.showTooltip(root,
          root.hasTrack ? "ЛКМ — плеер · ПКМ — пауза · колесо — громкость" : root.label)
      }
    }
    onExited: if (root.bar) root.bar.hideTooltip(root)
  }

  Timer { id: navSpinnerTimer; interval: 1200; onTriggered: root.navSpinner = false }
  Timer { id: likeFlashTimer; interval: 200; onTriggered: root.likeFlash = false }
  Timer { id: likeErrorTimer; interval: 3000; onTriggered: root.likeError = false }
  Timer {
    id: likeTimeout
    interval: 4000
    onTriggered: if (root.likePending) { root.likePending = false; root.likeError = true; likeErrorTimer.restart() }
  }
  readonly property bool likedState: logic ? logic.snapshot.liked === true : false
  onLikedStateChanged: if (likePending) {
    likePending = false
    likeTimeout.stop()
    likeFlash = true
    likeFlashTimer.restart()
  }
  onLoadingChanged: if (!loading) navSpinner = false
  onHasErrorChanged: if (hasError && likePending) {
    likePending = false
    likeTimeout.stop()
    likeError = true
    likeErrorTimer.restart()
  }

  Timer {
    interval: 16
    repeat: true
    running: root.loading || root.navSpinner
    onTriggered: root.loaderAngle = (root.loaderAngle + 7.2) % 360
  }

  Rectangle {
    id: progressBarContainer
    visible: root.hasTrack && root.showProgress
    x: controls.x + (cover.visible ? cover.x : labelSlot.x)
    anchors.bottom: parent.bottom
    width: {
      var startX = cover.visible ? cover.x : labelSlot.x
      var endX = separatorItem.visible
        ? separatorItem.x
        : (showTimeText.visible ? (showTimeText.x + showTimeText.width)
          : (likeButton.visible ? (likeButton.x + likeButton.width) : (labelSlot.x + labelSlot.width)))
      return Math.max(Style.space(40), endX - startX)
    }
    height: Style.space(2)
    color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, .15)
    opacity: root.dimmed ? .5 : 1

    Rectangle {
      width: parent.width * (root.logic
        ? Math.min(1, root.displayPosition / Math.max(1, Number(root.logic.snapshot.duration || 1)))
        : 0)
      height: parent.height
      color: Color.accent
    }
  }
}
