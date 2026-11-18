import QtQuick
import MpireOS.Style

// The MpireOS mark: the skyline "M" from the official logo (branding/logo).
// At 24 px and below it is the simplified skyline, since windows would blur.
Item {
    property real size: 22
    implicitWidth: size
    implicitHeight: size
    Image {
        anchors.fill: parent
        sourceSize: Qt.size(parent.size * 2, parent.size * 2)
        source: Qt.resolvedUrl(parent.size <= 24 ? "images/mpireos-mark-small.svg" : "images/mpireos-mark.svg")
        fillMode: Image.PreserveAspectFit
        smooth: true
    }
}
