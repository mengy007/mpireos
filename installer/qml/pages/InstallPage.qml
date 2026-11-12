import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import MpireSetup

SetupPage {
    id: page
    overline: Installer.failed ? qsTr("Install stopped") : qsTr("Installing")
    title: Installer.failed ? qsTr("Something went wrong") : qsTr("Making your space")
    subtitle: Installer.failed
              ? qsTr("MpireOS couldn't finish installing. Your settings are kept, so you can go back and try again.")
              : Installer.status
    showBack: false
    showFooter: Installer.failed
    continueText: qsTr("Back to review")

    readonly property var tour: [
        { title: qsTr("Undo any update"), text: qsTr("MpireOS takes a snapshot before every update. If something goes wrong, pick an earlier snapshot when your computer starts.") },
        { title: qsTr("Thousands of apps"), text: qsTr("Find apps in the Software center, from Flathub and the Arch Linux repositories.") },
        { title: qsTr("Built in the open"), text: qsTr("MpireOS is open source and US-based, with no tracking by default.") }
    ]
    property int tourIndex: 0

    // Shown only when the install fails.
    Rectangle {
        Layout.fillWidth: true
        visible: Installer.failed
        implicitHeight: errorColumn.implicitHeight + 40
        radius: Theme.radius
        color: Theme.surfaceSunken
        ColumnLayout {
            id: errorColumn
            anchors.fill: parent
            anchors.margins: 20
            spacing: 8
            Text {
                Layout.fillWidth: true
                text: Installer.errorMessage
                color: Theme.danger
                font.pixelSize: Theme.fontBody
                wrapMode: Text.WordWrap
            }
            Text {
                Layout.fillWidth: true
                text: qsTr("The full log is in %1.").arg(Installer.logPath)
                color: Theme.textMuted
                font.pixelSize: Theme.fontSmall
                wrapMode: Text.WordWrap
            }
        }
    }

    ProgressBar {
        id: bar
        visible: !Installer.failed
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
        visible: !Installer.failed
        text: qsTr("%1% complete").arg(Math.round(Installer.progress * 100))
        color: Theme.textMuted
        font.pixelSize: Theme.fontSmall
    }

    Item { Layout.preferredHeight: 24 }

    Rectangle {
        Layout.fillWidth: true
        visible: !Installer.failed
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
