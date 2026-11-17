import QtQuick
import ".."

// The dock (layer-shell top layer, bottom center). Sized to its icons.
Dock {
    id: surface
    Timer { interval: 60000; repeat: true; running: true; triggeredOnStart: true; onTriggered: surface.now = new Date() }
    onLaunch: command => shellApi.launch(command)
    onOpenLauncher: shellApi.TogglePanel("launcher")
}
