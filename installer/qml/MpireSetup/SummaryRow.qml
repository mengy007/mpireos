import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import MpireSetup

RowLayout {
    id: root
    property string label
    property string value
    property bool warning: false
    property bool editable: false
    signal editRequested()

    spacing: 16
    Text {
        Layout.preferredWidth: 150
        text: root.label
        color: Theme.textSecondary
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontBody
    }
    Text {
        Layout.fillWidth: true
        text: root.value
        color: root.warning ? Theme.danger : Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontBody
        font.weight: Font.Medium
        wrapMode: Text.WordWrap
    }
    Text {
        visible: root.editable
        text: qsTr("Edit")
        color: editArea.containsMouse ? Theme.accent : Theme.accentText
        font.family: Theme.fontFamily
        font.pixelSize: 13
        font.weight: Font.Medium
        MouseArea {
            id: editArea
            anchors.fill: parent
            anchors.margins: -6
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.editRequested()
        }
    }
}
