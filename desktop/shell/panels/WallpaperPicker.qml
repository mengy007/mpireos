import QtQuick
import QtQuick.Layouts
import MpireOS.Style
import "../wallpaper"
import "../wallpaper/Wallpapers.js" as Wallpapers

// The wallpaper picker, opened from the desktop menu. Every choice applies
// right away (the desktop shows around the picker), so there is nothing to
// save: Done just closes it.
Card {
    id: root
    property var settings: null             // DesktopSettings (src/desktopsettings.h)
    property real maxHeight: 720
    signal done()

    readonly property string current: settings ? settings.wallpaper : "mpire:fjord"
    readonly property bool currentIsPicture: Wallpapers.kind(current) === "picture"
    readonly property var pictures: settings ? settings.pictures : []
    readonly property int columns: 4
    readonly property real tileWidth: Math.floor((content.width - (columns - 1) * 14) / columns)
    readonly property real tileHeight: Math.round(tileWidth * 9 / 16)

    function choose(source) { if (settings) settings.wallpaper = source }

    // A wallpaper thumbnail with its name; outlined when chosen.
    component Tile: Item {
        id: tile
        property string source
        property string label
        readonly property bool selected: root.current === source
        Layout.preferredWidth: root.tileWidth
        Layout.preferredHeight: root.tileHeight + 26
        Item {
            id: thumb
            width: parent.width
            height: root.tileHeight
            scale: tileArea.pressed ? 0.97 : 1
            Behavior on scale { NumberAnimation { duration: Theme.animFast } }
            WallpaperLayer {
                anchors.fill: parent
                source: tile.source
                thumbnail: true
            }
            // Rounds the corners: a thick frame in the card's color.
            Rectangle {
                anchors.fill: parent
                anchors.margins: -10
                radius: 22
                color: "transparent"
                border.width: 10
                border.color: Theme.surface
            }
            Rectangle {
                anchors.fill: parent
                anchors.margins: tile.selected ? -4 : 0
                radius: tile.selected ? 16 : 12
                color: "transparent"
                border.width: tile.selected ? 2.5 : 1
                border.color: tile.selected ? Theme.accent : tileArea.containsMouse ? Theme.accentHover : Qt.rgba(0, 0, 0, 0.06)
            }
            Rectangle {
                visible: tile.selected
                anchors { right: parent.right; top: parent.top; margins: 6 }
                width: 22; height: 22; radius: 11
                color: Theme.accent
                border.color: "white"; border.width: 1.5
                Icon { anchors.centerIn: parent; name: "check"; size: 14; weight: 2.4; color: "white" }
            }
        }
        Text {
            anchors { top: thumb.bottom; topMargin: 7; left: parent.left; right: parent.right }
            text: tile.label
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
            color: tile.selected ? Theme.accentText : Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: 12
            font.weight: tile.selected ? Font.DemiBold : Font.Normal
        }
        MouseArea {
            id: tileArea
            anchors.fill: thumb
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.choose(tile.source)
        }
    }

    component Chip: Rectangle {
        id: chip
        property string text
        property bool selected
        signal clicked()
        implicitWidth: chipLabel.implicitWidth + 26
        implicitHeight: 30
        radius: 15
        color: selected ? Theme.accentSoft : chipArea.containsMouse ? Theme.surfaceHover : "transparent"
        border.color: selected ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.35) : Theme.border
        Text {
            id: chipLabel
            anchors.centerIn: parent
            text: chip.text
            color: chip.selected ? Theme.accentText : Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: 12
            font.weight: chip.selected ? Font.DemiBold : Font.Normal
        }
        MouseArea { id: chipArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: chip.clicked() }
    }

    width: 780
    implicitHeight: Math.min(maxHeight, header.height + flick.contentHeight + footer.height + 2 * padding + 14)
    padding: 28
    level: 4
    radius: 24

    Keys.onEscapePressed: root.done()

    // Header
    RowLayout {
        id: header
        width: parent.width
        height: 52
        spacing: 14
        Rectangle {
            Layout.preferredWidth: 44; Layout.preferredHeight: 44; radius: 14
            color: Theme.accentSoft
            Icon { anchors.centerIn: parent; name: "image"; size: 22; color: Theme.accent }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Label { Layout.fillWidth: true; role: "title"; text: qsTr("Wallpaper"); font.pixelSize: 20 }
            Label { Layout.fillWidth: true; role: "small"; secondary: true; text: qsTr("Pick one you love. It changes right away.") }
        }
        Rectangle {
            Layout.alignment: Qt.AlignTop
            Layout.preferredWidth: 32; Layout.preferredHeight: 32; radius: 16
            color: closeArea.containsMouse ? Theme.surfaceHover : Theme.surfaceSunken
            Icon { anchors.centerIn: parent; name: "x"; size: 16; color: Theme.textSecondary }
            MouseArea { id: closeArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.done() }
        }
    }

    Flickable {
        id: flick
        anchors { top: header.bottom; topMargin: 14; left: parent.left; right: parent.right; bottom: footer.top; bottomMargin: 0 }
        contentWidth: width
        contentHeight: content.implicitHeight + 14
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: content
            x: 5                         // room for the chosen tile's outline
            y: 5
            width: flick.width - 10
            spacing: 14

            Overline { text: qsTr("MpireOS") }
            GridLayout {
                Layout.fillWidth: true
                columns: root.columns
                columnSpacing: 14
                rowSpacing: 10
                Repeater {
                    model: Wallpapers.builtIn
                    Tile { required property var modelData; source: modelData.id; label: qsTr(modelData.name) }
                }
            }

            Overline { Layout.topMargin: 6; text: qsTr("Colors") }
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                Repeater {
                    model: Wallpapers.colors
                    delegate: Rectangle {
                        id: swatch
                        required property var modelData
                        readonly property string source: "color:" + modelData.color
                        readonly property bool selected: root.current.toLowerCase() === source.toLowerCase()
                        Layout.preferredWidth: 36; Layout.preferredHeight: 36
                        radius: 18
                        color: modelData.color
                        border.color: Qt.rgba(0, 0, 0, 0.08)
                        scale: swatchArea.containsMouse ? 1.08 : 1
                        Behavior on scale { NumberAnimation { duration: Theme.animFast } }
                        Rectangle {
                            visible: swatch.selected
                            anchors.centerIn: parent
                            width: parent.width + 8; height: width; radius: width / 2
                            color: "transparent"
                            border.width: 2.5
                            border.color: Theme.accent
                        }
                        Icon {
                            visible: swatch.selected
                            anchors.centerIn: parent
                            name: "check"; size: 18; weight: 2.4
                            color: Qt.colorEqual(swatch.color, "#F7F9FB") || Qt.colorEqual(swatch.color, "#E4EDEF") ? Theme.text : "white"
                        }
                        MouseArea { id: swatchArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.choose(swatch.source) }
                    }
                }
            }

            Overline { Layout.topMargin: 6; text: qsTr("Your pictures") }
            GridLayout {
                Layout.fillWidth: true
                columns: root.columns
                columnSpacing: 14
                rowSpacing: 10
                // Add a picture: opens the system's file chooser.
                Item {
                    Layout.preferredWidth: root.tileWidth
                    Layout.preferredHeight: root.tileHeight + 26
                    Rectangle {
                        id: addTile
                        width: parent.width
                        height: root.tileHeight
                        radius: 12
                        color: addArea.containsMouse ? Theme.accentSoft : Theme.surfaceSunken
                        border.color: addArea.containsMouse ? Theme.accent : Theme.border
                        border.width: 1.5
                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            Rectangle {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.preferredWidth: 34; Layout.preferredHeight: 34; radius: 17
                                color: Theme.surface
                                Icon { anchors.centerIn: parent; name: "plus"; size: 18; weight: 2; color: Theme.accent }
                            }
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: qsTr("Add a picture")
                                color: Theme.accentText
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                            }
                        }
                        MouseArea {
                            id: addArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (root.settings) root.settings.browse()
                        }
                    }
                    Text {
                        anchors { top: addTile.bottom; topMargin: 7; left: parent.left; right: parent.right }
                        horizontalAlignment: Text.AlignHCenter
                        text: qsTr("From your files")
                        color: Theme.textTertiary
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                    }
                }
                Repeater {
                    model: root.pictures
                    Tile { required property var modelData; source: modelData.url; label: modelData.name }
                }
            }
        }
    }

    // Footer: how a picture is placed, and Done.
    RowLayout {
        id: footer
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 52
        spacing: 8
        Text {
            text: qsTr("Placement")
            color: root.currentIsPicture ? Theme.textSecondary : Theme.textTertiary
            font.family: Theme.fontFamily
            font.pixelSize: 12
            Layout.rightMargin: 4
        }
        Repeater {
            model: [
                { mode: "fill", label: qsTr("Fill screen") },
                { mode: "fit", label: qsTr("Fit") },
                { mode: "center", label: qsTr("Center") },
                { mode: "tile", label: qsTr("Tile") }
            ]
            Chip {
                required property var modelData
                text: modelData.label
                enabled: root.currentIsPicture
                opacity: root.currentIsPicture ? 1 : 0.45
                selected: root.currentIsPicture && root.settings && root.settings.fillMode === modelData.mode
                onClicked: if (root.settings) root.settings.fillMode = modelData.mode
            }
        }
        Item { Layout.fillWidth: true }
        PillButton {
            text: qsTr("Done")
            accent: true
            implicitWidth: 92
            implicitHeight: 36
            radius: 18
            onClicked: root.done()
        }
    }
    Rectangle {
        // A hairline above the footer.
        anchors { left: parent.left; right: parent.right; bottom: footer.top }
        height: 1
        visible: flick.contentHeight > flick.height     // only when the list scrolls under it
        color: Theme.divider
    }
}
