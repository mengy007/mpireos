import QtQuick
import QtQuick.Layouts
import MpireOS.Style

// "Now playing": the current track from any media player (MPRIS).
Card {
    id: card
    plain: true
    property string overline: qsTr("Slow down a little")
    property string title: "Soft Currents"
    property string source: "MpireOS soundscapes"
    implicitWidth: 264
    implicitHeight: 78
    padding: 12

    RowLayout {
        anchors.fill: parent
        spacing: 12
        Rectangle {
            Layout.preferredWidth: 54; Layout.preferredHeight: 54
            radius: 10
            clip: true
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#C9C3DD" }
                GradientStop { position: 0.55; color: "#8E8AA6" }
                GradientStop { position: 1.0; color: "#B9C4C9" }
            }
            Rectangle {
                width: parent.width * 1.6; height: width; radius: width / 2
                x: -parent.width * 0.3; y: parent.height * 0.55
                color: "#D8DEE0"; opacity: 0.8
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            Overline { text: card.overline; font.pixelSize: 8 }
            Label { role: "heading"; text: card.title; font.pixelSize: 13 }
            Label { role: "small"; secondary: true; text: card.source; font.pixelSize: 11 }
        }
        Icon { name: "play"; size: 18; color: Theme.text; Layout.rightMargin: 6 }
    }
}
