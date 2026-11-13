import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import MpireSetup

SetupPage {
    id: page
    overline: qsTr("Step 2 of 4")
    title: qsTr("Where should MpireOS go?")
    subtitle: Installer.disks.length === 0
              ? qsTr("MpireOS needs a disk of at least 12 GB, and none was found. Connect one, then check again.")
              : Installer.disks.length > 1
              ? qsTr("Choose a disk, then how to use it.")
              : qsTr("MpireOS will be installed on %1 (%2).").arg(Installer.disk.name).arg(Installer.disk.size)
    canContinue: Installer.disks.length > 0

    GhostButton {
        visible: Installer.disks.length === 0 && Installer.real
        text: qsTr("Check again")
        onClicked: Installer.system.refreshDisks()
    }

    // Disk picker only appears when there is a real choice to make.
    Flow {
        Layout.fillWidth: true
        visible: Installer.disks.length > 1
        spacing: 12
        Repeater {
            model: Installer.disks
            delegate: ChoiceCard {
                required property int index
                required property var modelData
                width: 300
                glyph: "◉"
                title: modelData.name
                description: modelData.size
                selected: Installer.diskIndex === index
                onClicked: Installer.diskIndex = index
            }
        }
    }

    ChoiceCard {
        Layout.fillWidth: true
        visible: Installer.disks.length > 0
        glyph: "✦"
        badgeColor: Theme.lavenderTint
        glyphColor: Theme.accent
        title: qsTr("Erase disk and install MpireOS")
        description: Installer.disk.otherOs
                     ? qsTr("<font color='%1'>This removes %2 and all files on this disk.</font>").arg(Theme.danger).arg(Installer.disk.otherOs)
                     : Installer.disk.hasData
                     ? qsTr("<font color='%1'>This disk has files on it. They will all be removed.</font>").arg(Theme.danger)
                     : qsTr("Uses the whole disk.")
        selected: Installer.diskMode === "erase"
        onClicked: Installer.diskMode = "erase"
    }
    ChoiceCard {
        Layout.fillWidth: true
        visible: Installer.alongsideSupported && !!Installer.disk.otherOs
        glyph: "⇆"
        badgeColor: Theme.sageTint
        glyphColor: Theme.sage
        title: qsTr("Install alongside %1").arg(Installer.disk.otherOs || "")
        description: qsTr("Keep %1 and choose which one to start each time you turn on your computer. Space is split evenly; you can change this under Advanced.").arg(Installer.disk.otherOs || "")
        selected: Installer.diskMode === "alongside"
        onClicked: Installer.diskMode = "alongside"
    }

    Rectangle {
        Layout.fillWidth: true
        visible: Installer.disks.length > 0
        Layout.topMargin: 8
        implicitHeight: encryptRow.implicitHeight + 32
        radius: Theme.radius
        color: Theme.surfaceSunken
        border.width: 0
        RowLayout {
            id: encryptRow
            anchors.fill: parent
            anchors.margins: 16
            spacing: 16
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                Text {
                    text: qsTr("Encrypt my disk")
                    color: Theme.text
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                }
                Text {
                    Layout.fillWidth: true
                    text: qsTr("Keeps your files private if this computer is lost or stolen. You'll unlock it with your password when it starts.")
                    color: Theme.textSecondary
                    font.pixelSize: 13
                    wrapMode: Text.WordWrap
                }
            }
            Switch {
                id: encryptSwitch
                checked: Installer.encrypt
                onToggled: Installer.encrypt = checked
                indicator: Rectangle {
                    implicitWidth: 44; implicitHeight: 26; radius: 13
                    color: encryptSwitch.checked ? Theme.accent : "#D5D2DE"
                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                    Rectangle {
                        width: 20; height: 20; radius: 10; y: 3
                        x: encryptSwitch.checked ? parent.width - width - 3 : 3
                        color: "white"
                        Behavior on x { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
                    }
                }
            }
        }
    }

    Text {
        text: qsTr("Advanced options")
        color: Theme.accentText
        font.pixelSize: Theme.fontSmall
        font.underline: false
        ToolTip.visible: advArea.containsMouse
        ToolTip.text: qsTr("Manual partitioning is coming in a later release.")
        MouseArea { id: advArea; anchors.fill: parent; hoverEnabled: true }
    }
    Item { Layout.fillHeight: true }
}
