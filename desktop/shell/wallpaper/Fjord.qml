import QtQuick
import QtQuick.Shapes

// "Night fjord", Mpire Desktop's default wallpaper, drawn here (no image file):
// a moonlit sky over layered mountain ridges, mist along the shore, and a
// still lake that mirrors it all. Deep teal-black, so the dark glass and the
// cyan accent sit well on it. Ridges come from a seeded midpoint-displacement
// line, so they look the same at every size.
Item {
    id: root
    readonly property real horizon: height * 0.6

    // A ridge line across the width: [{x, y}], y in 0..1 of `height`.
    function ridge(seed, base, rough, peaks) {
        let s = seed
        const rnd = () => { s = (s * 16807) % 2147483647; return s / 2147483647 }
        let pts = [base + (rnd() - 0.5) * rough, base + (rnd() - 0.5) * rough]
        let amp = rough
        for (let level = 0; level < 7; level++) {
            const next = []
            for (let i = 0; i < pts.length - 1; i++) {
                next.push(pts[i])
                next.push((pts[i] + pts[i + 1]) / 2 + (rnd() - 0.5) * amp)
            }
            next.push(pts[pts.length - 1])
            pts = next
            amp *= 0.62
        }
        // Raise a few peaks so the skyline has character.
        for (let p = 0; p < peaks.length; p++) {
            const at = peaks[p][0], h = peaks[p][1], w = peaks[p][2]
            for (let i = 0; i < pts.length; i++) {
                const d = Math.abs(i / (pts.length - 1) - at) / w
                if (d < 1) pts[i] -= h * Math.pow(1 - d, 1.35) * (0.85 + 0.3 * rnd())
            }
        }
        return pts
    }
    function polygon(pts, w, h, bottom) {
        const out = []
        for (let i = 0; i < pts.length; i++)
            out.push(Qt.point(w * i / (pts.length - 1), h * pts[i]))
        out.push(Qt.point(w, bottom), Qt.point(0, bottom), out[0])
        return out
    }

    readonly property var far: ridge(7, 0.52, 0.12, [[0.14, 0.08, 0.14], [0.58, 0.10, 0.12], [0.86, 0.07, 0.09]])
    readonly property var mid: ridge(41, 0.57, 0.12, [[0.27, 0.22, 0.20], [0.44, 0.06, 0.08], [0.78, 0.08, 0.12]])
    readonly property var near: ridge(97, 0.605, 0.05, [[0.04, 0.08, 0.10], [0.97, 0.10, 0.12]])

    // Sky
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#081114" }
            GradientStop { position: 0.45; color: "#10242A" }
            GradientStop { position: 0.6; color: "#183338" }
            GradientStop { position: 1.0; color: "#060D10" }
        }
    }

    // Moon and its glow
    Item {
        id: moon
        readonly property real r: Math.max(8, root.width * 0.016)
        x: root.width * 0.7
        y: root.height * 0.14
        Shape {
            x: -moon.r * 14; y: -moon.r * 14; width: moon.r * 28; height: moon.r * 28
            ShapePath {
                strokeWidth: -1
                fillGradient: RadialGradient {
                    centerX: moon.r * 14; centerY: moon.r * 14; centerRadius: moon.r * 14
                    focalX: centerX; focalY: centerY
                    GradientStop { position: 0; color: "#33BFE3E0" }
                    GradientStop { position: 0.25; color: "#127FB8B6" }
                    GradientStop { position: 1; color: "#00000000" }
                }
                PathRectangle { width: moon.r * 28; height: moon.r * 28 }
            }
        }
        Rectangle {
            x: -moon.r; y: -moon.r; width: 2 * moon.r; height: width; radius: moon.r
            gradient: Gradient {
                GradientStop { position: 0; color: "#E8EFEC" }
                GradientStop { position: 1; color: "#AFC4C0" }
            }
        }
    }

    // The landscape, then its reflection in the lake.
    component Landscape: Item {
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: -1
                fillGradient: LinearGradient {
                    x1: 0; y1: root.height * 0.3; x2: 0; y2: root.horizon
                    GradientStop { position: 0; color: "#2A4448" }
                    GradientStop { position: 1; color: "#1A3034" }
                }
                PathPolyline { path: root.polygon(root.far, root.width, root.height, root.horizon + 2) }
            }
            ShapePath {
                strokeWidth: -1
                fillGradient: LinearGradient {
                    x1: 0; y1: root.height * 0.3; x2: 0; y2: root.horizon
                    GradientStop { position: 0; color: "#1A2E33" }
                    GradientStop { position: 1; color: "#0F1E22" }
                }
                PathPolyline { path: root.polygon(root.mid, root.width, root.height, root.horizon + 2) }
            }
            ShapePath {
                strokeWidth: -1
                fillColor: "#0A1518"
                PathPolyline { path: root.polygon(root.near, root.width, root.height, root.horizon + 2) }
            }
        }
        // Mist settling over the water line.
        Rectangle {
            width: root.width
            y: root.horizon - root.height * 0.12
            height: root.height * 0.14
            gradient: Gradient {
                GradientStop { position: 0; color: "#00365459" }
                GradientStop { position: 0.75; color: "#33406166" }
                GradientStop { position: 1; color: "#14365459" }
            }
        }
    }

    Item {
        id: scene
        width: root.width
        height: root.horizon
        clip: true
        Landscape { width: root.width; height: root.height }
    }

    // The lake: the scene mirrored, darker, with ripples.
    Item {
        y: root.horizon
        width: root.width
        height: root.height - root.horizon
        clip: true
        Item {
            width: root.width
            height: root.horizon
            transform: Scale { origin.y: root.horizon / 2; yScale: -1 }
            opacity: 0.42
            Rectangle {      // the mirrored sky
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#081114" }
                    GradientStop { position: 0.75; color: "#10242A" }
                    GradientStop { position: 1.0; color: "#183338" }
                }
            }
            Landscape { width: root.width; height: root.height }
        }
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#40102226" }
                GradientStop { position: 1.0; color: "#F2050B0D" }
            }
        }
        // Moonlight on the water: a column of short bright strokes.
        Repeater {
            model: 40
            Rectangle {
                required property int index
                readonly property real t: index / 40
                x: root.width * 0.7 - width / 2 + Math.sin(index * 2.3) * root.width * (0.004 + t * 0.01)
                y: (root.height - root.horizon) * (0.03 + t * 0.7)
                width: root.width * (0.035 - t * 0.022) * (0.4 + 0.6 * Math.abs(Math.sin(index * 1.7)))
                height: 1
                color: "#C9DEDA"
                opacity: 0.22 * (1 - t) * (0.5 + 0.5 * Math.abs(Math.cos(index * 0.9)))
            }
        }
        // The shoreline: a faint lit edge.
        Rectangle { width: parent.width; height: 1; color: "#2A5A5E"; opacity: 0.5 }
    }
}
