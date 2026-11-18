import QtQuick
import MpireOS.Style

// The MpireOS splash between the login screen and the desktop (KSplash).
// It picks up where the login screen leaves off (the same light backdrop),
// shows the logo and a cyan spinner like the boot splash, and at the end
// dims to the desktop's dark backdrop so the desktop doesn't flash in.
//
// ksplashqml sets `stage` from 1 to 6 as the session starts, and closes the
// splash when the session is ready.
Item {
    id: root
    width: 1366
    height: 768

    property int stage
    readonly property bool ready: stage >= 5

    Backdrop { anchors.fill: parent }

    Column {
        id: content
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -24
        spacing: 56
        opacity: 0
        scale: 0.985

        Image {
            anchors.horizontalCenter: parent.horizontalCenter
            source: "images/mpireos-logo-light.svg"
            height: Math.round(Math.min(root.width, root.height) * 0.075)
            width: height * (1414.1 / 354)
            sourceSize: Qt.size(width * 2, height * 2)
            fillMode: Image.PreserveAspectFit
            smooth: true
        }

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 34
            height: 34

            // The boot splash's spinner: a pale ring with a brand cyan arc.
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: "transparent"
                border.width: 3
                border.color: "#2600B4C1"
            }
            Canvas {
                id: arc
                anchors.fill: parent
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    ctx.lineWidth = 3
                    ctx.lineCap = "round"
                    ctx.strokeStyle = Theme.accent
                    ctx.beginPath()
                    ctx.arc(width / 2, height / 2, width / 2 - 1.5, -Math.PI / 2, Math.PI * 0.1)
                    ctx.stroke()
                }
                RotationAnimator on rotation {
                    from: 0; to: 360
                    duration: 1200
                    loops: Animation.Infinite
                    running: root.visible
                }
            }
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 48
        text: "Getting your desktop ready"
        color: Theme.textTertiary
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSmall + 1
        opacity: content.opacity
    }

    // Fade the logo in as soon as the splash appears.
    ParallelAnimation {
        running: true
        NumberAnimation { target: content; property: "opacity"; to: 1; duration: 320; easing.type: Easing.OutCubic }
        NumberAnimation { target: content; property: "scale"; to: 1; duration: 420; easing.type: Easing.OutCubic }
    }

    // The desktop is dark: dim to its backdrop just before it appears.
    Rectangle {
        anchors.fill: parent
        color: "#0B1316"
        opacity: root.ready ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.InOutQuad } }
    }
}
