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
    property color badgeColor: Theme.accentSoft

    implicitWidth: 520
    implicitHeight: Math.max(88, row.implicitHeight + 40)
    hoverEnabled: true
    padding: 20

    background: Rectangle {
        radius: Theme.radius
        color: control.selected ? Theme.surfaceSelected
             : control.hovered ? Theme.surfaceHover : Theme.surface
        border.width: control.selected ? 2 : 1
        border.color: control.selected ? Theme.accent : Theme.border
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
        Behavior on border.color { ColorAnimation { duration: Theme.animFast } }
    }

    contentItem: RowLayout {
        id: row
        spacing: 18

        Rectangle {
            Layout.preferredWidth: 48
            Layout.preferredHeight: 48
            Layout.alignment: Qt.AlignVCenter
            radius: 14
            color: control.badgeColor
            Text {
                anchors.centerIn: parent
                text: control.glyph
                color: "white"
                font.pixelSize: 22
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
                font.pixelSize: Theme.fontSubtitle
                font.weight: Font.DemiBold
                wrapMode: Text.WordWrap
            }
            Text {
                Layout.fillWidth: true
                visible: text.length > 0
                text: control.description
                color: Theme.textMuted
                font.pixelSize: Theme.fontBody
                wrapMode: Text.WordWrap
                textFormat: Text.StyledText
            }
        }
        Rectangle {
            visible: control.selectable
            Layout.preferredWidth: 22
            Layout.preferredHeight: 22
            Layout.alignment: Qt.AlignVCenter
            radius: 11
            color: "transparent"
            border.width: 2
            border.color: control.selected ? Theme.accent : Theme.border
            Rectangle {
                anchors.centerIn: parent
                width: 10; height: 10; radius: 5
                color: Theme.accent
                visible: control.selected
            }
        }
    }
}
