import QtQuick
import MpireOS.Style
import "../panels"

// Full-screen overlay (layer-shell overlay layer) that mpire-shell shows only
// while a panel is open: the launcher, quick settings, or the notification
// list. Clicking outside the panel or pressing Esc closes it.
// Context properties: shellApi, appIndex, notifications, systemStatus.
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
        }
    }

    // Dim the desktop behind the launcher; other panels float without a scrim.
    Rectangle {
        anchors.fill: parent
        color: Theme.text
        opacity: surface.panel === "launcher" ? 0.16 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }
    }
    MouseArea { anchors.fill: parent; onClicked: surface.close() }

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
        anchors { right: parent.right; rightMargin: 12; top: parent.top; topMargin: 44 + 8 }
        height: implicitHeight
        status: systemStatus
        notifier: notifications
        onOpenCommand: command => { shellApi.launch(command); surface.close() }
        MouseArea { anchors.fill: parent; z: -1 }
    }

    NotificationCenter {
        visible: surface.panel === "notifications"
        anchors { right: parent.right; rightMargin: 12; top: parent.top; topMargin: 44 + 8 }
        height: implicitHeight
        server: notifications
        now: surface.now
        onLinkOpened: url => { shellApi.openUrl(url); surface.close() }
        MouseArea { anchors.fill: parent; z: -1 }
    }
}
