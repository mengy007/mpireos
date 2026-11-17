import QtQuick
import QtQuick.Layouts
import MpireOS.Style

// A tray icon's menu, drawn by the shell from the app's own entries
// (systemTray.menu, src/tray.h), so every app's menu looks like Mpire Desktop.
// Submenus open in place, with a back row. Keys: arrows move, Enter or Right
// opens, Left goes back, Esc closes.
Card {
    id: root
    property var entries: []            // {id, label, enabled, separator, checkable, checked, radio, icon, submenu}
    property string title: ""
    property string icon: ""            // the app's tray icon (image URL)
    property var stack: []              // open submenus: [{title, entries}]
    property int cursor: -1
    readonly property var current: stack.length > 0 ? stack[stack.length - 1].entries : entries
    readonly property string currentTitle: stack.length > 0 ? stack[stack.length - 1].title : title

    signal picked(int id)

    function reset() { stack = []; cursor = -1 }
    function usable(e) { return e && !e.separator && e.enabled }
    function open(e) {
        if (!usable(e)) return
        if (e.submenu && e.submenu.length > 0) {
            stack = stack.concat([{ title: e.label, entries: e.submenu }])
            cursor = -1
        } else {
            root.picked(e.id)
        }
    }
    function back() {
        if (stack.length === 0) return
        stack = stack.slice(0, stack.length - 1)
        cursor = -1
    }
    function move(step) {
        const n = current.length
        let i = cursor
        for (let k = 0; k < n; k++) {
            i = (i + step + n) % n
            if (usable(current[i])) { cursor = i; return }
        }
    }
    Keys.onUpPressed: move(-1)
    Keys.onDownPressed: move(1)
    Keys.onReturnPressed: open(current[cursor])
    Keys.onEnterPressed: open(current[cursor])
    Keys.onRightPressed: if (current[cursor] && current[cursor].submenu.length > 0) open(current[cursor])
    Keys.onLeftPressed: back()
    Keys.onBackPressed: back()

    // As wide as the longest entry needs, within limits.
    width: Math.max(220, Math.min(340, measure.widest + 96))
    implicitHeight: column.implicitHeight + 2 * padding
    padding: 6
    level: 3
    radius: 14

    TextMetrics { id: tm; font.family: Theme.fontFamily; font.pixelSize: 13 }
    QtObject {
        id: measure
        readonly property real widest: {
            let w = 0
            const all = root.current
            for (let i = 0; i < all.length; i++) {
                tm.text = all[i].label || ""
                w = Math.max(w, tm.advanceWidth)
            }
            tm.text = root.currentTitle
            return Math.max(w, tm.advanceWidth)
        }
    }

    ColumnLayout {
        id: column
        width: parent.width
        spacing: 0

        // Which app this is (or, in a submenu, the way back).
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 30
            Rectangle {
                anchors.fill: parent
                radius: 9
                visible: root.stack.length > 0
                color: backArea.containsMouse ? Theme.surfaceHover : "transparent"
            }
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                spacing: 8
                Icon {
                    visible: root.stack.length > 0
                    name: "chevronRight"
                    rotation: 180
                    size: 14
                    color: Theme.textSecondary
                }
                Image {
                    visible: root.stack.length === 0 && root.icon.length > 0
                    Layout.preferredWidth: 16
                    Layout.preferredHeight: 16
                    sourceSize: Qt.size(32, 32)
                    source: root.icon
                }
                Text {
                    Layout.fillWidth: true
                    text: root.currentTitle
                    elide: Text.ElideRight
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }
            }
            MouseArea {
                id: backArea
                anchors.fill: parent
                enabled: root.stack.length > 0
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.back()
            }
        }
        Rectangle { Layout.fillWidth: true; Layout.leftMargin: 8; Layout.rightMargin: 8; Layout.topMargin: 2; Layout.bottomMargin: 4; Layout.preferredHeight: 1; color: Theme.divider }

        Repeater {
            model: root.current
            delegate: Item {
                id: row
                required property var modelData
                required property int index
                readonly property bool hot: root.cursor === index && root.usable(modelData)
                readonly property bool hasSubmenu: (modelData.submenu || []).length > 0
                Layout.fillWidth: true
                Layout.preferredHeight: modelData.separator ? 9 : 32

                Rectangle {
                    visible: row.modelData.separator
                    anchors.verticalCenter: parent.verticalCenter
                    x: 10; width: parent.width - 20; height: 1
                    color: Theme.divider
                }
                Rectangle {
                    visible: !row.modelData.separator
                    anchors.fill: parent
                    radius: 9
                    color: row.hot ? Theme.selection : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                }
                RowLayout {
                    visible: !row.modelData.separator
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 10
                    spacing: 8
                    opacity: row.modelData.enabled ? 1 : 0.45
                    // Check mark or radio dot (a column only menus with toggles use).
                    Item {
                        Layout.preferredWidth: 16
                        Layout.preferredHeight: 16
                        Icon {
                            anchors.centerIn: parent
                            visible: row.modelData.checkable && !row.modelData.radio && row.modelData.checked
                            name: "check"
                            size: 15
                            weight: 2
                            color: Theme.accent
                        }
                        Rectangle {
                            anchors.centerIn: parent
                            visible: row.modelData.radio
                            width: 12; height: 12; radius: 6
                            color: "transparent"
                            border.width: 1.5
                            border.color: row.modelData.checked ? Theme.accent : Theme.controlOff
                            Rectangle {
                                anchors.centerIn: parent
                                visible: row.modelData.checked
                                width: 6; height: 6; radius: 3
                                color: Theme.accent
                            }
                        }
                        Image {
                            anchors.fill: parent
                            visible: !row.modelData.checkable && (row.modelData.icon || "").length > 0
                            sourceSize: Qt.size(32, 32)
                            source: row.modelData.icon || ""
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: row.modelData.label || ""
                        elide: Text.ElideRight
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 13
                    }
                    Icon {
                        visible: row.hasSubmenu
                        name: "chevronRight"
                        size: 14
                        color: Theme.textTertiary
                    }
                }
                MouseArea {
                    visible: !row.modelData.separator
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: row.modelData.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onEntered: root.cursor = row.index
                    onExited: if (root.cursor === row.index) root.cursor = -1
                    onClicked: root.open(row.modelData)
                }
            }
        }
    }
}
