import QtQuick
import QtQuick.Layouts
import MpireOS.Style

// A one-line text field in the MpireOS style, with a placeholder and an
// optional leading glyph. `secret` hides what's typed (API keys).
Rectangle {
    id: root
    property alias text: input.text
    property string placeholder: ""
    property string glyph: ""
    property bool secret: false
    readonly property bool hasFocus: input.activeFocus
    signal accepted()

    function focusField() { input.forceActiveFocus() }

    implicitHeight: 38
    radius: 11
    color: Theme.surfaceSunken
    border.width: input.activeFocus ? 1.5 : 1
    border.color: input.activeFocus ? Theme.accent : Theme.border
    Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 8
        Icon { visible: root.glyph.length > 0; name: root.glyph; size: 16; color: Theme.textTertiary }
        TextInput {
            id: input
            Layout.fillWidth: true
            clip: true
            echoMode: root.secret ? TextInput.Password : TextInput.Normal
            passwordCharacter: "•"
            color: Theme.text
            selectionColor: Theme.accentSoft
            selectedTextColor: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: 13
            onAccepted: root.accepted()
            Text {
                visible: input.text.length === 0
                text: root.placeholder
                color: Theme.textTertiary
                font: input.font
                elide: Text.ElideRight
                width: parent.width
            }
        }
    }
    MouseArea { anchors.fill: parent; z: -1; cursorShape: Qt.IBeamCursor; onClicked: input.forceActiveFocus() }
}
