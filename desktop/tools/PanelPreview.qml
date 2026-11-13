import QtQuick
import "../shell"
import "../shell/surfaces"

// tools/preview.py's "panels" scene: the desktop with the notification popups
// and the panel overlay on top, as mpire-shell stacks them.
Item {
    id: root
    property date now: new Date()
    Desktop { anchors.fill: parent; now: root.now }
    PopupSurface {
        anchors { right: parent.right; top: parent.top; topMargin: 44 + 4; rightMargin: 4 }
        width: implicitWidth; height: implicitHeight
        visible: shellApi.panel === ""
        now: root.now
    }
    PanelSurface {
        anchors.fill: parent
        visible: shellApi.panel !== ""
        now: root.now
    }
}
