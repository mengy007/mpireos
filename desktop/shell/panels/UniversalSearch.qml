import QtQuick
import QtQuick.Layouts
import MpireOS.Style
import "../search.js" as Search

// Universal search (Meta+Space, or the search icon in the top bar): one field
// that finds apps, files and folders, settings, and system actions, does math
// and unit conversions, and searches the web. Results come in sections on the
// left; the selected one is previewed on the right.
// Keys: arrows move, Enter opens, Ctrl+Enter shows a file in its folder,
// Ctrl+C copies an answer or a file's path, Esc closes.
Item {
    id: root
    property var apps: []                     // AppIndex entries (src/apps.h)
    property var files: null                  // FileSearch (src/filesearch.h), or a stand-in
    property alias query: input.text
    readonly property bool searching: query.trim().length > 0
    // FileSearch.revision: search again when the file index is rebuilt.
    readonly property var fileHits: searching && files ? (files.revision, files.search(query, 6)) : []
    readonly property var rows: Search.universal(query, apps, fileHits)
    property int cursor: 0
    readonly property var selected: rows[cursor] && rows[cursor].kind !== "header" ? rows[cursor] : null

    signal openApp(string id)
    signal runCommand(string command)
    signal runAction(string action)
    signal copyText(string text)
    signal openUrl(string url)
    signal reveal(string path)
    signal close()

    function reset() {
        input.text = ""
        cursor = 0
        input.forceActiveFocus()
        if (files) files.refresh()
    }
    function firstPick() {
        for (let i = 0; i < rows.length; i++) if (rows[i].kind !== "header") return i
        return 0
    }
    function activate(item) {
        if (!item) return
        switch (item.kind) {
        case "app": root.openApp(item.id); break
        case "command": root.runCommand(item.command); break
        case "system": root.runAction(item.action); break
        case "calc": root.copyText(item.value); break
        case "web": case "file": root.openUrl(item.url); break
        }
        root.close()
    }
    function move(step) {
        let i = cursor
        for (let n = 0; n < rows.length; n++) {
            i = i + step
            if (i < 0 || i >= rows.length) return
            if (rows[i].kind !== "header") break
        }
        cursor = i
        list.positionViewAtIndex(cursor > 1 ? cursor : 0, ListView.Contain)
    }
    function enter(modifiers) {
        if ((modifiers & Qt.ControlModifier) && selected && selected.kind === "file") {
            root.reveal(selected.path)
            root.close()
        } else {
            activate(selected)
        }
    }
    function copySelected() {
        if (!selected) return
        if (selected.kind === "calc") root.copyText(selected.value)
        else if (selected.kind === "file") root.copyText(selected.path)
        else return
        root.close()
    }

    onRowsChanged: cursor = firstPick()

    width: 760
    implicitHeight: card.height

    Card {
        id: card
        width: parent.width
        height: 64 + (root.searching ? 1 + 400 : 0)
        Behavior on height { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }
        padding: 0
        level: 4
        radius: 24
        clip: true

        // The field
        RowLayout {
            id: field
            x: 0; y: 0
            width: parent.width
            height: 64
            spacing: 14
            Item { Layout.preferredWidth: 8 }
            Icon { name: "search"; size: 24; weight: 1.8; color: Theme.accent }
            TextInput {
                id: input
                Layout.fillWidth: true
                focus: true
                color: Theme.text
                selectionColor: Theme.accentSoft
                selectedTextColor: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 22
                font.letterSpacing: -0.2
                clip: true
                Text {
                    visible: input.text.length === 0
                    text: qsTr("Search apps, files, settings, and more")
                    color: Theme.textTertiary
                    font: input.font
                }
                Keys.onDownPressed: root.move(1)
                Keys.onUpPressed: root.move(-1)
                Keys.onTabPressed: root.move(1)
                Keys.onBacktabPressed: root.move(-1)
                Keys.onReturnPressed: event => root.enter(event.modifiers)
                Keys.onEnterPressed: event => root.enter(event.modifiers)
                Keys.onEscapePressed: root.close()
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_C && (event.modifiers & Qt.ControlModifier) && input.selectedText.length === 0) {
                        root.copySelected()
                        event.accepted = true
                    }
                }
            }
            Rectangle {
                visible: input.text.length > 0
                Layout.preferredWidth: 26; Layout.preferredHeight: 26; radius: 13
                color: clearArea.containsMouse ? Theme.surfaceHover : Theme.surfaceSunken
                Icon { anchors.centerIn: parent; name: "x"; size: 14 }
                MouseArea { id: clearArea; anchors.fill: parent; hoverEnabled: true; onClicked: root.reset() }
            }
            Item { Layout.preferredWidth: 10 }
        }

        Rectangle { y: 64; width: parent.width; height: 1; color: Theme.divider; visible: root.searching }

        // Results, in sections
        ListView {
            id: list
            visible: root.searching
            x: 10; y: 65 + 8
            width: 320
            height: 400 - 16
            clip: true
            model: root.rows
            boundsBehavior: Flickable.StopAtBounds
            delegate: Item {
                id: row
                required property var modelData
                required property int index
                readonly property bool header: modelData.kind === "header"
                readonly property bool current: index === root.cursor
                width: ListView.view.width
                height: header ? (index === 0 ? 24 : 32) : 44

                Overline {
                    visible: row.header
                    x: 12
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 6
                    text: row.modelData.title
                    font.pixelSize: 10
                }
                Rectangle {
                    visible: !row.header
                    anchors.fill: parent
                    radius: 11
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: row.current ? Theme.accent : rowArea.containsMouse ? Theme.surfaceHover : "transparent" }
                        GradientStop { position: 1; color: row.current ? Qt.darker(Theme.accent, 1.12) : rowArea.containsMouse ? Theme.surfaceHover : "transparent" }
                    }
                }
                RowLayout {
                    visible: !row.header
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 12
                    spacing: 11
                    ResultIcon {
                        icon: row.modelData.icon || ""
                        glyph: row.modelData.glyph || "grid"
                        size: 28
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Text {
                            Layout.fillWidth: true
                            text: row.modelData.title || ""
                            elide: Text.ElideRight
                            color: row.current ? "white" : Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: text.length > 0
                            text: row.modelData.subtitle || ""
                            elide: Text.ElideMiddle
                            color: row.current ? "#D9FFFFFF" : Theme.textTertiary
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                        }
                    }
                }
                MouseArea {
                    id: rowArea
                    visible: !row.header
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        if (root.cursor === row.index) root.activate(row.modelData)
                        else root.cursor = row.index
                    }
                    onDoubleClicked: root.activate(row.modelData)
                }
            }
        }

        Rectangle { visible: root.searching; x: 340; y: 65; width: 1; height: 400; color: Theme.divider }

        // Preview of the selected result
        Item {
            id: preview
            visible: root.searching && root.selected !== null
            readonly property var item: root.selected || ({})
            readonly property bool isFile: item.kind === "file"
            x: 341; y: 65
            width: parent.width - x
            height: 400

            Rectangle { anchors.fill: parent; color: Theme.surfaceSunken; opacity: 0.6 }

            ColumnLayout {
                anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 28; rightMargin: 28; topMargin: 30 }
                spacing: 0

                // Picture: an image file itself, or a big icon.
                Item {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: preview.item.image ? 300 : 88
                    Layout.preferredHeight: preview.item.image ? 160 : (preview.item.kind === "calc" ? 0 : 88)
                    visible: preview.item.kind !== "calc"
                    Image {
                        id: picture
                        anchors.fill: parent
                        visible: preview.item.image === true && status === Image.Ready
                        source: preview.item.image ? preview.item.url : ""
                        fillMode: Image.PreserveAspectFit
                        sourceSize: Qt.size(600, 320)
                        asynchronous: true
                    }
                    ResultIcon {
                        anchors.centerIn: parent
                        visible: !picture.visible
                        icon: preview.item.icon || ""
                        glyph: preview.item.glyph || "grid"
                        size: 80
                    }
                }

                // Calculator and conversions: the answer, big.
                Text {
                    visible: preview.item.kind === "calc"
                    Layout.fillWidth: true
                    Layout.topMargin: 64
                    horizontalAlignment: Text.AlignHCenter
                    text: preview.item.subtitle || ""
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: 15
                    elide: Text.ElideMiddle
                }
                Text {
                    Layout.fillWidth: true
                    Layout.topMargin: preview.item.kind === "calc" ? 6 : 18
                    horizontalAlignment: Text.AlignHCenter
                    text: preview.item.title || ""
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    color: preview.item.kind === "calc" ? Theme.accentText : Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: preview.item.kind === "calc" ? 40 : 19
                    font.weight: preview.item.kind === "calc" ? Font.Bold : Font.DemiBold
                    font.letterSpacing: preview.item.kind === "calc" ? -1 : -0.3
                }
                Text {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    horizontalAlignment: Text.AlignHCenter
                    visible: text.length > 0
                    text: {
                        const it = preview.item
                        switch (it.kind) {
                        case "app": return it.subtitle || qsTr("Application")
                        case "file": return it.fileKind || ""
                        case "command": return qsTr("Settings")
                        case "system": return qsTr("System action")
                        case "calc": return it.detail || ""
                        case "web": return qsTr("Opens DuckDuckGo in your browser")
                        }
                        return ""
                    }
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                }

                // A file's details
                GridLayout {
                    visible: preview.isFile
                    Layout.fillWidth: true
                    Layout.topMargin: 18
                    columns: 2
                    columnSpacing: 14
                    rowSpacing: 7
                    Repeater {
                        model: preview.isFile ? [
                            [qsTr("Size"), preview.item.size || "—"],
                            [qsTr("Modified"), preview.item.modified ? Qt.formatDateTime(preview.item.modified, "MMM d, yyyy  h:mm AP") : "—"],
                            [qsTr("Where"), preview.item.subtitle || ""]
                        ].filter(r => !(preview.item.isDir && r[0] === qsTr("Size"))) : []
                        delegate: Repeater {
                            required property var modelData
                            model: 2
                            Text {
                                required property int index
                                Layout.fillWidth: index === 1
                                horizontalAlignment: index === 0 ? Text.AlignRight : Text.AlignLeft
                                Layout.preferredWidth: index === 0 ? 70 : -1
                                text: modelData[index]
                                elide: Text.ElideMiddle
                                color: index === 0 ? Theme.textTertiary : Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                            }
                        }
                    }
                }
            }

            // Actions and key hints, along the bottom.
            Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom; bottomMargin: 52 } height: 1; color: Theme.divider }
            RowLayout {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 20; rightMargin: 16 }
                height: 52
                spacing: 8
                Text {
                    text: preview.isFile ? qsTr("Ctrl+↵ shows it in its folder")
                        : preview.item.kind === "calc" ? qsTr("Ctrl+C copies the answer") : qsTr("↑↓ to move, Esc to close")
                    color: Theme.textTertiary
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                }
                Item { Layout.fillWidth: true }
                PillButton {
                    visible: preview.isFile
                    text: qsTr("Show in Folder")
                    onClicked: { root.reveal(preview.item.path); root.close() }
                }
                PillButton {
                    accent: true
                    text: {
                        switch (preview.item.kind) {
                        case "calc": return qsTr("Copy")
                        case "system": return qsTr("Run")
                        case "web": return qsTr("Search")
                        }
                        return qsTr("Open") + "  ↵"
                    }
                    onClicked: root.activate(preview.item)
                }
            }
        }
    }
}
