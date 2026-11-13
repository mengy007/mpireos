import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import MpireSetup

Popup {
    id: popup
    property string title
    property var options: []
    property string current
    signal picked(string value)

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: 420
    modal: true
    padding: 24
    background: Rectangle { radius: Theme.radius; color: Theme.surface; border.color: Theme.border }
    Overlay.modal: Rectangle { color: Theme.scrim }

    contentItem: ColumnLayout {
        spacing: 8
        Text {
            text: popup.title
            color: Theme.text
            font.pixelSize: Theme.fontSubtitle
            font.weight: Font.DemiBold
            Layout.bottomMargin: 8
        }
        Repeater {
            model: popup.options
            delegate: ItemDelegate {
                required property string modelData
                Layout.fillWidth: true
                implicitHeight: 42
                text: modelData.replace("_", " ")
                contentItem: Text {
                    text: parent.text
                    color: modelData === popup.current ? Theme.accentText : Theme.text
                    font.pixelSize: Theme.fontBody
                    verticalAlignment: Text.AlignVCenter
                    leftPadding: 12
                }
                background: Rectangle {
                    radius: Theme.radiusSmall
                    color: parent.hovered ? Theme.surfaceHover : "transparent"
                }
                onClicked: { popup.picked(modelData); popup.close() }
            }
        }
    }
}
