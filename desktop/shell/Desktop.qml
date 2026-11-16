import QtQuick
import QtQuick.Layouts
import MpireOS.Style
import "widgets"

// Mpire Desktop as one scene, for previews. In the running shell, the top bar,
// dock, and widget column are separate layer-shell surfaces built from these
// same components.
Item {
    id: desktop
    property date now: new Date()
    property string greeting: qsTr("A little space for everything.")

    Backdrop { anchors.fill: parent }

    // Greeting
    ColumnLayout {
        x: 52; y: Theme.topBarHeight + 34
        spacing: 8
        Overline { text: Qt.formatDate(desktop.now, "dddd, MMMM d") }
        RowLayout {
            spacing: 12
            Label { role: "greeting"; text: desktop.greeting }
            Icon { name: "sparkle"; size: 18; color: Theme.accent }
        }
    }

    // Shortcuts
    RowLayout {
        anchors.right: parent.right
        anchors.rightMargin: 52
        y: Theme.topBarHeight + 30
        spacing: 26
        Repeater {
            model: [{ icon: "folder", label: qsTr("My files") }, { icon: "image", label: qsTr("Wallpapers") }]
            ColumnLayout {
                required property var modelData
                spacing: 6
                Card {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: 44; implicitHeight: 44; radius: 12; padding: 0; level: 1
                    Icon { anchors.centerIn: parent; name: modelData.icon; size: 22; color: Theme.text }
                }
                Label { Layout.alignment: Qt.AlignHCenter; role: "small"; text: modelData.label; font.pixelSize: 11 }
            }
        }
    }

    // Widgets
    ColumnLayout {
        anchors.right: parent.right
        anchors.rightMargin: 40
        y: Theme.topBarHeight + 112
        spacing: 16
        TodayWidget { now: desktop.now }
        FocusWidget {}
        NowPlayingWidget {}
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 4
            spacing: 6
            Icon { name: "sliders"; size: 14 }
            Label { role: "small"; secondary: true; text: qsTr("Make it yours"); font.pixelSize: 11 }
        }
    }

    TopBar {
        anchors { left: parent.left; right: parent.right; top: parent.top }
        now: desktop.now
        // Sample content for the preview; the running shell fills in real values.
        appName: "Files"; menus: ["Applications", "View"]; workspace: "Personal space"
        battery: 98; showNotifications: true
    }

    Dock {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16
        now: desktop.now
    }
}
