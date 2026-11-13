import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import MpireOS.Style
import "../shell" as Shell

// mpire-greeter: the MpireOS login screen, as an SDDM theme.
// Uses SDDM's context objects (sddm, userModel, sessionModel) when they exist,
// so it can also be previewed outside SDDM.
Item {
    id: root
    width: 1366
    height: 936

    readonly property bool inSddm: typeof sddm !== "undefined"
    property string userName: inSddm ? userModel.lastUser : "jordan"
    property string realName: "Jordan Lee"
    property int sessionIndex: inSddm ? sessionModel.lastIndex : 0
    property date now: new Date()
    property bool failed: false

    function login() {
        if (inSddm) sddm.login(userName, password.text, sessionIndex)
    }
    Connections {
        target: root.inSddm ? sddm : null
        ignoreUnknownSignals: true
        function onLoginFailed() { root.failed = true; password.text = ""; password.forceActiveFocus() }
    }
    Timer { interval: 1000; repeat: true; running: true; onTriggered: root.now = new Date() }

    Backdrop { anchors.fill: parent }

    // Status, top right
    RowLayout {
        anchors { top: parent.top; right: parent.right; topMargin: 22; rightMargin: 28 }
        spacing: 18
        Icon { name: "keyboard"; size: 18; color: Theme.text }
        Icon { name: "wifi"; size: 18; color: Theme.text }
        RowLayout {
            spacing: 6
            Icon { name: "battery"; size: 20; color: Theme.text }
            Label { role: "small"; text: "98%" }
        }
    }

    ColumnLayout {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -30
        spacing: 0

        Overline {
            Layout.alignment: Qt.AlignHCenter
            text: Qt.formatDate(root.now, "dddd, MMMM d")
        }
        Label {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 6
            role: "display"
            font.pixelSize: 96
            font.weight: Font.ExtraLight
            font.letterSpacing: -4
            text: Qt.formatTime(root.now, "h:mm")
        }
        Label {
            Layout.alignment: Qt.AlignHCenter
            role: "greeting"
            font.pixelSize: 18
            secondary: true
            text: {
                const h = root.now.getHours()
                return h < 12 ? qsTr("Good morning.") : h < 18 ? qsTr("Good afternoon.") : qsTr("Good evening.")
            }
        }

        Card {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 40
            implicitWidth: 340
            implicitHeight: 232
            level: 3
            radius: 20
            padding: 28

            ColumnLayout {
                anchors.fill: parent
                spacing: 0
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 64; Layout.preferredHeight: 64
                    radius: 32
                    gradient: Gradient {
                        GradientStop { position: 0; color: "#C9BDF0" }
                        GradientStop { position: 1; color: "#9C88E0" }
                    }
                    Text {
                        anchors.centerIn: parent
                        text: root.realName.charAt(0)
                        color: "white"
                        font.family: Theme.fontFamily
                        font.pixelSize: 26
                        font.weight: Font.Medium
                    }
                }
                Label {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 12
                    role: "heading"
                    font.pixelSize: 17
                    text: root.realName
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: 18
                    Layout.preferredHeight: 44
                    radius: 22
                    color: password.activeFocus ? Theme.surface : Theme.surfaceSunken
                    border.width: password.activeFocus ? 1.5 : 1
                    border.color: root.failed ? Theme.danger : password.activeFocus ? Theme.accent : Theme.border
                    TextField {
                        id: password
                        anchors { left: parent.left; right: go.left; verticalCenter: parent.verticalCenter; leftMargin: 18; rightMargin: 6 }
                        echoMode: TextInput.Password
                        placeholderText: qsTr("Password")
                        placeholderTextColor: Theme.textTertiary
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 15
                        background: null
                        focus: true
                        onTextEdited: root.failed = false
                        onAccepted: root.login()
                    }
                    Rectangle {
                        id: go
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 5 }
                        width: 34; height: 34; radius: 17
                        color: password.text.length > 0 ? Theme.accent : "#D5D2DE"
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }
                        Icon { anchors.centerIn: parent; name: "arrowRight"; size: 16; color: "white"; weight: 2 }
                        MouseArea { anchors.fill: parent; onClicked: root.login() }
                    }
                }
                Label {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 10
                    role: "small"
                    font.pixelSize: 11
                    color: root.failed ? Theme.danger : Theme.textTertiary
                    text: root.failed ? qsTr("That password didn't work. Try again.") : qsTr("Welcome back.")
                }
            }
        }
    }

    // Bottom left: signature
    RowLayout {
        anchors { left: parent.left; bottom: parent.bottom; leftMargin: 32; bottomMargin: 28 }
        spacing: 10
        Shell.Mark { size: 14 }
        Overline { text: "MpireOS" }
        Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: 12; color: Theme.border }
        Label { role: "small"; secondary: true; text: qsTr("Thoughtfully yours."); font.pixelSize: 11 }
    }

    // Bottom right: sleep, restart, shut down
    RowLayout {
        anchors { right: parent.right; bottom: parent.bottom; rightMargin: 28; bottomMargin: 20 }
        spacing: 10
        Repeater {
            model: [
                { icon: "moon", label: qsTr("Sleep"), act: "suspend" },
                { icon: "refresh", label: qsTr("Restart"), act: "reboot" },
                { icon: "power", label: qsTr("Shut down"), act: "powerOff" }
            ]
            Rectangle {
                required property var modelData
                width: 36; height: 36; radius: 18
                color: pa.containsMouse ? "#CCFFFFFF" : "#80FFFFFF"
                border.color: "#FFFFFFFF"
                Icon { anchors.centerIn: parent; name: modelData.icon; size: 16; color: Theme.text }
                MouseArea {
                    id: pa; anchors.fill: parent; hoverEnabled: true
                    onClicked: if (root.inSddm) sddm[modelData.act]()
                }
                ToolTip.visible: pa.containsMouse
                ToolTip.text: modelData.label
            }
        }
    }
}
