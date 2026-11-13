import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import MpireSetup

SetupPage {
    id: page
    overline: qsTr("Installing")
    title: qsTr("Making your space")
    subtitle: Installer.status
    showBack: false
    showFooter: false

    readonly property var tour: [
        { title: qsTr("Undo any update"), text: qsTr("MpireOS takes a snapshot before every update. If something goes wrong, pick an earlier snapshot when your computer starts.") },
        { title: qsTr("Thousands of apps"), text: qsTr("Find apps in the Software center, from Flathub and the Arch Linux repositories.") },
        { title: qsTr("Built in the open"), text: qsTr("MpireOS is open source and US-based, with no tracking by default.") }
    ]
    property int tourIndex: 0

    ProgressBar {
        id: bar
        Layout.fillWidth: true
        value: Installer.progress
        background: Rectangle { implicitHeight: 6; radius: 3; color: Theme.surfaceSunken }
        contentItem: Item {
            Rectangle {
                width: bar.visualPosition * parent.width
                height: parent.height
                radius: 3
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Theme.accent }
                    GradientStop { position: 1; color: Theme.lavender }
                }
                Behavior on width { NumberAnimation { duration: 200 } }
            }
        }
    }
    Text {
        text: qsTr("%1% complete").arg(Math.round(Installer.progress * 100))
        color: Theme.textMuted
        font.pixelSize: Theme.fontSmall
    }

    Item { Layout.preferredHeight: 24 }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 160
        radius: Theme.radius
        color: Theme.surfaceSunken
        border.width: 0
        ColumnLayout {
            id: tourCard
            anchors.fill: parent
            anchors.margins: 28
            spacing: 10
            Text {
                text: page.tour[page.tourIndex].title
                color: Theme.text
                font.pixelSize: 18
                font.weight: Font.DemiBold
            }
            Text {
                Layout.fillWidth: true
                text: page.tour[page.tourIndex].text
                color: Theme.textMuted
                font.pixelSize: Theme.fontSubtitle
                wrapMode: Text.WordWrap
            }
            Behavior on opacity { NumberAnimation { duration: Theme.animNormal } }
        }
    }
    Item { Layout.fillHeight: true }

    Timer {
        interval: 7000
        repeat: true
        running: page.visible
        onTriggered: page.tourIndex = (page.tourIndex + 1) % page.tour.length
    }
}
