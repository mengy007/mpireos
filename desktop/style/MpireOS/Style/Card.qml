import QtQuick
import QtQuick.Effects

// A white rounded card with a soft teal-tinted shadow (elevation 2).
Item {
    id: root
    default property alias content: inner.data
    property int padding: 20
    property int level: 2
    property color color: Theme.surface
    property int radius: Theme.radius
    property bool plain: false      // no surface or shadow: content sits on the desktop

    RectangularShadow {
        visible: !root.plain
        anchors.fill: bg
        radius: bg.radius
        color: Qt.rgba(0.043, 0.227, 0.267, [0, 0.06, 0.08, 0.12, 0.18][root.level])
        blur: [0, 2, 24, 48, 72][root.level]
        offset.y: [0, 1, 8, 18, 28][root.level]
    }
    Rectangle {
        id: bg
        visible: !root.plain
        anchors.fill: parent
        radius: root.radius
        color: root.color
        border.color: Qt.rgba(1, 1, 1, 0.9)
    }
    Item {
        id: inner
        anchors.fill: parent
        anchors.margins: root.padding
    }
}
