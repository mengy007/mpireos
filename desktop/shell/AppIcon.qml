import QtQuick
import QtQuick.Effects
import MpireOS.Style

// A soft pastel squircle app icon with a glyph (design-system.md, Iconography).
Item {
    id: root
    property string glyph: "grid"
    property color topColor: "#FFFFFF"
    property color bottomColor: "#F1EFF6"
    property color glyphColor: Theme.textSecondary
    property real size: 52
    property bool running: false
    property bool hovered: area.containsMouse
    default property alias overlay: face.data

    implicitWidth: size
    implicitHeight: size

    RectangularShadow {
        anchors.fill: face
        radius: face.radius
        color: Qt.rgba(0.235, 0.188, 0.431, 0.10)
        blur: 12
        offset.y: 4
    }
    Rectangle {
        id: face
        anchors.fill: parent
        radius: root.size * 0.28
        border.color: Qt.rgba(1, 1, 1, 0.7)
        gradient: Gradient {
            GradientStop { position: 0; color: root.topColor }
            GradientStop { position: 1; color: root.bottomColor }
        }
        scale: root.hovered ? 1.06 : 1
        Behavior on scale { NumberAnimation { duration: Theme.animFast } }
        Icon {
            anchors.centerIn: parent
            visible: root.glyph.length > 0
            name: root.glyph
            size: root.size * 0.52
            color: root.glyphColor
            weight: 1.7
        }
    }
    Rectangle {
        visible: root.running
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.bottom
        anchors.topMargin: 5
        width: 4; height: 4; radius: 2
        color: Theme.accent
    }
    MouseArea { id: area; anchors.fill: parent; hoverEnabled: true }
}
