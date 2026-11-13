import QtQuick
import MpireOS.Style

// The calendar app icon's live date.
Column {
    property date now: new Date()
    spacing: -4
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: Qt.formatDate(now, "MMM").toUpperCase()
        color: "#E06A7A"
        font.family: Theme.fontFamily
        font.pixelSize: 9
        font.weight: Font.Bold
        font.letterSpacing: 0.8
    }
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: Qt.formatDate(now, "d")
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: 24
        font.weight: Font.Medium
    }
}
