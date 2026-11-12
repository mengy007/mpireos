import QtQuick
import QtQuick.Layouts
import MpireOS.Style

// "A moment of focus": a simple focus timer.
Card {
    id: card
    plain: true
    property int minutes: 25
    property int remaining: minutes * 60
    property bool running: false
    implicitWidth: 264
    implicitHeight: 146
    padding: 20

    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Icon { name: "focus"; size: 16 }
            Overline { text: qsTr("A moment of focus") }
            Item { Layout.fillWidth: true }
            Icon { name: "refresh"; size: 15 }
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 10
            ColumnLayout {
                spacing: 2
                Label {
                    role: "display"
                    font.pixelSize: 40
                    text: Math.floor(card.remaining / 60) + ":" + String(card.remaining % 60).padStart(2, "0")
                }
                Label { role: "small"; secondary: true; text: qsTr("One thing at a time.") }
            }
            Item { Layout.fillWidth: true }
            Rectangle {
                Layout.preferredWidth: 44; Layout.preferredHeight: 44
                radius: 22
                color: playArea.containsMouse ? Theme.accentHover : Theme.accent
                Icon { anchors.centerIn: parent; anchors.horizontalCenterOffset: 1; name: "play"; size: 18; color: "white" }
                MouseArea { id: playArea; anchors.fill: parent; hoverEnabled: true; onClicked: card.running = !card.running }
            }
        }
        Item { Layout.fillHeight: true }
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 3
            radius: 1.5
            color: Theme.surfaceSunken
            Rectangle {
                width: parent.width * (1 - card.remaining / (card.minutes * 60))
                height: parent.height
                radius: 1.5
                color: Theme.accent
            }
        }
    }
    Timer {
        interval: 1000; repeat: true; running: card.running && card.remaining > 0
        onTriggered: card.remaining--
    }
}
