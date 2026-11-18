import QtQuick

Text {
    color: Theme.textTertiary
    font.family: Theme.dark ? Theme.fontMono : Theme.fontFamily
    font.pixelSize: Theme.fontOverline
    font.weight: Font.DemiBold
    font.capitalization: Font.AllUppercase
    font.letterSpacing: Theme.dark ? 1.0 : 1.4
}
