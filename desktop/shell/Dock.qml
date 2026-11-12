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

    component Divider: Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: 36; color: Theme.border }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 12

        AppIcon { glyph: "grid"; glyphColor: Theme.textSecondary }
        Divider {}
        AppIcon { glyph: "folder"; topColor: "#B5CDEE"; bottomColor: "#83A9D8"; glyphColor: "white"; running: true }
        AppIcon { glyph: "notes"; topColor: "#FBE6A6"; bottomColor: "#F2CF77"; glyphColor: "#A77B1F" }
        AppIcon {
            glyph: ""
            ColumnLayoutCal { anchors.centerIn: parent; now: dock.now }
        }
        AppIcon { glyph: "image"; topColor: "#DCCDF3"; bottomColor: "#B6A1E4"; glyphColor: "#6A55C4" }
        AppIcon { glyph: "headphones"; topColor: "#F7C3D0"; bottomColor: "#EBA0B4"; glyphColor: "#B4475F" }
        Divider {}
        AppIcon { glyph: "settings"; topColor: "#DDE2EA"; bottomColor: "#B9C2D0"; glyphColor: "#5A6475" }
    }
}
