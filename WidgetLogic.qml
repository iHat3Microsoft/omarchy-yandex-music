import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root
  property var bar: null
  property var settings: ({})
  property var anchorItem: null
  property var hostWidget: null
  readonly property string cli: Quickshell.env("HOME") + "/.local/bin/omarchy-yandex-music"
  readonly property string pluginDir: Quickshell.env("HOME") + "/.config/omarchy/plugins/vornashev.yandex-music"
  property var data: ({ title: "", artist: "", playing: false })
  property string statusError: ""
  property string bootstrapError: ""
  readonly property string currentTrackId: String(data.trackId || "")
  readonly property var lyricsData: (data && data.lyrics && String(data.lyrics.trackId || "") === currentTrackId)
    ? data.lyrics
    : ({ trackId: currentTrackId, loading: false, available: false, synced: false, lines: [] })
  readonly property bool hasTrack: String(data.title || "") !== ""
  readonly property bool loading: bootstrapProcess.running || data.loading === true || data.connecting === true || data.restoring === true
  readonly property string error: bootstrapError || statusError || String(data.error || "")
  property var optimisticPlaying: null
  property var optimisticLiked: null
  readonly property bool playing: optimisticPlaying !== null ? Boolean(optimisticPlaying) : (data.playing === true)
  readonly property bool liked: optimisticLiked !== null ? Boolean(optimisticLiked) : (data.liked === true)
  property var actionQueue: []
  readonly property string shortTitle: {
    var title = String(data.title || "")
    return title.length > 28 ? title.slice(0, 28) + "…" : title
  }
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    target.bar = root.bar
    target.settings = root.settings
    target.anchorItem = root.anchorItem
    target.hostWidget = root.hostWidget
  }
  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function toggle() { if (panelLoader.item) panelLoader.item.toggle() }
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch() }
  function showArtist(artistId) {
    if (!artistId) return
    if (panelLoader.item) {
      if (panelLoader.item.selectPage) panelLoader.item.selectPage(2)
      else panelLoader.item.page = 2
    }
    open()
    action("catalog_artist", artistId)
  }

  function refresh() {
    if (!statusProcess.running) {
      statusProcess.command = [cli, "status"]
      statusProcess.running = true
    }
  }
  function action(name, argument) {
    if (name === "pause" && root.hasTrack) {
      optimisticPlaying = !root.playing
    } else if (name === "like" && root.hasTrack) {
      optimisticLiked = !root.liked
    }
    var args = [cli, name]
    if (argument !== undefined && argument !== null) args.push(String(argument))
    if (actionProcess.running) {
      if (name === "seek" && actionQueue.length > 0 && actionQueue[actionQueue.length - 1][1] === "seek") {
        actionQueue[actionQueue.length - 1] = args
        return
      }
      actionQueue.push(args)
      return
    }
    actionProcess.command = args
    actionProcess.running = true
  }

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()
  onAnchorItemChanged: injectPanel()

  Component.onCompleted: {
    bootstrapProcess.command = [pluginDir + "/bootstrap.sh"]
    bootstrapProcess.running = true
  }

  Process {
    id: bootstrapProcess
    command: []
    stderr: StdioCollector { id: bootstrapErr; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        var message = String(bootstrapErr.text || "").trim()
        root.bootstrapError = message || "Не удалось установить фоновый музыкальный сервис"
        return
      }
      root.bootstrapError = ""
      settle.restart()
    }
  }
  Process {
    id: statusProcess
    command: []
    stdout: StdioCollector { id: statusOut; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.statusError = "Фоновый музыкальный сервис недоступен"
        return
      }
      try {
        root.data = JSON.parse(statusOut.text || "{}")
        root.statusError = ""
        root.optimisticPlaying = null
        root.optimisticLiked = null
        if (root.data.lyrics && root.data.lyrics.loading === true) {
          settle.interval = 250
          settle.restart()
        }
      } catch (e) {
        root.statusError = "Музыкальный сервис вернул некорректный ответ"
      }
    }
  }
  Process {
    id: actionProcess
    command: []
    stdout: StdioCollector { id: actionOut; waitForEnd: true }
    onExited: {
      if (actionOut.text) {
        try {
          var res = JSON.parse(actionOut.text || "{}")
          if (res.title !== undefined) {
            root.data = res
            root.optimisticPlaying = null
            root.optimisticLiked = null
          }
        } catch (e) {}
      }
      if (actionQueue.length > 0) {
        var nextArgs = actionQueue.shift()
        actionProcess.command = nextArgs
        actionProcess.running = true
        return
      }
      settle.interval = 60
      settle.restart()
    }
  }
  Timer {
    interval: root.opened || root.playing ? 1000 : 3000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }
  Timer {
    id: settle
    interval: 300
    repeat: false
    onTriggered: root.refresh()
  }
  Loader {
    id: panelLoader
    active: true
    visible: false
    source: Qt.resolvedUrl("Panel.qml")
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }
}
