import QtQuick
import QtQuick.Layouts
import MpireOS.Style

// One of the assistant's replies: Markdown text, who answered, and Copy. While
// a reply streams in, three dots stand in until the first words arrive.
ColumnLayout {
    id: root
    property string text: ""
    property string provider: ""
    property bool error: false
    property bool streaming: false
    signal copy()
    signal fix()
    spacing: 6

    // Thinking…
    Row {
        visible: root.streaming && root.text.length === 0
        spacing: 5
        Layout.topMargin: 4
        Layout.bottomMargin: 4
        Repeater {
            model: 3
            Rectangle {
                required property int index
                width: 7; height: 7; radius: 3.5
                color: Theme.accent
                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    running: root.streaming && root.text.length === 0
                    PauseAnimation { duration: index * 160 }
                    NumberAnimation { from: 0.25; to: 1; duration: 320 }
                    NumberAnimation { from: 1; to: 0.25; duration: 320 }
                    PauseAnimation { duration: (2 - index) * 160 }
                }
            }
        }
    }

    Rectangle {
        visible: root.error
        Layout.fillWidth: true
        Layout.preferredHeight: errText.implicitHeight + 22
        radius: 14
        color: Theme.roseTint
        RowLayout {
            anchors.fill: parent
            anchors.margins: 11
            anchors.leftMargin: 13
            spacing: 10
            Text {
                id: errText
                Layout.fillWidth: true
                text: root.error ? root.text : ""
                wrapMode: Text.Wrap
                color: Theme.text
                font.family: Theme.fontFamily
                font.pixelSize: 12
            }
            Text {
                text: qsTr("AI settings")
                color: Theme.accentText
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.weight: Font.DemiBold
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.fix() }
            }
        }
    }

    Text {
        visible: !root.error && root.text.length > 0
        Layout.fillWidth: true
        text: root.error ? "" : root.text
        textFormat: Text.MarkdownText
        wrapMode: Text.Wrap
        color: Theme.text
        linkColor: Theme.accentText
        font.family: Theme.fontFamily
        font.pixelSize: 13
        lineHeight: 1.25
        onLinkActivated: link => shellApi.openUrl(link)
    }

    RowLayout {
        visible: !root.error && !root.streaming && root.text.length > 0
        spacing: 10
        Text {
            visible: root.provider.length > 0
            text: root.provider
            color: Theme.textTertiary
            font.family: Theme.fontFamily
            font.pixelSize: 10
        }
        Rectangle {
            width: copyRow.implicitWidth + 12; height: 20; radius: 6
            color: copyArea.containsMouse ? Theme.surfaceHover : "transparent"
            Row {
                id: copyRow
                anchors.centerIn: parent
                spacing: 4
                Icon { name: copied.running ? "check" : "copy"; size: 12; color: Theme.textTertiary; anchors.verticalCenter: parent.verticalCenter }
                Text { text: copied.running ? qsTr("Copied") : qsTr("Copy"); color: Theme.textTertiary; font.family: Theme.fontFamily; font.pixelSize: 10 }
            }
            MouseArea { id: copyArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.copy(); copied.restart() } }
            Timer { id: copied; interval: 1400 }
        }
    }
}
