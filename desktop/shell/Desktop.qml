import QtQuick
import MpireOS.Style
import "wallpaper"

// Mpire Desktop as one scene, for previews. In the running shell, the
// wallpaper, top bar, and dock are separate layer-shell surfaces built from
// these same components.
Item {
    id: desktop
    property date now: new Date()
    // Previews have no desktopSettings unless tools/preview.py provides one.
    readonly property bool hasSettings: typeof desktopSettings !== "undefined"

    Wallpaper {
        anchors.fill: parent
        source: desktop.hasSettings ? desktopSettings.wallpaper : "mpire:fjord"
        fillMode: desktop.hasSettings ? desktopSettings.fillMode : "fill"
    }

    TopBar {
        anchors { left: parent.left; right: parent.right; top: parent.top }
        now: desktop.now
        battery: 98; showNotifications: true
        workspaceCount: typeof workspaces !== "undefined" ? workspaces.count : 3
        currentWorkspace: typeof workspaces !== "undefined" ? workspaces.current : 0
        onWorkspaceClicked: index => { if (typeof workspaces !== "undefined") workspaces.activate(index) }
        trayItems: typeof systemTray !== "undefined" ? systemTray.items : []
        openTrayKey: typeof systemTray !== "undefined" && typeof shellApi !== "undefined" && shellApi.panel === "tray-menu" ? systemTray.menuKey : ""
    }

    Dock {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10
        now: desktop.now
    }
}
