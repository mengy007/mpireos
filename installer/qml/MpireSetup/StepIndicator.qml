import QtQuick
import QtQuick.Layouts
import MpireSetup

RowLayout {
    id: root
    property var steps: []
    property int current: 0
    spacing: 10

    Repeater {
        model: root.steps
        delegate: RowLayout {
            required property int index
            required property string modelData
            spacing: 8
            Rectangle {
                Layout.preferredWidth: index === root.current ? 28 : 8
                Layout.preferredHeight: 8
                radius: 4
                color: index <= root.current ? Theme.accent : Theme.border
                Behavior on Layout.preferredWidth { NumberAnimation { duration: Theme.animNormal; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: Theme.animNormal } }
            }
            Text {
                visible: index === root.current
                text: modelData
                color: Theme.textMuted
                font.pixelSize: Theme.fontSmall
            }
        }
    }
}
