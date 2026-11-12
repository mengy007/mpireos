import QtQuick

// Text in the MpireOS type scale: role is "display", "greeting", "title",
// "heading", "body", "small".
Text {
    property string role: "body"
    property bool secondary: false
    color: secondary ? Theme.textSecondary : Theme.text
    font.family: Theme.fontFamily
    font.pixelSize: ({ display: 56, greeting: 26, title: 22, heading: 15, body: 14, small: 12 })[role]
    font.weight: ({ display: Font.Light, greeting: Font.Normal, title: Font.DemiBold,
                    heading: Font.DemiBold, body: Font.Normal, small: Font.Normal })[role]
    font.letterSpacing: ({ display: -1.6, greeting: -0.3, title: -0.2, heading: 0, body: 0, small: 0 })[role]
    font.features: { "tnum": 1 }
}
