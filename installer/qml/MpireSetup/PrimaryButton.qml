import QtQuick
import QtQuick.Controls.Basic
import MpireSetup

Button {
    id: control
    implicitHeight: 44
    implicitWidth: Math.max(140, contentItem.implicitWidth + 44)
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontBody
    font.weight: Font.DemiBold
    hoverEnabled: true

    contentItem: Text {
        text: control.text
        font: control.font
        color: control.enabled ? "white" : Theme.textTertiary
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
    background: Rectangle {
        radius: Theme.radiusSmall
        color: !control.enabled ? Theme.surfaceSunken
             : control.down ? Theme.accentPressed
             : control.hovered ? Theme.accentHover : Theme.accent
        border.width: control.enabled ? 0 : 1
        border.color: Theme.border
        scale: control.down ? 0.98 : 1
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
        Behavior on scale { NumberAnimation { duration: Theme.animFast } }
    }
}
