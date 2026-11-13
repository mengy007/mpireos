import QtQuick
import QtQuick.Effects
import MpireSetup

// Large, soft, teal-tinted shadow (design-system.md, Elevation).
// Place it before the item it shadows and set `target`.
RectangularShadow {
    property Item target
    property int level: 3

    x: target ? target.x : 0
    y: target ? target.y : 0
    width: target ? target.width : 0
    height: target ? target.height : 0
    radius: Theme.radiusWindow
    color: Qt.rgba(0.043, 0.227, 0.267, [0, 0.06, 0.08, 0.12, 0.18][level])
    blur: [0, 2, 24, 48, 72][level]
    offset.y: [0, 1, 8, 18, 28][level]
    spread: 0
}
