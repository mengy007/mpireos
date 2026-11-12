import QtQuick
import QtQuick.Controls.Basic
import MpireSetup

Button {
    id: control
    implicitHeight: 48
    implicitWidth: contentItem.implicitWidth + 40
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
        radius: height / 2
        color: control.hovered ? Theme.surface : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
    }
}
