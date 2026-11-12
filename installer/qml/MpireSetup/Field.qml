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
        font.pixelSize: Theme.fontBody
        font.weight: Font.Medium
    }
    TextField {
        id: input
        Layout.fillWidth: true
        implicitHeight: 48
        leftPadding: 16
        rightPadding: 16
        color: Theme.text
        placeholderTextColor: Theme.textMuted
        selectionColor: Theme.accent
        font.pixelSize: Theme.fontSubtitle
        background: Rectangle {
            radius: Theme.radiusSmall
            color: Theme.surface
            border.width: input.activeFocus ? 2 : 1
            border.color: root.error ? Theme.danger
                        : input.activeFocus ? Theme.accent : Theme.border
            Behavior on border.color { ColorAnimation { duration: Theme.animFast } }
        }
    }
    Text {
        Layout.fillWidth: true
        visible: root.hint.length > 0
        text: root.hint
        color: root.error ? Theme.danger : Theme.textMuted
        font.pixelSize: Theme.fontSmall
        wrapMode: Text.WordWrap
    }
}
