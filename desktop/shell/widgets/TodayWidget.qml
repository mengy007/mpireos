import QtQuick
import QtQuick.Layouts
import MpireOS.Style

// "Today": big day number, month grid, and a one-line note.
Card {
    id: card
    plain: true
    property date now: new Date()
    property string noteTitle: qsTr("A fresh page")
    property string noteText: qsTr("Make something good today.")
    implicitWidth: 264
    implicitHeight: 258
    padding: 20

    readonly property int year: now.getFullYear()
    readonly property int month: now.getMonth()
    readonly property int firstWeekday: (new Date(year, month, 1).getDay() + 6) % 7   // Monday first
    readonly property int days: new Date(year, month + 1, 0).getDate()

    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        RowLayout {
            Layout.fillWidth: true
            Overline { text: qsTr("Today") }
            Item { Layout.fillWidth: true }
            Icon { name: "expand"; size: 16 }
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 12
            spacing: 14
            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: 0
                Label { role: "small"; secondary: true; text: Qt.formatDate(card.now, "dddd") }
                Label { role: "display"; text: card.now.getDate(); font.pixelSize: 48 }
            }
            Grid {
                Layout.alignment: Qt.AlignTop
                columns: 7
                columnSpacing: 2
                rowSpacing: 1
                Repeater {
                    model: ["M", "T", "W", "T", "F", "S", "S"]
                    Text {
                        required property string modelData
                        width: 18; height: 16
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData
                        color: Theme.textTertiary
                        font.family: Theme.fontFamily
                        font.pixelSize: 8
                        font.weight: Font.DemiBold
                    }
                }
                Repeater {
                    model: card.firstWeekday + card.days
                    Item {
                        required property int index
                        readonly property int day: index - card.firstWeekday + 1
                        readonly property bool today: day === card.now.getDate()
                        width: 18; height: 16
                        Rectangle {
                            anchors.centerIn: parent
                            width: 17; height: 17; radius: 8.5
                            color: Theme.accent
                            visible: parent.today
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: parent.day > 0
                            text: parent.day
                            color: parent.today ? "white" : (index % 7 >= 5 ? Theme.textTertiary : Theme.text)
                            font.family: Theme.fontFamily
                            font.pixelSize: 9
                            font.weight: parent.today ? Font.DemiBold : Font.Normal
                        }
                    }
                }
            }
        }
        Item { Layout.fillHeight: true }
        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.divider }
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 12
            spacing: 10
            Rectangle { Layout.preferredWidth: 3; Layout.fillHeight: true; radius: 1.5; color: Theme.accent }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Label { role: "small"; text: card.noteTitle; font.weight: Font.DemiBold; font.pixelSize: 12 }
                Label { role: "small"; secondary: true; text: card.noteText; font.pixelSize: 11 }
            }
            Overline { text: Qt.formatDate(card.now, "MMM"); font.pixelSize: 9 }
        }
    }
}
