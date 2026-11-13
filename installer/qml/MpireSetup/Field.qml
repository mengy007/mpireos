import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import MpireSetup

ColumnLayout {
    id: root
    property alias label: labelText.text
    property alias text: input.text
    property alias placeholder: input.placeholderText
    property alias echoMode: input.echoMode
    property alias input: input
    property string hint
    property bool error: false

    spacing: 8

    Text {
        id: labelText
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: 13
        font.weight: Font.DemiBold
    }
    TextField {
        id: input
        Layout.fillWidth: true
        implicitHeight: 44
        leftPadding: 16
        rightPadding: 16
        color: Theme.text
        placeholderTextColor: Theme.textTertiary
        selectionColor: Theme.accentSoft
        selectedTextColor: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: 15
        background: Rectangle {
            radius: Theme.radiusSmall
            color: input.activeFocus ? Theme.surface : Theme.surfaceSunken
            border.width: input.activeFocus ? 1.5 : 1
            border.color: root.error ? Theme.danger
                        : input.activeFocus ? Theme.accent : Theme.border
            Behavior on border.color { ColorAnimation { duration: Theme.animFast } }
        }
    }
    Text {
        Layout.fillWidth: true
        visible: root.hint.length > 0
        text: root.hint
        color: root.error ? Theme.danger : Theme.textSecondary
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSmall
        wrapMode: Text.WordWrap
    }
}
