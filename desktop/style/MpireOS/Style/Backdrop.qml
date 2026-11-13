import QtQuick

// The MpireOS desktop backdrop: pale lavender with broad, soft light sweeps.
Item {
    id: root
    clip: true
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
            { x: 0.42, y: -0.55, s: 1.35, w: 0.10, o: 0.55 },
            { x: 0.60, y: -0.10, s: 1.15, w: 0.06, o: 0.45 },
            { x: -0.35, y: 0.45, s: 1.05, w: 0.08, o: 0.45 },
            { x: 0.25, y: 0.62, s: 0.90, w: 0.05, o: 0.30 }
        ]
        delegate: Rectangle {
            required property var modelData
            width: root.width * modelData.s
            height: width
            radius: width / 2
            x: root.width * modelData.x
            y: root.height * modelData.y
            color: "transparent"
            border.width: width * modelData.w
            border.color: "white"
            opacity: modelData.o * 0.6
        }
    }
}
