import QtQuick
import QtQuick.Layouts
import "../panels"

// Notification popups (layer-shell overlay, top right). mpire-shell sizes the
// surface to implicitHeight and hides it when there are none.
Item {
    id: surface
    readonly property var shown: notifications.popups.slice(0, 3)
    property date now: new Date()
    Timer { interval: 30000; repeat: true; running: surface.shown.length > 0; onTriggered: surface.now = new Date() }

    implicitWidth: 392
    implicitHeight: shown.length > 0 ? column.implicitHeight + 8 + 24 : 0

    ColumnLayout {
        id: column
        x: 16
        y: 8
        width: 360
        spacing: 10
        Repeater {
            model: surface.shown
            NotificationCard {
                required property var modelData
                Layout.fillWidth: true
                item: modelData
                now: surface.now
                onDismissed: notifications.dismiss(modelData.id)
                onActivated: key => {
                    if (key.length > 0) notifications.invoke(modelData.id, key)
                    else notifications.hidePopup(modelData.id)
                }
                onLinkOpened: url => shellApi.openUrl(url)
            }
        }
    }
}
