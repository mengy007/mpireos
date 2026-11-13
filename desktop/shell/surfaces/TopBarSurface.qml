import QtQuick
import ".."

// The top bar (layer-shell top layer, full width, reserves its height).
TopBar {
    id: surface
    battery: systemStatus.battery
    unread: notifications.unread
    online: systemStatus.networkKind.length > 0
    wired: systemStatus.networkKind === "wired"
    Timer { interval: 5000; repeat: true; running: true; triggeredOnStart: true; onTriggered: surface.now = new Date() }
    onSearchClicked: shellApi.TogglePanel("launcher")
    onNotificationsClicked: shellApi.TogglePanel("notifications")
    onNetworkClicked: shellApi.TogglePanel("quick-settings")
    onSettingsClicked: shellApi.TogglePanel("quick-settings")
}
