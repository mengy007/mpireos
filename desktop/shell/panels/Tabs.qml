import QtQuick
import QtQuick.Layouts
import MpireOS.Style

// Underline tabs, as in Mpire window frames' apps: monospace labels on a
// hairline, the current one bright with a cyan underline.
// model: [{ id, label, glyph (optional) }]
Item {
    id: root
    property var model: []
    property string current: ""
    signal picked(string id)

    implicitHeight: 38

    Rectangle {          // the hairline the tabs sit on
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 1
        color: Theme.divider
    }
    Row {
        id: row
        height: parent.height
        spacing: 4
        Repeater {
            model: root.model
            Item {
                id: tab
                required property var modelData
                readonly property bool on: root.current === modelData.id
                objectName: "tab:" + modelData.id
                width: content.implicitWidth + 28
                height: row.height
                Row {
                    id: content
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -1
                    spacing: 7
                    Icon {
                        visible: !!tab.modelData.glyph
                        name: tab.modelData.glyph || ""
                        size: 14
                        weight: 1.5
                        color: tab.on ? Theme.accentText : Theme.textTertiary
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: tab.modelData.label
                        color: tab.on ? Theme.text : area.containsMouse ? Theme.textSecondary : Theme.textTertiary
                        font.family: Theme.fontMono
                        font.pixelSize: 12
                        anchors.verticalCenter: parent.verticalCenter
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    }
                }
                Rectangle {
                    anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
                    width: tab.on ? parent.width : 0
                    height: 2
                    radius: 1
                    color: Theme.brand
                    Behavior on width { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }
                }
                MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.picked(tab.modelData.id) }
            }
        }
    }
}
