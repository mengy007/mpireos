import QtQuick
import QtQuick.Shapes
import MpireOS.Style
import "Wallpapers.js" as Wallpapers

// One wallpaper: one of ours ("mpire:<name>"), a solid color ("color:#rrggbb"),
// or a picture (a file:// URL) placed by `fillMode`. `thumbnail` loads
// pictures small, for the picker.
Item {
    id: root
    property string source: ""
    property string fillMode: "fill"        // fill | fit | center | tile
    property bool thumbnail: false
    readonly property string kind: Wallpapers.kind(source)
    readonly property var spec: kind === "mpire" ? (Wallpapers.find(source) || Wallpapers.builtIn[0]) : null
    // False until a picture has loaded; Wallpaper.qml fades in when it turns true.
    readonly property bool ready: kind !== "picture" || picture.status === Image.Ready
    readonly property bool failed: kind === "picture" && picture.status === Image.Error
    clip: true

    // Ours: the default backdrop
    Backdrop {
        anchors.fill: parent
        visible: root.kind === "mpire" && !root.spec.from && !root.spec.scene || root.failed
    }

    // Ours: a drawn scene
    Loader {
        anchors.fill: parent
        active: root.kind === "mpire" && root.spec.scene === "fjord"
        sourceComponent: Fjord {}
    }

    // Ours: wash, glow, rings
    Item {
        anchors.fill: parent
        visible: root.kind === "mpire" && !!root.spec.from
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: -1
                fillGradient: LinearGradient {
                    x1: 0; y1: 0
                    x2: root.width; y2: root.height
                    GradientStop { position: 0; color: root.spec && root.spec.from ? root.spec.from : "transparent" }
                    GradientStop { position: 1; color: root.spec && root.spec.to ? root.spec.to : "transparent" }
                }
                startX: 0; startY: 0
                PathLine { x: root.width; y: 0 }
                PathLine { x: root.width; y: root.height }
                PathLine { x: 0; y: root.height }
                PathLine { x: 0; y: 0 }
            }
        }
        Shape {
            id: glow
            readonly property real r: Math.max(root.width, root.height) * 0.75
            readonly property real cx: root.width * (root.spec && root.spec.glowAt ? root.spec.glowAt[0] : 0.5)
            readonly property real cy: root.height * (root.spec && root.spec.glowAt ? root.spec.glowAt[1] : 0.5)
            anchors.fill: parent
            opacity: root.spec && root.spec.dark ? 0.55 : 0.85
            ShapePath {
                strokeWidth: -1
                fillGradient: RadialGradient {
                    centerX: glow.cx; centerY: glow.cy; centerRadius: glow.r
                    focalX: glow.cx; focalY: glow.cy
                    GradientStop { position: 0; color: root.spec && root.spec.glow ? root.spec.glow : "transparent" }
                    GradientStop { position: 1; color: "transparent" }
                }
                startX: 0; startY: 0
                PathLine { x: root.width; y: 0 }
                PathLine { x: root.width; y: root.height }
                PathLine { x: 0; y: root.height }
                PathLine { x: 0; y: 0 }
            }
        }
        Repeater {
            model: [
                { x: 0.42, y: -0.55, s: 1.35, w: 0.10, o: 0.9 },
                { x: 0.60, y: -0.10, s: 1.15, w: 0.06, o: 0.7 },
                { x: -0.35, y: 0.45, s: 1.05, w: 0.08, o: 0.7 },
                { x: 0.25, y: 0.62, s: 0.90, w: 0.05, o: 0.5 }
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
                border.color: root.spec && root.spec.ring ? root.spec.ring : "white"
                opacity: modelData.o * (root.spec && root.spec.ringOpacity !== undefined ? root.spec.ringOpacity : 0.3)
            }
        }
    }

    // A solid color
    Rectangle {
        anchors.fill: parent
        visible: root.kind === "color"
        color: root.kind === "color" ? root.source.substring(6) : "transparent"
    }

    // A picture
    Rectangle {
        anchors.fill: parent
        visible: root.kind === "picture" && !root.failed
        color: Theme.backdrop                 // around a fitted or centered picture
        Image {
            id: picture
            anchors.fill: parent
            source: root.kind === "picture" ? Wallpapers.pictureUrl(root.source) : ""
            asynchronous: true
            cache: root.thumbnail
            smooth: true
            mipmap: root.thumbnail
            fillMode: root.thumbnail || root.fillMode === "fill" ? Image.PreserveAspectCrop
                    : root.fillMode === "fit" ? Image.PreserveAspectFit
                    : root.fillMode === "tile" ? Image.Tile : Image.Pad
            // Decode at screen size (or thumbnail size) for fill and fit; tile
            // and center use the picture's own size.
            sourceSize: root.thumbnail || root.fillMode === "fill" || root.fillMode === "fit"
                        ? Qt.size(Math.max(1, root.width), Math.max(1, root.height)) : undefined
        }
    }
}
