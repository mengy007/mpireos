import QtQuick
import MpireOS.Style

// An on/off switch in the MpireOS style.
Rectangle {
    id: root
    property bool checked: false
    signal toggled(bool on)
    implicitWidth: 38
    implicitHeight: 22
    radius: height / 2
    color: checked ? Theme.accent : Theme.controlOff
    Behavior on color { ColorAnimation { duration: Theme.animFast } }
    Rectangle {
        width: 18; height: 18; radius: 9
        y: 2
        x: root.checked ? root.width - width - 2 : 2
        color: "white"
        Behavior on x { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
    }
    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.toggled(!root.checked) }
}
