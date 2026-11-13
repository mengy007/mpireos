import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import MpireSetup

SetupPage {
    id: page
    overline: qsTr("Step 3 of 4")
    title: qsTr("Who's using this computer?")
    subtitle: qsTr("This is your account. You can add more people later.")

    property bool userNameEdited: false
    readonly property bool userNameValid: /^[a-z_][a-z0-9_-]{0,31}$/.test(Installer.userName)
    readonly property bool passwordsMatch: Installer.password === confirm.text
    readonly property int strength: {
        const p = Installer.password
        let s = 0
        if (p.length >= 8) s++
        if (p.length >= 12) s++
        if (/[A-Z]/.test(p) && /[a-z]/.test(p)) s++
        if (/[0-9]/.test(p) || /[^A-Za-z0-9]/.test(p)) s++
        return s
    }

    canContinue: Installer.fullName.trim().length > 0 && userNameValid
                 && Installer.password.length > 0 && passwordsMatch

    Field {
        id: fullName
        Layout.fillWidth: true
        label: qsTr("Your name")
        placeholder: qsTr("Jordan Lee")
        text: Installer.fullName
        input.onTextEdited: {
            Installer.fullName = text
            if (!page.userNameEdited) Installer.userName = Installer.suggestUserName(text)
        }
        Component.onCompleted: input.forceActiveFocus()
    }
    Field {
        Layout.fillWidth: true
        label: qsTr("Username")
        text: Installer.userName
        input.onTextEdited: { page.userNameEdited = true; Installer.userName = text }
        error: Installer.userName.length > 0 && !page.userNameValid
        hint: error ? qsTr("Use lowercase letters, numbers, - and _. Start with a letter.")
                    : qsTr("Your computer will be called %1.").arg(Installer.computerName)
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.spacing
        Field {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.alignment: Qt.AlignTop
            label: qsTr("Password")
            echoMode: TextInput.Password
            text: Installer.password
            input.onTextEdited: Installer.password = text
            hint: Installer.password.length === 0 ? ""
                : [qsTr("Weak password"), qsTr("Weak password"), qsTr("Fair password"), qsTr("Good password"), qsTr("Strong password")][page.strength]
        }
        Field {
            id: confirm
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.alignment: Qt.AlignTop
            label: qsTr("Confirm password")
            echoMode: TextInput.Password
            error: text.length > 0 && !page.passwordsMatch
            hint: error ? qsTr("Passwords don't match") : ""
        }
    }
    Item { Layout.fillHeight: true }
}
