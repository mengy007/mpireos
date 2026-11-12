import QtQuick
import QtQuick.Controls.Basic
import MpireSetup

Button {
    id: control
    implicitHeight: 44
    implicitWidth: contentItem.implicitWidth + 40
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontBody
    hoverEnabled: true

    contentItem: Text {
        text: control.text
        font: control.font
        color: control.hovered ? Theme.text : Theme.textMuted
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
    }
    background: Rectangle {
        radius: Theme.radiusSmall
        color: control.hovered ? Theme.surfaceHover : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
    }
}
