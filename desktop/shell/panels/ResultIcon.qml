import QtQuick
import MpireOS.Style

// An app's own icon (from the icon theme), or an MpireOS glyph on a soft tile.
Item {
    id: root
    property string icon: ""        // theme icon name or absolute path
    property string glyph: "grid"
    property real size: 32
    implicitWidth: size
    implicitHeight: size

    Image {
        id: themed
        anchors.fill: parent
        visible: root.icon.length > 0 && status === Image.Ready
        source: root.icon.length > 0 ? "image://icon/" + encodeURIComponent(root.icon) : ""
        sourceSize: Qt.size(root.size * 2, root.size * 2)
        smooth: true
    }
    Rectangle {
        anchors.fill: parent
        visible: !themed.visible
        radius: root.size * 0.28
        color: Theme.accentSoft
        Icon { anchors.centerIn: parent; name: root.glyph; size: root.size * 0.56; color: Theme.accentText }
    }
}
