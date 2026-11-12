import QtQuick
import QtQuick.Layouts
import MpireSetup

SetupPage {
    id: page
    overline: qsTr("Done")
    title: qsTr("You're all set")
    subtitle: qsTr("MpireOS is installed. Remove the USB drive when your computer turns off, then sign in as %1.").arg(Installer.userName)
    showBack: false
    continueText: qsTr("Restart now")

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
}
