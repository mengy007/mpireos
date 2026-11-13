pragma Singleton
import QtQuick

// MpireOS design tokens (light theme), from docs/design-system.md.
// Shared by Mpire Desktop, its apps, and Mpire Setup.
QtObject {
    // Neutrals
    readonly property color backdrop: "#E4EDEF"
    readonly property color backdropHighlight: "#F4F8F9"
    readonly property color chrome: "#CCF7F9FB"          // 80% frosted
    readonly property color surface: "#FFFFFF"
    readonly property color surfaceSunken: "#F7F9FB"
    readonly property color surfaceHover: "#F1F7F8"
    readonly property color selection: "#EBF6F7"
    readonly property color divider: "#EDF0F3"
    readonly property color border: "#E6EAEF"
    readonly property color text: "#0B1F25"
    readonly property color textSecondary: "#4F5D6B"
    readonly property color textTertiary: "#8B95A3"
    // Older names used by components
    readonly property color textMuted: textSecondary
    readonly property color surfaceSelected: selection

    // Accent
    readonly property color accent: "#269CA1"
    readonly property color accentHover: "#2FAAAF"
    readonly property color accentPressed: "#1A7F86"
    readonly property color accentSoft: "#EBF6F7"
    readonly property color accentText: "#094551"
    readonly property color accentDeep: "#094551"      // end of accent gradients (mpire-tech.com)
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
    readonly property int animSlow: 360
    readonly property int radiusDock: 22
    readonly property color butter: "#F2D58C"
    readonly property color butterTint: "#FCF6E3"
    readonly property color slate: "#AEB7C6"
    readonly property color slateTint: "#EEF0F4"
}
