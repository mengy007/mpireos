pragma Singleton
import QtQuick

// MpireOS design tokens used by Mpire Setup. These will move to a shared
// design-system module once the desktop components exist.
QtObject {
    readonly property color background: "#0A0F1C"
    readonly property color backgroundGlow: "#16224A"
    readonly property color surface: "#121A2C"
    readonly property color surfaceHover: "#18233A"
    readonly property color surfaceSelected: "#1A2B55"
    readonly property color border: "#24304A"
    readonly property color accent: "#3D7BFF"
    readonly property color accentHover: "#5A90FF"
    readonly property color accentSoft: "#2A3F7A"
    readonly property color text: "#F3F6FC"
    readonly property color textMuted: "#98A3BA"
    readonly property color danger: "#FF6B6B"
    readonly property color success: "#3DDC97"

    readonly property int radius: 16
    readonly property int radiusSmall: 10
    readonly property int spacing: 16

    readonly property int fontTitle: 34
    readonly property int fontSubtitle: 17
    readonly property int fontBody: 15
    readonly property int fontSmall: 13

    readonly property int animFast: 140
    readonly property int animNormal: 260
}
