import QtQuick
import QtQuick.Layouts
import MpireOS.Style

// The notification list, opened from the bell in the top bar.
Card {
    id: root
    property var server: null          // NotificationServer (src/notifications.h)
    property date now: new Date()
    signal linkOpened(string url)
    readonly property var items: server ? server.history : []

    width: 392
    implicitHeight: Math.min(620, content.implicitHeight + 2 * padding)
    padding: 16
    level: 4
    radius: 22

    ColumnLayout {
        id: content
        anchors.fill: parent
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            Label { Layout.fillWidth: true; role: "heading"; text: qsTr("Notifications"); font.pixelSize: 16 }
            PillButton { visible: root.items.length > 0; text: qsTr("Clear all"); onClicked: root.server.clearAll() }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Icon { name: "bellOff"; size: 18; color: Theme.textSecondary }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Label { role: "body"; text: qsTr("Do not disturb") }
                Label { role: "small"; secondary: true; text: qsTr("Hold popups. Urgent ones still show."); font.pixelSize: 11 }
            }
            Toggle {
                checked: root.server ? root.server.doNotDisturb : false
                onToggled: on => root.server.doNotDisturb = on
            }
        }
        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.divider }

        // Empty
        ColumnLayout {
            visible: root.items.length === 0
            Layout.fillWidth: true
            Layout.topMargin: 18
            Layout.bottomMargin: 22
            spacing: 10
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 48; Layout.preferredHeight: 48; radius: 24
                color: Theme.accentSoft
                Icon { anchors.centerIn: parent; name: "bell"; size: 22; color: Theme.accentText }
            }
            Label { Layout.alignment: Qt.AlignHCenter; role: "heading"; text: qsTr("You're all caught up") }
            Label { Layout.alignment: Qt.AlignHCenter; role: "small"; secondary: true; text: qsTr("New notifications will collect here.") }
        }

        ListView {
            id: list
            visible: root.items.length > 0
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, 470)
            clip: true
            spacing: 8
            model: root.items
            boundsBehavior: Flickable.StopAtBounds
            delegate: NotificationCard {
                required property var modelData
                width: ListView.view.width
                item: modelData
                popup: false
                now: root.now
                onDismissed: root.server.dismiss(modelData.id)
                onActivated: key => { if (key.length > 0) root.server.invoke(modelData.id, key) }
                onLinkOpened: url => root.linkOpened(url)
            }
        }
    }
}
