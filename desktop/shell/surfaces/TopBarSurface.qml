import QtQuick
import ".."

// The top bar (layer-shell top layer, full width, reserves its height).
TopBar {
    id: surface
    battery: shellApi.battery
    Timer { interval: 5000; repeat: true; running: true; triggeredOnStart: true; onTriggered: surface.now = new Date() }
    onSearchClicked: shellApi.launch("krunner")
    onNetworkClicked: shellApi.launch("kcmshell6 kcm_networkmanagement")
    onSettingsClicked: shellApi.launch("systemsettings")
}
