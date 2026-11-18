import QtQuick
import QtQuick.Effects

// A rounded card: white with a soft teal-tinted shadow (elevation 2), or, in
// the dark theme, dark frosted glass with a hairline light edge.
Item {
    id: root
    default property alias content: inner.data
    property int padding: 20
    property int level: 2
    property color color: Theme.glass
    property int radius: Theme.radius
    property bool plain: false      // no surface or shadow: content sits on the desktop
    // Dark glass: Mpire Desktop blurs what's behind it (mpire-shell's src/glass.h).
    readonly property bool glass: Theme.dark && !plain && color.a < 0.99
    Component.onCompleted: if (typeof shellGlass !== "undefined" && shellGlass) shellGlass.add(root)

    RectangularShadow {
        visible: !root.plain
        anchors.fill: bg
        radius: bg.radius
        color: Theme.dark ? Qt.rgba(0, 0, 0, [0, 0.18, 0.28, 0.36, 0.45][root.level])
                          : Qt.rgba(0.043, 0.227, 0.267, [0, 0.06, 0.08, 0.12, 0.18][root.level])
        blur: [0, 2, 24, 48, 72][root.level]
        offset.y: [0, 1, 8, 18, 28][root.level]
    }
    Rectangle {
        id: bg
        visible: !root.plain
        anchors.fill: parent
        radius: root.radius
        color: root.color
        border.color: Theme.glassBorder
        // Dark glass catches a little light along its top edge.
        Rectangle {
            visible: Theme.dark
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            gradient: Gradient {
                GradientStop { position: 0; color: "#0CFFFFFF" }
                GradientStop { position: 0.35; color: "#00FFFFFF" }
            }
        }
    }
    Item {
        id: inner
        anchors.fill: parent
        anchors.margins: root.padding
    }
}
