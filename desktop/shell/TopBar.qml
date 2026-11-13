import QtQuick
import QtQuick.Layouts
import MpireOS.Style

// The frosted top bar: mark and app menus, workspace pill, status tray, clock.
Rectangle {
    id: bar
    property string appName: "Files"
    property var menus: ["Applications", "View"]
    property string workspace: "Personal space"
    property int battery: 98
    property date now: new Date()

    implicitHeight: 44
    color: Theme.chrome
    Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 1; color: "#80FFFFFF" }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 22
        anchors.rightMargin: 24
        spacing: 0

        Mark { Layout.rightMargin: 9 }
        Text {
            text: "MpireOS"
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: 16
            font.weight: Font.DemiBold
            font.letterSpacing: -0.4
        }
        Rectangle { Layout.leftMargin: 16; Layout.rightMargin: 16; Layout.preferredWidth: 1; Layout.preferredHeight: 16; color: Theme.border }
        Text {
            text: bar.appName
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: 13
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
                font.pixelSize: 13
            }
        }
        Item { Layout.fillWidth: true }
    }

    // Workspace pill, centered on the screen.
    Rectangle {
        anchors.centerIn: parent
        height: 28
        width: wsRow.implicitWidth + 24
        radius: 14
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
                font.pixelSize: 13
            }
            Icon { name: "chevronDown"; size: 14 }
        }
        MouseArea { id: wsArea; anchors.fill: parent; hoverEnabled: true }
    }

    RowLayout {
        anchors.right: parent.right
        anchors.rightMargin: 24
        anchors.verticalCenter: parent.verticalCenter
        spacing: 18
        Icon { name: "search"; size: 18; color: Theme.text }
        Icon { name: "bell"; size: 18; color: Theme.text }
        Icon { name: "wifi"; size: 18; color: Theme.text }
        Icon { name: "sliders"; size: 18; color: Theme.text }
        RowLayout {
            spacing: 6
            Icon { name: "battery"; size: 20; color: Theme.text }
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
            font.pixelSize: 13
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
        }
    }
}
