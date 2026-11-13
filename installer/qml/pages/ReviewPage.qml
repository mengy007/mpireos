import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import MpireSetup

SetupPage {
    id: page
    overline: qsTr("Step 4 of 4")
    title: qsTr("Ready when you are")
    subtitle: qsTr("Check the details below. Nothing changes until you press Install.")
    continueText: qsTr("Install now")

    signal editLanguage()
    signal editDisk()
    signal editUser()

    readonly property string diskSummary: Installer.diskMode === "erase"
        ? qsTr("Erase %1 (%2) and install MpireOS").arg(Installer.disk.name).arg(Installer.disk.size)
        : qsTr("Install alongside %1 on %2").arg(Installer.disk.otherOs).arg(Installer.disk.name)

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: rows.implicitHeight + 40
        radius: Theme.radius
        color: Theme.surfaceSunken
        border.width: 0

        ColumnLayout {
            id: rows
            anchors.fill: parent
            anchors.margins: 20
            spacing: 14

            SummaryRow {
                Layout.fillWidth: true
                label: qsTr("Disk")
                value: page.diskSummary
                warning: Installer.diskMode === "erase"
                editable: true
                onEditRequested: page.editDisk()
            }
            SummaryRow {
                Layout.fillWidth: true
                label: qsTr("Encryption")
                value: Installer.encrypt ? qsTr("On, unlocked with your password") : qsTr("Off")
                editable: true
                onEditRequested: page.editDisk()
            }
            SummaryRow {
                Layout.fillWidth: true
                label: qsTr("Account")
                value: qsTr("%1 (%2)").arg(Installer.fullName).arg(Installer.userName)
                editable: true
                onEditRequested: page.editUser()
            }
            SummaryRow {
                Layout.fillWidth: true
                label: qsTr("Computer name")
                value: Installer.computerName
                editable: true
                onEditRequested: page.editUser()
            }
            SummaryRow {
                Layout.fillWidth: true
                label: qsTr("Language")
                value: Installer.languages[Installer.languageIndex].name
                editable: true
                onEditRequested: page.editLanguage()
            }
            SummaryRow {
                Layout.fillWidth: true
                label: qsTr("Keyboard")
                value: Installer.detectedKeyboard
                editable: true
                onEditRequested: keyboardPopup.open()
            }
            SummaryRow {
                Layout.fillWidth: true
                label: qsTr("Time zone")
                value: Installer.detectedTimezone.replace("_", " ")
                editable: true
                onEditRequested: timezonePopup.open()
            }
        }
    }
    Item { Layout.fillHeight: true }

    PickerPopup {
        id: keyboardPopup
        title: qsTr("Keyboard layout")
        options: ["English (US)", "English (UK)", "Spanish (Latin American)", "French (Canada)", "German"]
        current: Installer.detectedKeyboard
        onPicked: value => Installer.detectedKeyboard = value
    }
    PickerPopup {
        id: timezonePopup
        title: qsTr("Time zone")
        options: ["America/New_York", "America/Chicago", "America/Denver", "America/Phoenix",
                  "America/Los_Angeles", "America/Anchorage", "Pacific/Honolulu", "UTC"]
        current: Installer.detectedTimezone
        onPicked: value => Installer.detectedTimezone = value
    }
}
