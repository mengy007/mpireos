import QtQuick
import QtQuick.Layouts
import MpireOS.Style
import ".."
import "../widgets"

// The desktop itself (layer-shell background layer): wallpaper, greeting,
// shortcuts, and widgets. `shellApi` comes from mpire-shell (src/shellapi.h).
Item {
    id: desktop
    property date now: new Date()
    Timer { interval: 10000; repeat: true; running: true; triggeredOnStart: true; onTriggered: desktop.now = new Date() }

    Backdrop { anchors.fill: parent }

    ColumnLayout {
        x: 52; y: 44 + 34
        spacing: 8
        Overline { text: Qt.formatDate(desktop.now, "dddd, MMMM d") }
        RowLayout {
            spacing: 12
            Label {
                role: "greeting"
                text: {
                    const h = desktop.now.getHours()
                    return h < 12 ? qsTr("Good morning.") : h < 18 ? qsTr("Good afternoon.") : qsTr("Good evening.")
                }
            }
            Icon { name: "sparkle"; size: 18; color: Theme.accent }
        }
    }

    // Shortcuts
    ColumnLayout {
        anchors.right: parent.right
        anchors.rightMargin: 52 + 264 + 24
        y: 44 + 30
        spacing: 6
        Card {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 44; implicitHeight: 44; radius: 12; padding: 0; level: 1
            Icon { anchors.centerIn: parent; name: "folder"; size: 22; color: Theme.text }
            MouseArea { anchors.fill: parent; onClicked: shellApi.launch("dolphin") }
        }
        Label { Layout.alignment: Qt.AlignHCenter; role: "small"; text: qsTr("My files"); font.pixelSize: 11 }
    }

    // Widgets
    ColumnLayout {
        anchors.right: parent.right
        anchors.rightMargin: 40
        y: 44 + 30
        spacing: 16
        TodayWidget { now: desktop.now }
        FocusWidget {}
    }

    // Bottom corners
    RowLayout {
        anchors { left: parent.left; bottom: parent.bottom; leftMargin: 52; bottomMargin: 34 }
        spacing: 10
        Mark { size: 14 }
        Overline { text: "MpireOS" }
        Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: 12; color: Theme.border }
        Label { role: "small"; secondary: true; text: qsTr("Thoughtfully yours."); font.pixelSize: 11 }
    }
    RowLayout {
        anchors { right: parent.right; bottom: parent.bottom; rightMargin: 46; bottomMargin: 30 }
        spacing: 8
        Icon { name: "search"; size: 14 }
        Label { role: "small"; secondary: true; text: qsTr("Find your flow"); font.pixelSize: 11 }
        Rectangle {
            implicitWidth: kbd.implicitWidth + 12; implicitHeight: 20; radius: 5
            color: "transparent"; border.color: Theme.border
            Label { id: kbd; anchors.centerIn: parent; role: "small"; secondary: true; text: "Alt Space"; font.pixelSize: 10 }
        }
        TapHandler { onTapped: shellApi.TogglePanel("launcher") }
    }
}
