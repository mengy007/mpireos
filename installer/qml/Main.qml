import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtQuick.Window
import MpireSetup
import "pages"

ApplicationWindow {
    id: window
    width: 1280
    height: 800
    visible: true
    title: qsTr("Install MpireOS")
    color: Theme.background

    // Screens in order. Only the first four count as "steps" for the user.
    readonly property var screens: [welcome, disk, user, review, install, done]
    readonly property var stepNames: [qsTr("Welcome"), qsTr("Disk"), qsTr("Account"), qsTr("Review")]
    property int index: 0
    readonly property Item page: stack.currentItem
    readonly property QtObject installer: Installer   // for tools/preview.py

    function go(to) {
        if (to === index) return
        const forward = to > index
        index = to
        stack.replace(stack.currentItem, screens[to], {},
                      forward ? StackView.PushTransition : StackView.PopTransition)
    }

    // Soft glow behind the content.
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.backgroundGlow }
            GradientStop { position: 0.55; color: Theme.background }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 48
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "MpireOS"
                color: Theme.text
                font.pixelSize: 20
                font.weight: Font.Bold
                font.letterSpacing: 0.5
            }
            Item { Layout.fillWidth: true }
            StepIndicator {
                visible: window.index < window.stepNames.length
                steps: window.stepNames
                current: window.index
            }
        }

        StackView {
            id: stack
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: Math.min(720, window.width - 96)
            Layout.fillHeight: true
            Layout.topMargin: 56
            initialItem: welcome
            clip: true

            pushEnter: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.animNormal }
                    NumberAnimation { property: "x"; from: 40; to: 0; duration: Theme.animNormal; easing.type: Easing.OutCubic }
                }
            }
            pushExit: Transition {
                NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Theme.animFast }
            }
            popEnter: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.animNormal }
                    NumberAnimation { property: "x"; from: -40; to: 0; duration: Theme.animNormal; easing.type: Easing.OutCubic }
                }
            }
            popExit: Transition {
                NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Theme.animFast }
            }
            replaceEnter: pushEnter
            replaceExit: pushExit
        }

        // Footer: Back on the left, the primary action always in the same place.
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: Math.min(720, window.width - 96)
            Layout.maximumWidth: Layout.preferredWidth
            Layout.fillWidth: false
            visible: window.page && window.page.showFooter
            GhostButton {
                text: qsTr("Back")
                visible: window.page && window.page.showBack
                onClicked: window.go(window.index - 1)
            }
            Item { Layout.fillWidth: true }
            PrimaryButton {
                text: window.page ? window.page.continueText : ""
                enabled: window.page && window.page.canContinue
                onClicked: {
                    if (window.index === 3) { window.go(4); Installer.start() }
                    else if (window.index === 5) Qt.quit()   // the real backend reboots
                    else window.go(window.index + 1)
                }
            }
        }
    }

    Connections {
        target: Installer
        function onFinishedChanged() { if (Installer.finished) window.go(5) }
    }

    Component { id: welcome; WelcomePage { onInstallChosen: window.go(1); onTryChosen: Qt.quit() } }
    Component { id: disk; DiskPage {} }
    Component { id: user; UserPage {} }
    Component {
        id: review
        ReviewPage {
            onEditLanguage: window.go(0)
            onEditDisk: window.go(1)
            onEditUser: window.go(2)
        }
    }
    Component { id: install; InstallPage {} }
    Component { id: done; DonePage {} }
}
