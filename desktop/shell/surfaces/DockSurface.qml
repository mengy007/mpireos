import QtQuick
import MpireOS.Style
import ".."

// The dock (layer-shell top layer, along the bottom edge). It hides itself:
// it slides out of sight when the pointer leaves, and slides back up when the
// pointer touches the bottom edge of the screen. mpire-shell limits the
// surface's input to `inputArea`, so while hidden only a thin strip at the
// bottom edge catches the pointer and windows get every other click.
Item {
    id: surface
    property bool revealed: true          // shown for a moment at login, then hides
    readonly property int margin: 16      // space under the dock when it is up
    property date now: new Date()

    implicitWidth: dock.implicitWidth
    implicitHeight: dock.implicitHeight + margin

    Timer { interval: 60000; repeat: true; running: true; triggeredOnStart: true; onTriggered: surface.now = new Date() }

    HoverHandler {
        id: hover
        onHoveredChanged: {
            if (hovered) {
                hideTimer.stop()
                surface.revealed = true
            } else {
                hideTimer.restart()
            }
        }
    }
    Timer {
        id: hideTimer
        interval: 2500                     // first time: let people see the dock exists
        running: true
        onTriggered: {
            interval = 600
            if (!hover.hovered) surface.revealed = false
        }
    }

    Dock {
        id: dock
        width: implicitWidth
        height: implicitHeight
        x: Math.round((surface.width - width) / 2)
        y: surface.revealed ? surface.height - height - surface.margin : surface.height + 6
        opacity: surface.revealed ? 1 : 0
        scale: surface.revealed ? 1 : 0.96
        now: surface.now
        Behavior on y { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
        onLaunch: command => shellApi.launch(command)
        onOpenLauncher: shellApi.TogglePanel("launcher")
    }

    // Where the surface takes pointer input: the dock and the space below it
    // while shown, a 2 px strip along the bottom edge while hidden.
    Item {
        id: inputArea
        objectName: "inputArea"
        x: surface.revealed ? dock.x - 12 : 0
        width: surface.revealed ? dock.width + 24 : surface.width
        y: surface.revealed ? surface.height - dock.height - surface.margin - 8 : surface.height - 2
        height: surface.height - y
    }
}
