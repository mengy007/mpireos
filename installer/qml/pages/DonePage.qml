import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import MpireSetup

SetupPage {
    id: page
    overline: qsTr("Done")
    title: qsTr("You're all set")
    subtitle: qsTr("MpireOS is installed. After restarting, sign in as %1.").arg(Installer.userName)
    showBack: false
    continueText: qsTr("Restart now")

    // Main.qml calls this for "Restart now": ask for the install media first,
    // so the computer doesn't start the installer again.
    function requestRestart() { removeMedia.open() }

    Rectangle {
        Layout.preferredWidth: 96
        Layout.preferredHeight: 96
        radius: 48
        color: Theme.sageTint
        Text {
            anchors.centerIn: parent
            text: "✓"
            color: Theme.success
            font.pixelSize: 48
            font.weight: Font.Bold
        }
    }
    Item { Layout.fillHeight: true }

    Popup {
        id: removeMedia
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: 440
        modal: true
        closePolicy: Popup.CloseOnEscape
        padding: 28
        background: Rectangle { radius: Theme.radius; color: Theme.surface; border.color: Theme.border }
        Overlay.modal: Rectangle { color: Theme.scrim }

        contentItem: ColumnLayout {
            spacing: 10
            Text {
                Layout.fillWidth: true
                text: qsTr("Remove the installation media")
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSubtitle
                font.weight: Font.DemiBold
                wrapMode: Text.WordWrap
            }
            Text {
                Layout.fillWidth: true
                text: qsTr("Unplug the USB drive or take out the disc you installed from. In a virtual machine, detach the ISO. Otherwise your computer may start the installer again instead of MpireOS.")
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontBody
                wrapMode: Text.WordWrap
                lineHeight: 1.2
            }
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 14
                Item { Layout.fillWidth: true }
                GhostButton { text: qsTr("Not yet"); onClicked: removeMedia.close() }
                PrimaryButton { text: qsTr("I've removed it, restart"); onClicked: Installer.restart() }
            }
        }
    }
}
