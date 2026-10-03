import QtQuick
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "vornashev.yandex-music"

  readonly property var logic: logicLoader.item
  readonly property bool hasTrack: logic ? logic.hasTrack : false
  readonly property bool playing: logic ? logic.playing : false
  readonly property bool opened: logic ? logic.opened : false
  readonly property bool popoutSwitchClosing: logic ? logic.popoutSwitchClosing : false
  // Suppress Omarchy's extra underline while this widget's popup is open.
  readonly property real openPanelIndicatorWidth: 0.01

  function injectLogic() {
    if (!logic) return
    logic.bar = root.bar
    logic.settings = root.settings
    logic.anchorItem = (playerLoader.item && playerLoader.item.coverItem) ? playerLoader.item.coverItem : (playerLoader.item || root)
    logic.hostWidget = root
  }
  function open() { if (logic) logic.open() }
  function close() { if (logic) logic.close() }
  function closeForPopoutSwitch() { if (logic) logic.closeForPopoutSwitch() }
  function triggerPress(button) {
    if (logic) {
      if (button === Qt.LeftButton) logic.action("pause")
      else if (button === Qt.RightButton) logic.action("next")
      else if (button === Qt.MiddleButton) logic.action("previous")
    }
  }

  implicitWidth: playerLoader.item ? playerLoader.item.implicitWidth : 0
  implicitHeight: playerLoader.item ? playerLoader.item.implicitHeight : barSize
  onBarChanged: injectLogic()
  onSettingsChanged: injectLogic()

  Loader {
    id: logicLoader
    active: true
    visible: false
    source: Qt.resolvedUrl("WidgetLogic.qml")
    onLoaded: {
      root.injectLogic()
      Qt.callLater(root.injectLogic)
    }
  }

  Loader {
    id: playerLoader
    anchors.fill: parent
    active: true
    source: Qt.resolvedUrl("BarPlayer.qml")
    onLoaded: {
      root.injectLogic()
      Qt.callLater(root.injectLogic)
    }
  }

  Binding {
    target: playerLoader.item
    property: "logic"
    value: root.logic
    when: playerLoader.item !== null
  }
  Binding {
    target: playerLoader.item
    property: "bar"
    value: root.bar
    when: playerLoader.item !== null
  }
  Binding {
    target: playerLoader.item
    property: "hostWidget"
    value: root
    when: playerLoader.item !== null
  }

  Connections {
    target: root
    function onBarChanged() { root.injectLogic() }
    function onLogicChanged() { root.injectLogic() }
  }
}
