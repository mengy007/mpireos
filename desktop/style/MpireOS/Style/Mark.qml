import QtQuick
import MpireOS.Style

// The MpireOS mark: a teal squircle with a white peak.
Rectangle {
    property real size: 22
    implicitWidth: size
    implicitHeight: size
    radius: size * 0.3
    gradient: Gradient {
        GradientStop { position: 0; color: "#269CA1" }
        GradientStop { position: 1; color: "#094551" }
    }
    Icon {
        anchors.centerIn: parent
        name: "logo"
        size: parent.size * 0.82
        color: "white"
        weight: 2.4
    }
}
