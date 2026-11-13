import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import MpireOS.Style

// The dock: launcher, pinned and running apps, settings. Icons float on the
// desktop with no panel behind them.
Item {
    id: dock
    property date now: new Date()
    implicitWidth: row.implicitWidth + 28
    implicitHeight: 72

    // Asks the shell to run a command (an app, or the app search).
    signal launch(string command)

    component Divider: Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: 36; color: Theme.border }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 12

        AppIcon { glyph: "grid"; glyphColor: Theme.textSecondary; command: "krunner"; onClicked: dock.launch(command) }
        Divider {}
        AppIcon { glyph: "folder"; topColor: "#B5CDEE"; bottomColor: "#83A9D8"; glyphColor: "white"; command: "dolphin"; onClicked: dock.launch(command) }
        AppIcon { glyph: "globe"; topColor: "#BFE3DA"; bottomColor: "#8CCBBB"; glyphColor: "white"; command: "firefox"; onClicked: dock.launch(command) }
        AppIcon { glyph: "notes"; topColor: "#FBE6A6"; bottomColor: "#F2CF77"; glyphColor: "#A77B1F"; command: "kate"; onClicked: dock.launch(command) }
        AppIcon {
            glyph: ""
            ColumnLayoutCal { anchors.centerIn: parent; now: dock.now }
        }
        AppIcon { glyph: "image"; topColor: "#DCCDF3"; bottomColor: "#B6A1E4"; glyphColor: "#6A55C4"; command: "gwenview"; onClicked: dock.launch(command) }
        AppIcon { glyph: "terminal"; topColor: "#D9D4E6"; bottomColor: "#A9A1C0"; glyphColor: "white"; command: "konsole"; onClicked: dock.launch(command) }
        Divider {}
        AppIcon { glyph: "settings"; topColor: "#DDE2EA"; bottomColor: "#B9C2D0"; glyphColor: "#5A6475"; command: "systemsettings"; onClicked: dock.launch(command) }
    }
}
