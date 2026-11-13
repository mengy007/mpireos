import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import MpireSetup

// A large, clickable option. One card per choice keeps decisions obvious.
AbstractButton {
    id: control
    property string title
    property string description
    property string glyph           // a short glyph shown in the badge
    property bool selected: false
    property bool selectable: true   // false for cards that act immediately
    property color badgeColor: Theme.lavenderTint
    property color glyphColor: Theme.accent

    implicitWidth: 520
    implicitHeight: Math.max(80, row.implicitHeight + 36)
    hoverEnabled: true
    padding: 18

    background: Rectangle {
        radius: Theme.radius
        color: control.selected ? Theme.selection
             : control.hovered ? Theme.surfaceHover : Theme.surface
        border.width: control.selected ? 1.5 : 1
        border.color: control.selected ? Theme.accent : Theme.border
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
        Behavior on border.color { ColorAnimation { duration: Theme.animFast } }
    }

    contentItem: RowLayout {
        id: row
        spacing: 18

        Rectangle {
            Layout.preferredWidth: 44
            Layout.preferredHeight: 44
            Layout.alignment: Qt.AlignVCenter
            radius: 12
            color: control.badgeColor
            Text {
                anchors.centerIn: parent
                text: control.glyph
                color: control.glyphColor
                font.pixelSize: 20
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 4
            Text {
                Layout.fillWidth: true
                text: control.title
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 15
                font.weight: Font.DemiBold
                wrapMode: Text.WordWrap
            }
            Text {
                Layout.fillWidth: true
                visible: text.length > 0
                text: control.description
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: 13
                wrapMode: Text.WordWrap
                textFormat: Text.StyledText
            }
        }
        Rectangle {
            visible: control.selectable
            Layout.preferredWidth: 20
            Layout.preferredHeight: 20
            Layout.alignment: Qt.AlignVCenter
            radius: 10
            color: "transparent"
            border.width: 2
            border.color: control.selected ? Theme.accent : Theme.controlOff
            Rectangle {
                anchors.centerIn: parent
                width: 10; height: 10; radius: 5
                color: Theme.accent
                visible: control.selected
            }
        }
    }
}
