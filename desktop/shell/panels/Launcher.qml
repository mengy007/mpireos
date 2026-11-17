import QtQuick
import QtQuick.Layouts
import MpireOS.Style
import "../search.js" as Search

// The launcher: type to find apps, settings, and actions, do quick math, or
// search the web; with nothing typed, all apps in a grid.
// Keys: arrows move, Enter opens, Esc closes.
Card {
    id: root
    property var apps: []                // AppIndex entries (src/apps.h)
    property alias query: input.text
    readonly property var results: Search.search(query, apps, 7)
    readonly property bool searching: query.trim().length > 0
    property int cursor: 0
    readonly property int columns: 6

    signal openApp(string id)
    signal runCommand(string command)
    signal runAction(string action)
    signal copyText(string text)
    signal openUrl(string url)
    signal close()

    function reset() {
        input.text = ""
        cursor = 0
        input.forceActiveFocus()
    }
    function activate(item) {
        if (!item) return
        switch (item.kind) {
        case "app": root.openApp(item.id); break
        case "command": root.runCommand(item.command); break
        case "system": root.runAction(item.action); break
        case "calc": root.copyText(item.value); break
        case "web": root.openUrl(item.url); break
        }
        root.close()
    }
    function enter() {
        if (searching) activate(results[cursor])
        else if (apps.length > 0) activate({ kind: "app", id: apps[cursor].id })
    }
    function move(step) {
        const count = searching ? results.length : apps.length
        if (count === 0) return
        cursor = Math.max(0, Math.min(count - 1, cursor + step))
        if (searching) list.positionViewAtIndex(cursor, ListView.Contain)
        else grid.positionViewAtIndex(cursor, GridView.Contain)
    }

    width: 680
    // All apps get a fixed area; search results only as much as they need.
    implicitHeight: 64 + 1 + (searching ? Math.min(440, results.length * 56 + 16) : 440) + 40
    padding: 0
    level: 4
    radius: 22
    onQueryChanged: cursor = 0

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Search field
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 64
            Layout.leftMargin: 24
            Layout.rightMargin: 20
            spacing: 14
            Icon { name: "search"; size: 22; color: Theme.textSecondary }
            TextInput {
                id: input
                Layout.fillWidth: true
                focus: true
                color: Theme.text
                selectionColor: Theme.accentSoft
                selectedTextColor: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 20
                clip: true
                Text {
                    visible: input.text.length === 0
                    text: qsTr("Search apps, settings, and more")
                    color: Theme.textTertiary
                    font: input.font
                }
                Keys.onDownPressed: root.move(root.searching ? 1 : root.columns)
                Keys.onUpPressed: root.move(root.searching ? -1 : -root.columns)
                Keys.onRightPressed: event => {
                    if (!root.searching && input.text.length === 0) root.move(1)
                    else event.accepted = false
                }
                Keys.onLeftPressed: event => {
                    if (!root.searching && input.text.length === 0) root.move(-1)
                    else event.accepted = false
                }
                Keys.onReturnPressed: root.enter()
                Keys.onEnterPressed: root.enter()
                Keys.onEscapePressed: root.close()
            }
            Rectangle {
                visible: input.text.length > 0
                Layout.preferredWidth: 28; Layout.preferredHeight: 28; radius: 14
                color: clearArea.containsMouse ? Theme.surfaceHover : "transparent"
                Icon { anchors.centerIn: parent; name: "x"; size: 16 }
                MouseArea { id: clearArea; anchors.fill: parent; hoverEnabled: true; onClicked: root.reset() }
            }
        }
        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.divider }

        // All apps
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !root.searching
            Overline { x: 24; y: 18; text: qsTr("All apps") }
            GridView {
                id: grid
                anchors { fill: parent; topMargin: 44; leftMargin: 16; rightMargin: 16; bottomMargin: 8 }
                clip: true
                cellWidth: width / root.columns
                cellHeight: 100
                model: root.apps
                currentIndex: root.searching ? -1 : root.cursor
                boundsBehavior: Flickable.StopAtBounds
                delegate: Item {
                    required property var modelData
                    required property int index
                    width: grid.cellWidth
                    height: grid.cellHeight
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 4
                        radius: 14
                        color: index === root.cursor ? Theme.selection : cellArea.containsMouse ? Theme.surfaceHover : "transparent"
                    }
                    ColumnLayout {
                        anchors.centerIn: parent
                        width: parent.width - 16
                        spacing: 8
                        ResultIcon { Layout.alignment: Qt.AlignHCenter; icon: modelData.icon; size: 44 }
                        Text {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData.name
                            elide: Text.ElideRight
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                        }
                    }
                    MouseArea {
                        id: cellArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.activate({ kind: "app", id: modelData.id })
                    }
                }
            }
        }

        // Search results
        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: 8
            Layout.leftMargin: 12
            Layout.rightMargin: 12
            visible: root.searching
            clip: true
            spacing: 2
            model: root.results
            boundsBehavior: Flickable.StopAtBounds
            delegate: Rectangle {
                id: row
                required property var modelData
                required property int index
                readonly property bool current: index === root.cursor
                width: ListView.view.width
                height: 54
                radius: 12
                color: current ? Theme.selection : rowArea.containsMouse ? Theme.surfaceHover : "transparent"
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 14
                    spacing: 14
                    ResultIcon { icon: row.modelData.icon; glyph: row.modelData.glyph; size: 34 }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Text {
                            Layout.fillWidth: true
                            text: row.modelData.title
                            elide: Text.ElideRight
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: row.modelData.kind === "calc" ? 18 : 14
                            font.weight: Font.DemiBold
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: text.length > 0
                            text: row.modelData.subtitle
                            elide: Text.ElideRight
                            color: Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                        }
                    }
                    Text {
                        visible: row.current
                        text: row.modelData.hint + "  ↵"
                        color: Theme.accentText
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                    }
                }
                MouseArea {
                    id: rowArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: root.cursor = row.index
                    onClicked: root.activate(row.modelData)
                }
            }
        }

        // Key hints
        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.divider }
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 39
            Layout.leftMargin: 24
            Layout.rightMargin: 24
            spacing: 18
            Repeater {
                model: [["↑↓", qsTr("Move")], ["↵", qsTr("Open")], ["Esc", qsTr("Close")]]
                RowLayout {
                    required property var modelData
                    spacing: 6
                    Rectangle {
                        implicitWidth: keyText.implicitWidth + 10; implicitHeight: 18; radius: 5
                        color: "transparent"; border.color: Theme.border
                        Text { id: keyText; anchors.centerIn: parent; text: modelData[0]; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: 10 }
                    }
                    Text { text: modelData[1]; color: Theme.textTertiary; font.family: Theme.fontFamily; font.pixelSize: 11 }
                }
            }
            Item { Layout.fillWidth: true }
            Text {
                text: root.searching ? "" : qsTr("%n apps", "", root.apps.length)
                color: Theme.textTertiary
                font.family: Theme.fontFamily
                font.pixelSize: 11
            }
        }
    }
}
