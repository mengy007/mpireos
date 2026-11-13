import QtQuick
import MpireOS.Style

// A small text button: "accent" for the main action, otherwise quiet.
Rectangle {
    id: root
    property alias text: label.text
    property bool accent: false
    property bool danger: false
    signal clicked()
    implicitWidth: label.implicitWidth + 24
    implicitHeight: 30
    radius: 15
    color: accent ? (area.pressed ? Theme.accentPressed : area.containsMouse ? Theme.accentHover : Theme.accent)
         : danger ? (area.containsMouse ? Qt.darker(Theme.danger, 1.08) : Theme.danger)
         : (area.containsMouse ? Theme.surfaceHover : Theme.surfaceSunken)
    Text {
        id: label
        anchors.centerIn: parent
        color: root.accent || root.danger ? "white" : Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: 12
        font.weight: Font.DemiBold
    }
    MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.clicked() }
}
