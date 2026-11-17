import QtQuick
import QtQuick.Layouts
import MpireOS.Style

// The frosted top bar: mark and app menus, workspace pill, the system tray,
// and clock. The tray on the right holds other apps' status icons (from
// systemTray, src/tray.h), newest leftmost, then MpireOS's own: search,
// notifications, network, quick settings, battery.
// Parts with nothing real to show stay hidden: no app name or menus until the
// shell tracks the active window, no battery on desktops.
Rectangle {
    id: bar
    property string appName: ""
    property var menus: []
    property string workspace: ""
    property int battery: -1               // percent, or -1 when there is no battery
    property bool showNotifications: true
    property int unread: 0                  // dot on the bell
    property bool online: true              // dims the network icon when offline
    property bool wired: false
    property date now: new Date()
    // Apps' tray icons: {key, title, tooltip, icon (image URL), attention}
    property var trayItems: []
    property string openTrayKey: ""         // whose menu is open (its icon stays highlighted)

    signal searchClicked()
    // x: the icon's center, in screen coordinates (the bar spans the screen).
    signal trayActivated(string key, real x)
    signal trayMenuRequested(string key, real x)
    signal traySecondaryActivated(string key, real x)
    signal trayScrolled(string key, int delta, bool horizontal)
    signal notificationsClicked()
    signal networkClicked()
    signal settingsClicked()

    component TrayIcon: Icon {
        signal clicked()
        size: 16
        color: Theme.text
        opacity: trayArea.containsMouse ? 0.7 : 1
        MouseArea { id: trayArea; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; onClicked: parent.clicked() }
    }

    implicitHeight: Theme.topBarHeight
    color: Theme.chrome
    Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 1; color: Theme.divider }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 16
        spacing: 0

        Mark { size: 18; Layout.rightMargin: 7 }
        Text {
            // The wordmark: "Mpire" in ink, "OS" in logo cyan.
            text: "Mpire<font color=\"" + Theme.brand + "\">OS</font>"
            textFormat: Text.StyledText
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: 13
            font.weight: Font.DemiBold
            font.letterSpacing: -0.4
        }
        Rectangle { visible: bar.appName.length > 0; Layout.leftMargin: 12; Layout.rightMargin: 12; Layout.preferredWidth: 1; Layout.preferredHeight: 12; color: Theme.border }
        Text {
            visible: bar.appName.length > 0
            text: bar.appName
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: 12
            font.weight: Font.DemiBold
        }
        Repeater {
            model: bar.menus
            Text {
                required property string modelData
                Layout.leftMargin: 20
                text: modelData
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: 12
            }
        }
        Item { Layout.fillWidth: true }
    }

    // Workspace pill, centered on the screen.
    Rectangle {
        visible: bar.workspace.length > 0
        anchors.centerIn: parent
        height: 22
        width: wsRow.implicitWidth + 20
        radius: 11
        color: wsArea.containsMouse ? "#B3FFFFFF" : "transparent"
        RowLayout {
            id: wsRow
            anchors.centerIn: parent
            spacing: 8
            Rectangle { Layout.preferredWidth: 6; Layout.preferredHeight: 6; radius: 3; color: Theme.accent }
            Text {
                text: bar.workspace
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: 12
            }
            Icon { name: "chevronDown"; size: 12 }
        }
        MouseArea { id: wsArea; anchors.fill: parent; hoverEnabled: true }
    }

    RowLayout {
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 14

        // Apps' status icons, left of MpireOS's own (as on a Mac).
        Row {
            visible: bar.trayItems.length > 0
            Layout.rightMargin: -2
            spacing: 2
            Repeater {
                model: bar.trayItems
                Rectangle {
                    id: appIcon
                    required property var modelData
                    function centerX() { return mapToItem(null, width / 2, 0).x }
                    objectName: "tray:" + modelData.key
                    width: 26
                    height: 22
                    radius: 7
                    color: bar.openTrayKey === modelData.key ? "#1F0B1F25"
                         : appArea.pressed ? "#1A0B1F25" : appArea.containsMouse ? "#0F0B1F25" : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    Image {
                        anchors.centerIn: parent
                        width: 16
                        height: 16
                        sourceSize: Qt.size(32, 32)
                        source: appIcon.modelData.icon
                        smooth: true
                        mipmap: true
                    }
                    // Wants attention: a small accent dot.
                    Rectangle {
                        visible: appIcon.modelData.attention === true
                        anchors { right: parent.right; top: parent.top; rightMargin: 3; topMargin: 2 }
                        width: 6; height: 6; radius: 3
                        color: Theme.accent
                        border.color: "white"
                    }
                    MouseArea {
                        id: appArea
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                        onClicked: mouse => {
                            const key = appIcon.modelData.key
                            if (mouse.button === Qt.RightButton) bar.trayMenuRequested(key, appIcon.centerX())
                            else if (mouse.button === Qt.MiddleButton) bar.traySecondaryActivated(key, appIcon.centerX())
                            else bar.trayActivated(key, appIcon.centerX())
                        }
                        onWheel: wheel => {
                            const horizontal = Math.abs(wheel.angleDelta.x) > Math.abs(wheel.angleDelta.y)
                            bar.trayScrolled(appIcon.modelData.key, horizontal ? wheel.angleDelta.x : wheel.angleDelta.y, horizontal)
                        }
                    }
                }
            }
        }

        TrayIcon { name: "search"; onClicked: bar.searchClicked() }
        TrayIcon {
            name: "bell"
            visible: bar.showNotifications
            onClicked: bar.notificationsClicked()
            Rectangle {
                visible: bar.unread > 0
                anchors { right: parent.right; top: parent.top; rightMargin: -1; topMargin: -1 }
                width: 7; height: 7; radius: 3.5
                color: Theme.accent
                border.color: "white"
            }
        }
        TrayIcon { name: bar.wired ? "ethernet" : bar.online ? "wifi" : "wifiOff"; opacity: bar.online ? 1 : 0.55; onClicked: bar.networkClicked() }
        TrayIcon { name: "sliders"; onClicked: bar.settingsClicked() }
        RowLayout {
            visible: bar.battery >= 0
            spacing: 6
            Icon { name: "battery"; size: 17; color: Theme.text }
            Text {
                text: bar.battery + "%"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 12
            }
        }
        Text {
            Layout.leftMargin: 6
            text: Qt.formatTime(bar.now, "h:mm AP")
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: 12
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
        }
    }
}
