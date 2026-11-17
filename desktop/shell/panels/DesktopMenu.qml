import QtQuick
import QtQuick.Layouts
import MpireOS.Style

// The desktop's right-click menu: wallpaper, display, the dock, and shortcuts
// to Files, Terminal, and Settings. Keys: arrows move, Enter picks, Esc closes.
Card {
    id: root
    property bool dockAutoHide: true
    property int cursor: -1
    signal changeWallpaper()
    signal run(string command)
    signal setDockAutoHide(bool on)

    // kind: "item" | "toggle" | "divider"
    readonly property var entries: [
        { kind: "item", glyph: "image", text: qsTr("Change wallpaper…"), action: "wallpaper" },
        { kind: "item", glyph: "monitor", text: qsTr("Display settings"), command: "kcmshell6 kcm_kscreen" },
        { kind: "toggle", glyph: "dock", text: qsTr("Auto-hide the dock") },
        { kind: "divider" },
        { kind: "item", glyph: "folder", text: qsTr("Open Files"), command: "dolphin" },
        { kind: "item", glyph: "terminal", text: qsTr("Open Terminal"), command: "konsole" },
        { kind: "divider" },
        { kind: "item", glyph: "settings", text: qsTr("All settings"), command: "systemsettings" }
    ]

    function reset() { cursor = -1 }
    function pick(i) {
        const e = entries[i]
        if (!e || e.kind === "divider") return
        if (e.kind === "toggle") root.setDockAutoHide(!root.dockAutoHide)
        else if (e.action === "wallpaper") root.changeWallpaper()
        else root.run(e.command)
    }
    function move(step) {
        let i = cursor
        for (let n = 0; n < entries.length; n++) {
            i = (i + step + entries.length) % entries.length
            if (entries[i].kind !== "divider") { cursor = i; return }
        }
    }
    Keys.onUpPressed: move(-1)
    Keys.onDownPressed: move(1)
    Keys.onReturnPressed: pick(cursor)
    Keys.onEnterPressed: pick(cursor)
    Keys.onSpacePressed: pick(cursor)

    width: 264
    implicitHeight: column.implicitHeight + 2 * padding
    padding: 6
    level: 3
    radius: 16

    ColumnLayout {
        id: column
        width: parent.width
        spacing: 0
        Repeater {
            model: root.entries
            delegate: Item {
                id: row
                required property var modelData
                required property int index
                readonly property bool divider: modelData.kind === "divider"
                readonly property bool hot: root.cursor === index
                Layout.fillWidth: true
                Layout.preferredHeight: divider ? 11 : 36

                Rectangle {
                    visible: row.divider
                    anchors.verticalCenter: parent.verticalCenter
                    x: 10; width: parent.width - 20; height: 1
                    color: Theme.divider
                }
                Rectangle {
                    visible: !row.divider
                    anchors.fill: parent
                    radius: 10
                    color: row.hot ? Theme.selection : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                }
                RowLayout {
                    visible: !row.divider
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 11
                    Icon {
                        name: row.modelData.glyph || "grid"
                        size: 18
                        color: row.hot ? Theme.accentText : Theme.textSecondary
                    }
                    Text {
                        Layout.fillWidth: true
                        text: row.modelData.text || ""
                        elide: Text.ElideRight
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                        font.weight: row.index === 0 ? Font.DemiBold : Font.Normal
                    }
                    Toggle {
                        visible: row.modelData.kind === "toggle"
                        checked: root.dockAutoHide
                        scale: 0.86
                        onToggled: on => root.setDockAutoHide(on)
                    }
                }
                MouseArea {
                    visible: !row.divider
                    anchors.fill: parent
                    z: -1
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.cursor = row.index
                    onExited: if (root.cursor === row.index) root.cursor = -1
                    onClicked: root.pick(row.index)
                }
            }
        }
    }
}
