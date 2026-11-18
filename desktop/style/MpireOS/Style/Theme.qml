pragma Singleton
import QtQuick

// MpireOS design tokens, from docs/design-system.md. Shared by Mpire Desktop,
// its apps, and Mpire Setup. Light by default; Mpire Desktop's shell turns on
// `dark`: dark frosted glass with thin light borders, like its window frames.
QtObject {
    property bool dark: false

    // Dark glass (panels, popups, menus): see-through fill and a hairline edge.
    readonly property color glass: dark ? "#E00E171B" : surface
    readonly property color glassBorder: dark ? "#29FFFFFF" : "#E6FFFFFF"
    readonly property color glow: "#6600CBD7"           // focus glow, brand cyan
    // Neutrals
    readonly property color backdrop: dark ? "#0B1316" : "#E4EDEF"
    readonly property color backdropHighlight: dark ? "#13232A" : "#F4F8F9"
    readonly property color chrome: dark ? "#B30E171B" : "#CCF7F9FB"          // frosted top bar
    readonly property color surface: dark ? "#E0111B1F" : "#FFFFFF"
    readonly property color surfaceSunken: dark ? "#12FFFFFF" : "#F7F9FB"
    readonly property color surfaceHover: dark ? "#1AFFFFFF" : "#F1F7F8"
    readonly property color selection: dark ? "#2900CBD7" : "#E2F7F9"
    readonly property color divider: dark ? "#14FFFFFF" : "#EDF0F3"
    readonly property color border: dark ? "#26FFFFFF" : "#E6EAEF"
    readonly property color text: dark ? "#E2EAEC" : "#0B1F25"
    readonly property color textSecondary: dark ? "#A3B1B6" : "#4F5D6B"
    readonly property color textTertiary: dark ? "#6E7F86" : "#8B95A3"
    // Older names used by components
    readonly property color textMuted: textSecondary
    readonly property color surfaceSelected: selection

    // Accent
    readonly property color brand: "#00CBD7"           // logo cyan (branding/logo): the mark and "OS"
    readonly property color brandNavy: "#062331"       // logo navy
    readonly property color accent: dark ? "#00BFCB" : "#00B4C1"
    readonly property color accentHover: dark ? "#2AD3DD" : "#10C2CE"
    readonly property color accentPressed: dark ? "#00A3AE" : "#0096A3"
    readonly property color accentSoft: dark ? "#2600CBD7" : "#E2F7F9"
    readonly property color accentText: dark ? "#4DD6DF" : "#006975"
    readonly property color accentDeep: "#054F5C"      // end of accent gradients
    readonly property color controlOff: dark ? "#38FFFFFF" : "#D3DAE1"      // switch track, unselected ring
    readonly property color scrim: dark ? "#99000000" : "#660B1F25"         // behind popups

    // Pastels: fill, tint
    readonly property color lavender: "#A595D4"
    readonly property color lavenderTint: dark ? "#2EA595D4" : "#F0ECFA"
    readonly property color apricot: "#E6B072"
    readonly property color apricotTint: dark ? "#2EE6B072" : "#FBF1E4"
    readonly property color sky: "#83A9D8"
    readonly property color skyTint: dark ? "#2E83A9D8" : "#EAF1FA"
    readonly property color sage: "#8EB49B"
    readonly property color sageTint: dark ? "#2E8EB49B" : "#EBF3EE"
    readonly property color rose: "#EEAEBF"
    readonly property color roseTint: dark ? "#2EEEAEBF" : "#FCEEF2"

    // Status
    readonly property color success: dark ? "#78C8A0" : "#5FAF8A"
    readonly property color danger: dark ? "#F0808E" : "#E06A7A"
    readonly property color shadow: dark ? "#000000" : "#0B3A44"

    // Shape
    readonly property int radiusWindow: 16
    readonly property int radius: 14          // cards
    readonly property int radiusPanel: 18     // glass panels
    readonly property int radiusSmall: 10     // controls
    readonly property int spacing: 16

    // Type
    readonly property string fontFamily: "Inter"
    readonly property string fontMono: "JetBrains Mono"   // window titles, tabs, labels, clock
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
    readonly property int topBarHeight: 30      // Mpire Desktop's top bar
    readonly property color butter: "#F2D58C"
    readonly property color butterTint: dark ? "#2EF2D58C" : "#FCF6E3"
    readonly property color slate: "#AEB7C6"
    readonly property color slateTint: dark ? "#2EAEB7C6" : "#EEF0F4"
}
