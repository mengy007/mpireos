import QtQuick
import MpireOS.Style

// The MpireOS mark: a violet squircle with a white peak.
Rectangle {
    property real size: 22
    implicitWidth: size
    implicitHeight: size
    radius: size * 0.3
    gradient: Gradient {
        GradientStop { position: 0; color: "#9A86E6" }
        GradientStop { position: 1; color: "#6A55C4" }
    }
    Icon {
        anchors.centerIn: parent
        name: "logo"
        size: parent.size * 0.82
        color: "white"
        weight: 2.4
    }
}
