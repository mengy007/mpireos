import QtQuick
import QtQuick.Layouts
import MpireOS.Style

// Quick settings slider: an icon (clickable, e.g. mute) and a soft track.
RowLayout {
    id: root
    property string glyph: "volume"
    property int value: 50          // 0-100
    property bool dimmed: false     // e.g. muted
    signal moved(int value)
    signal iconClicked()
    spacing: 12

    Rectangle {
        Layout.preferredWidth: 32; Layout.preferredHeight: 32; radius: 16
        color: iconArea.containsMouse ? Theme.surfaceHover : "transparent"
        Icon { anchors.centerIn: parent; name: root.glyph; size: 18; color: root.dimmed ? Theme.textTertiary : Theme.text }
        MouseArea { id: iconArea; anchors.fill: parent; hoverEnabled: true; onClicked: root.iconClicked() }
    }
    Item {
        id: track
        Layout.fillWidth: true
        Layout.preferredHeight: 24
        readonly property real fraction: Math.max(0, Math.min(1, (drag.pressed ? drag.live : root.value) / 100))
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width; height: 6; radius: 3
            color: Theme.divider
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(6, parent.width * track.fraction); height: 6; radius: 3
            color: root.dimmed ? Theme.textTertiary : Theme.accent
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            x: track.fraction * (parent.width - width)
            width: 18; height: 18; radius: 9
            color: "white"
            border.color: Theme.border
        }
        MouseArea {
            id: drag
            property int live: 0
            anchors.fill: parent
            anchors.margins: -6
            function at(mx) { return Math.round(Math.max(0, Math.min(1, (mx - 6) / track.width)) * 100) }
            onPressed: mouse => { live = at(mouse.x); root.moved(live) }
            onPositionChanged: mouse => { if (pressed) { live = at(mouse.x); root.moved(live) } }
        }
    }
    Text {
        Layout.preferredWidth: 34
        horizontalAlignment: Text.AlignRight
        text: root.value + "%"
        color: Theme.textSecondary
        font.family: Theme.fontFamily
        font.pixelSize: 12
        font.features: { "tnum": 1 }
    }
}
