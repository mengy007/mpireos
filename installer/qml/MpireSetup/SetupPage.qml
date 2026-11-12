import QtQuick
import QtQuick.Layouts
import MpireSetup

// Base for every screen: a title, a subtitle, and the page's content.
// The window's bottom bar reads canContinue and continueText.
Item {
    id: page
    property string title
    property string subtitle
    property bool canContinue: true
    property string continueText: qsTr("Continue")
    property bool showBack: true
    property bool showFooter: true
    default property alias content: body.data

    signal continueRequested()

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Text {
            Layout.fillWidth: true
            visible: text.length > 0
            text: page.title
            color: Theme.text
            font.pixelSize: Theme.fontTitle
            font.weight: Font.Bold
            wrapMode: Text.WordWrap
        }
        Text {
            Layout.fillWidth: true
            Layout.topMargin: 10
            visible: text.length > 0
            text: page.subtitle
            color: Theme.textMuted
            font.pixelSize: Theme.fontSubtitle
            wrapMode: Text.WordWrap
            lineHeight: 1.2
        }
        ColumnLayout {
            id: body
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: 32
            spacing: Theme.spacing
        }
    }
}
