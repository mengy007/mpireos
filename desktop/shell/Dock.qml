import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import MpireOS.Style

// The dock: launcher, pinned and running apps, settings. Icons float on the
// desktop with no panel behind them.
Item {
    id: dock
    property date now: new Date()
    property real iconSize: 40
    implicitWidth: row.implicitWidth + 20
    implicitHeight: iconSize + 16

    // Asks the shell to run a command, or to open the launcher.
    signal launch(string command)
    signal openLauncher()

    component Divider: Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: 26; color: Theme.border }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 8

        AppIcon { size: dock.iconSize; glyph: "grid"; glyphColor: Theme.textSecondary; onClicked: dock.openLauncher() }
        Divider {}
        AppIcon { size: dock.iconSize; glyph: "folder"; topColor: "#B5CDEE"; bottomColor: "#83A9D8"; glyphColor: "white"; command: "dolphin"; onClicked: dock.launch(command) }
        AppIcon { size: dock.iconSize; glyph: "globe"; topColor: "#BFE3DA"; bottomColor: "#8CCBBB"; glyphColor: "white"; command: "firefox"; onClicked: dock.launch(command) }
        AppIcon { size: dock.iconSize; glyph: "notes"; topColor: "#FBE6A6"; bottomColor: "#F2CF77"; glyphColor: "#A77B1F"; command: "kate"; onClicked: dock.launch(command) }
        AppIcon {
            size: dock.iconSize
            glyph: ""
            ColumnLayoutCal { anchors.centerIn: parent; now: dock.now; scale: dock.iconSize / 52 }
        }
        AppIcon { size: dock.iconSize; glyph: "image"; topColor: "#DCCDF3"; bottomColor: "#B6A1E4"; glyphColor: "#5E4BB8"; command: "gwenview"; onClicked: dock.launch(command) }
        AppIcon { size: dock.iconSize; glyph: "terminal"; topColor: "#5B7C86"; bottomColor: "#0B3A44"; glyphColor: "white"; command: "konsole"; onClicked: dock.launch(command) }
        Divider {}
        AppIcon { size: dock.iconSize; glyph: "settings"; topColor: "#DDE2EA"; bottomColor: "#B9C2D0"; glyphColor: "#5A6475"; command: "systemsettings"; onClicked: dock.launch(command) }
    }
}
