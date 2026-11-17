import QtQuick
import MpireOS.Style
import "../panels"

// Full-screen overlay (layer-shell overlay layer) that mpire-shell shows only
// while a panel is open: the launcher, quick settings, the notification list,
// the desktop's right-click menu, or the wallpaper picker. Clicking outside
// the panel or pressing Esc closes it.
// Context properties: shellApi, appIndex, notifications, systemStatus, desktopSettings.
Item {
    id: surface
    readonly property string panel: shellApi.panel
    property date now: new Date()

    function close() { shellApi.panel = "" }

    focus: true
    Keys.onEscapePressed: close()

    Connections {
        target: shellApi
        function onPanelChanged() {
            surface.now = new Date()
            if (shellApi.panel === "launcher") launcher.reset()
            else surface.forceActiveFocus()          // so Esc closes this panel too
            if (shellApi.panel === "notifications") notifications.markRead()
            if (shellApi.panel === "quick-settings") { quick.confirm = ""; systemStatus.refresh() }
            if (shellApi.panel === "desktop-menu") { desktopMenu.reset(); desktopMenu.forceActiveFocus() }
            if (shellApi.panel === "wallpaper") { desktopSettings.refreshPictures(); picker.forceActiveFocus() }
        }
    }

    // Dim the desktop behind the launcher; other panels float without a scrim.
    Rectangle {
        anchors.fill: parent
        color: Theme.text
        opacity: surface.panel === "launcher" ? 0.16 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }
    }
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        // Right-click outside the desktop menu moves it there; anything else closes.
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton && surface.panel === "desktop-menu")
                shellApi.openDesktopMenu(mouse.x, mouse.y)
            else
                surface.close()
        }
    }

    Launcher {
        id: launcher
        objectName: "launcher"
        visible: surface.panel === "launcher"
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.max(70, parent.height * 0.16)
        height: implicitHeight
        apps: appIndex.apps
        onOpenApp: id => appIndex.launch(id)
        onRunCommand: command => shellApi.launch(command)
        onRunAction: action => systemStatus[action]()
        onCopyText: text => shellApi.copy(text)
        onOpenUrl: url => shellApi.openUrl(url)
        onClose: surface.close()
        MouseArea { anchors.fill: parent; z: -1 }     // clicks inside don't close it
    }

    QuickSettings {
        id: quick
        visible: surface.panel === "quick-settings"
        anchors { right: parent.right; rightMargin: 12; top: parent.top; topMargin: Theme.topBarHeight + 8 }
        height: implicitHeight
        status: systemStatus
        notifier: notifications
        onOpenCommand: command => { shellApi.launch(command); surface.close() }
        MouseArea { anchors.fill: parent; z: -1 }
    }

    NotificationCenter {
        visible: surface.panel === "notifications"
        anchors { right: parent.right; rightMargin: 12; top: parent.top; topMargin: Theme.topBarHeight + 8 }
        height: implicitHeight
        server: notifications
        now: surface.now
        onLinkOpened: url => { shellApi.openUrl(url); surface.close() }
        MouseArea { anchors.fill: parent; z: -1 }
    }

    DesktopMenu {
        id: desktopMenu
        objectName: "desktopMenu"
        readonly property point at: shellApi.menuPosition
        readonly property bool centered: at.x < 0
        visible: surface.panel === "desktop-menu"
        height: implicitHeight
        // At the pointer, flipped left or up when it would run off the screen.
        x: centered ? Math.round((surface.width - width) / 2)
           : at.x + width + 8 <= surface.width ? at.x : Math.max(8, at.x - width)
        y: centered ? Math.round((surface.height - height) / 2)
           : at.y + height + 8 <= surface.height ? Math.max(Theme.topBarHeight + 4, at.y) : Math.max(Theme.topBarHeight + 4, at.y - height)
        dockAutoHide: desktopSettings.dockAutoHide
        onChangeWallpaper: shellApi.panel = "wallpaper"
        onRun: command => { shellApi.launch(command); surface.close() }
        onSetDockAutoHide: on => desktopSettings.dockAutoHide = on
        Keys.onEscapePressed: surface.close()
        MouseArea { anchors.fill: parent; z: -1 }
        // A quick, soft pop from the pointer.
        transformOrigin: Item.TopLeft
        opacity: visible ? 1 : 0
        scale: visible ? 1 : 0.94
        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
        Behavior on scale { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }
    }

    WallpaperPicker {
        id: picker
        objectName: "wallpaperPicker"
        visible: surface.panel === "wallpaper"
        anchors.horizontalCenter: parent.horizontalCenter
        // Low on the screen, so the wallpaper shows above it.
        maxHeight: surface.height - Theme.topBarHeight - 48
        height: implicitHeight
        y: Math.max(Theme.topBarHeight + 24, surface.height - height - 40)
        settings: desktopSettings
        onDone: surface.close()
        MouseArea { anchors.fill: parent; z: -1 }
    }
}
