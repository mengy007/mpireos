import QtQuick
import ".."

// The top bar (layer-shell top layer, full width, reserves its height).
TopBar {
    id: surface
    battery: systemStatus.battery
    unread: notifications.unread
    online: systemStatus.networkKind.length > 0
    wired: systemStatus.networkKind === "wired"
    trayItems: systemTray.items
    openTrayKey: shellApi.panel === "tray-menu" ? systemTray.menuKey : ""
    Timer { interval: 5000; repeat: true; running: true; triggeredOnStart: true; onTriggered: surface.now = new Date() }
    onSearchClicked: shellApi.TogglePanel("search")
    onTrayActivated: (key, x) => systemTray.activate(key, x)
    onTrayMenuRequested: (key, x) => {
        if (shellApi.panel === "tray-menu" && systemTray.menuKey === key) shellApi.panel = ""
        else systemTray.openMenu(key, x)
    }
    onTraySecondaryActivated: (key, x) => systemTray.secondaryActivate(key, x)
    onTrayScrolled: (key, delta, horizontal) => systemTray.scroll(key, delta, horizontal)
    onNotificationsClicked: shellApi.TogglePanel("notifications")
    onNetworkClicked: shellApi.TogglePanel("quick-settings")
    onSettingsClicked: shellApi.TogglePanel("quick-settings")
}
