import QtQuick

// The desktop's wallpaper. A new choice fades in over the old one (once a
// picture has loaded), so trying wallpapers in the picker feels calm.
Item {
    id: root
    property string source: "mpire:mist"
    property string fillMode: "fill"

    property int front: 0
    readonly property var layers: [a, b]

    function show() {
        const cur = layers[front]
        if (cur.source === source && cur.fillMode === fillMode)
            return
        const next = layers[1 - front]
        next.source = source
        next.fillMode = fillMode
        next.z = 1
        cur.z = 0
        next.opacity = 0
        front = 1 - front
        if (next.ready || next.failed) fade.start()
    }
    onSourceChanged: show()
    onFillModeChanged: show()
    Component.onCompleted: { a.source = source; a.fillMode = fillMode; a.opacity = 1 }

    WallpaperLayer {
        id: a
        anchors.fill: parent
        onReadyChanged: if (ready && root.layers[root.front] === a && opacity < 1) fade.start()
        onFailedChanged: if (failed && root.layers[root.front] === a && opacity < 1) fade.start()
    }
    WallpaperLayer {
        id: b
        anchors.fill: parent
        opacity: 0
        onReadyChanged: if (ready && root.layers[root.front] === b && opacity < 1) fade.start()
        onFailedChanged: if (failed && root.layers[root.front] === b && opacity < 1) fade.start()
    }
    NumberAnimation {
        id: fade
        target: root.layers[root.front]
        property: "opacity"
        to: 1
        duration: 420
        easing.type: Easing.OutCubic
        onFinished: root.layers[1 - root.front].source = ""   // free the old picture
    }
}
