import QtQuick
import QtQuick.Controls.Basic
import MpireSetup

Button {
    id: control
    implicitHeight: 48
    implicitWidth: Math.max(160, contentItem.implicitWidth + 48)
    font.pixelSize: Theme.fontBody
    font.weight: Font.DemiBold
    hoverEnabled: true

    contentItem: Text {
        text: control.text
        font: control.font
        color: control.enabled ? "white" : Theme.textMuted
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
    background: Rectangle {
        radius: height / 2
        color: !control.enabled ? Theme.surface
             : control.down ? Theme.accent
             : control.hovered ? Theme.accentHover : Theme.accent
        border.width: control.enabled ? 0 : 1
        border.color: Theme.border
        scale: control.down ? 0.98 : 1
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
        Behavior on scale { NumberAnimation { duration: Theme.animFast } }
    }
}
