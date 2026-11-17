import QtQuick
import "../wallpaper"

// The desktop itself (layer-shell background layer): just the wallpaper, kept
// clear on purpose. Right-click opens the desktop menu (wallpaper, display,
// dock, settings) on the panel overlay.
// Context properties: shellApi (src/shellapi.h), desktopSettings (src/desktopsettings.h).
Item {
    id: desktop

    Wallpaper {
        anchors.fill: parent
        source: desktopSettings.wallpaper
        fillMode: desktopSettings.fillMode
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton)
                shellApi.openDesktopMenu(mouse.x, mouse.y)
            else
                shellApi.panel = ""
        }
        // Touch screens: press and hold.
        onPressAndHold: mouse => shellApi.openDesktopMenu(mouse.x, mouse.y)
    }
}
