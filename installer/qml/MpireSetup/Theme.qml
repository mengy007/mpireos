pragma Singleton
import QtQuick

// MpireOS design tokens (light theme), from docs/design-system.md.
// Moves to the shared MpireOS.Style module once it exists.
QtObject {
    // Neutrals
    readonly property color backdrop: "#E4EDEF"
    readonly property color backdropHighlight: "#F4F8F9"
    readonly property color chrome: "#CCF7F9FB"          // 80% frosted
    readonly property color surface: "#FFFFFF"
    readonly property color surfaceSunken: "#F7F9FB"
    readonly property color surfaceHover: "#F1F7F8"
    readonly property color selection: "#E2F7F9"
    readonly property color divider: "#EDF0F3"
    readonly property color border: "#E6EAEF"
    readonly property color text: "#0B1F25"
    readonly property color textSecondary: "#4F5D6B"
    readonly property color textTertiary: "#8B95A3"
    // Older names used by components
    readonly property color textMuted: textSecondary
    readonly property color surfaceSelected: selection

    // Accent
    readonly property color brand: "#00CBD7"           // logo cyan (branding/logo): the mark and "OS"
    readonly property color brandNavy: "#062331"       // logo navy
    readonly property color accent: "#00B4C1"
    readonly property color accentHover: "#10C2CE"
    readonly property color accentPressed: "#0096A3"
    readonly property color accentSoft: "#E2F7F9"
    readonly property color accentText: "#006975"
    readonly property color accentDeep: "#054F5C"      // end of accent gradients
    readonly property color controlOff: "#D3DAE1"      // switch track, unselected ring
    readonly property color scrim: "#660B1F25"         // behind popups

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
    readonly property color shadow: "#0B3A44"

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
