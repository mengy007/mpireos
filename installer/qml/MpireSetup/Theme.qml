pragma Singleton
import QtQuick

// MpireOS design tokens (light theme), from docs/design-system.md.
// Moves to the shared MpireOS.Style module once it exists.
QtObject {
    // Neutrals
    readonly property color backdrop: "#E6E3EC"
    readonly property color backdropHighlight: "#F3F1F7"
    readonly property color chrome: "#CCF6F5FA"          // 80% frosted
    readonly property color surface: "#FDFDFF"
    readonly property color surfaceSunken: "#F4F4F7"
    readonly property color surfaceHover: "#F6F4FB"
    readonly property color selection: "#EFEBFC"
    readonly property color divider: "#ECEBF0"
    readonly property color border: "#E6E5EB"
    readonly property color text: "#24222E"
    readonly property color textSecondary: "#6B6878"
    readonly property color textTertiary: "#A19EAE"
    // Older names used by components
    readonly property color textMuted: textSecondary
    readonly property color surfaceSelected: selection

    // Accent
    readonly property color accent: "#7C66D6"
    readonly property color accentHover: "#8C78DE"
    readonly property color accentPressed: "#6A55C4"
    readonly property color accentSoft: "#EFEBFC"
    readonly property color accentText: "#5E4BB8"

    // Pastels: fill, tint
    readonly property color lavender: "#A595D4"
    readonly property color lavenderTint: "#F0ECFA"
    readonly property color apricot: "#E6B072"
    readonly property color apricotTint: "#FBF1E4"
    readonly property color sky: "#83A9D8"
    readonly property color skyTint: "#EAF1FA"
    readonly property color sage: "#8EB49B"
    readonly property color sageTint: "#EBF3EE"
    readonly property color rose: "#EEAEBF"
    readonly property color roseTint: "#FCEEF2"

    // Status
    readonly property color success: "#5FAF8A"
    readonly property color danger: "#E06A7A"
    readonly property color shadow: "#3C306E"

    // Shape
    readonly property int radiusWindow: 16
    readonly property int radius: 14          // cards
    readonly property int radiusSmall: 10     // controls
    readonly property int spacing: 16

    // Type
    readonly property string fontFamily: "Inter"
    readonly property int fontDisplay: 56
    readonly property int fontTitle: 28
    readonly property int fontSubtitle: 16
    readonly property int fontBody: 14
    readonly property int fontSmall: 12
    readonly property int fontOverline: 11

    // Motion
    readonly property int animFast: 120
    readonly property int animNormal: 220
}
