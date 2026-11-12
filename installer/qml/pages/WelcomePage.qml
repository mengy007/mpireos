import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import MpireSetup

SetupPage {
    id: page
    overline: Qt.formatDate(new Date(), "dddd, MMMM d")
    title: qsTr("Welcome to MpireOS")
    subtitle: qsTr("A little space for everything. Let's set yours up; it only takes a few minutes.")
    showBack: false
    showFooter: false

    signal installChosen()
    signal tryChosen()

    RowLayout {
        spacing: 12
        Text {
            text: qsTr("Language")
            color: Theme.textMuted
            font.pixelSize: Theme.fontBody
        }
        ComboBox {
            id: language
            Layout.preferredWidth: 300
            implicitHeight: 44
            model: Installer.languages
            textRole: "name"
            currentIndex: Installer.languageIndex
            onActivated: Installer.languageIndex = currentIndex
            font.pixelSize: Theme.fontBody
            contentItem: Text {
                leftPadding: 14
                text: language.displayText
                color: Theme.text
                font: language.font
                verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle {
                radius: Theme.radiusSmall
                color: Theme.surfaceSunken
                border.color: language.activeFocus ? Theme.accent : Theme.border
            }
        }
    }

    Item { Layout.preferredHeight: 8 }

    ChoiceCard {
        Layout.fillWidth: true
        glyph: "↓"
        selectable: false
        badgeColor: Theme.accent
        glyphColor: "white"
        title: qsTr("Install MpireOS")
        description: qsTr("Set up MpireOS on this computer.")
        onClicked: page.installChosen()
    }
    ChoiceCard {
        Layout.fillWidth: true
        glyph: "▶"
        badgeColor: Theme.skyTint
        glyphColor: Theme.sky
        selectable: false
        title: qsTr("Try it first")
        description: qsTr("Keep using MpireOS from this USB drive. Nothing on your computer changes, and you can install any time.")
        onClicked: page.tryChosen()
    }
    Item { Layout.fillHeight: true }
}
