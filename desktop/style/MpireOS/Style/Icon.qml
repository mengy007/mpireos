import QtQuick
import "Icons.js" as Icons

// An MpireOS outline icon, tinted to any color.
Image {
    property string name
    property color color: Theme.textSecondary
    property real size: 20
    property real weight: 1.6
    width: size
    height: size
    sourceSize: Qt.size(size * 2, size * 2)
    source: Icons.url(name, color, weight)
    smooth: true
}
