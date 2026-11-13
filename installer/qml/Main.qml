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
    color: Theme.backdrop
    font.family: Theme.fontFamily

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

    // Backdrop: pale lavender with soft light sweeps (design-system.md, Color).
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Theme.backdropHighlight }
            GradientStop { position: 1.0; color: Theme.backdrop }
        }
    }
    Repeater {
        model: [
            { x: 0.55, y: -0.35, s: 1.25, o: 0.55 },
            { x: 0.70, y: 0.10, s: 1.10, o: 0.35 },
            { x: -0.30, y: 0.55, s: 1.00, o: 0.40 }
        ]
        delegate: Rectangle {
            required property var modelData
            width: window.width * modelData.s
            height: width
            radius: width / 2
            x: window.width * modelData.x
            y: window.height * modelData.y
            color: "transparent"
            border.width: width * 0.08
            border.color: "white"
            opacity: modelData.o * 0.5
        }
    }

    // Top bar: frosted, like the desktop's.
    Rectangle {
        id: topBar
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: 44
        color: Theme.chrome
        Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 1; color: Theme.divider }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 24
            anchors.rightMargin: 24
            spacing: 10
            Rectangle {
                Layout.preferredWidth: 18; Layout.preferredHeight: 18
                radius: 6
                gradient: Gradient {
                    GradientStop { position: 0; color: Theme.accentHover }
                    GradientStop { position: 1; color: Theme.accentPressed }
                }
            }
            Text {
                text: "MpireOS"
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 16
                font.weight: Font.DemiBold
                font.letterSpacing: -0.3
            }
            Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: 16; color: Theme.border }
            Text {
                text: qsTr("Setup")
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: 13
            }
            Item { Layout.fillWidth: true }
            StepIndicator {
                visible: window.index < window.stepNames.length
                steps: window.stepNames
                current: window.index
            }
        }
    }

    // The setup window: a white card floating on the backdrop.
    Item {
        id: card
        width: Math.min(820, window.width - 96)
        height: Math.min(620, window.height - 160)
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 10

        SoftShadow { target: cardBg; level: 3 }
        Rectangle {
            id: cardBg
            anchors.fill: parent
            radius: Theme.radiusWindow
            color: Theme.surface
            border.color: Theme.border
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            StackView {
                id: stack
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: 44
                Layout.bottomMargin: 20
                initialItem: welcome
                clip: true

                pushEnter: Transition {
                    ParallelAnimation {
                        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.animNormal }
                        NumberAnimation { property: "x"; from: 24; to: 0; duration: Theme.animNormal; easing.type: Easing.OutCubic }
                    }
                }
                pushExit: Transition {
                    NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Theme.animFast }
                }
                popEnter: Transition {
                    ParallelAnimation {
                        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.animNormal }
                        NumberAnimation { property: "x"; from: -24; to: 0; duration: Theme.animNormal; easing.type: Easing.OutCubic }
                    }
                }
                popExit: Transition {
                    NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Theme.animFast }
                }
                replaceEnter: pushEnter
                replaceExit: pushExit
            }

            // Footer: Back on the left, the primary action always in the same place.
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.divider
                visible: footer.visible
            }
            RowLayout {
                id: footer
                Layout.fillWidth: true
                Layout.leftMargin: 32
                Layout.rightMargin: 32
                Layout.topMargin: 14
                Layout.bottomMargin: 14
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
                        else if (window.index === 4) window.go(3)        // after a failed install
                        else if (window.index === 5) window.page.requestRestart()
                        else window.go(window.index + 1)
                    }
                }
            }
        }
    }

    // Bottom-left signature, as on the desktop.
    RowLayout {
        anchors { left: parent.left; bottom: parent.bottom; leftMargin: 28; bottomMargin: 20 }
        spacing: 10
        Overline { text: "MpireOS" }
        Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: 12; color: Theme.border }
        Text {
            text: qsTr("Thoughtfully yours.")
            color: Theme.textTertiary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSmall
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
