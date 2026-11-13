import QtQuick
import QtQuick.Layouts
import MpireOS.Style

// Quick settings, opened from the top bar: network, do not disturb, volume,
// brightness, battery, and power. Restart and shut down ask first.
Card {
    id: root
    property var status: null           // SystemStatus (src/systemstatus.h)
    property var notifier: null         // NotificationServer, for do not disturb
    property string confirm: ""         // "restart" | "powerOff" | "logOut" while asking
    signal openCommand(string command)

    component Tile: Rectangle {
        id: tile
        property string glyph
        property string title
        property string subtitle
        property bool on: false
        property bool more: false       // shows a chevron that opens details
        signal toggled()
        signal details()
        Layout.fillWidth: true
        Layout.preferredHeight: 64
        radius: 16
        color: on ? Theme.accentSoft : (tileArea.containsMouse ? Theme.surfaceHover : Theme.surfaceSunken)
        border.color: on ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.25) : "transparent"
        MouseArea { id: tileArea; anchors.fill: parent; hoverEnabled: true; onClicked: tile.toggled() }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 8
            spacing: 10
            Rectangle {
                Layout.preferredWidth: 34; Layout.preferredHeight: 34; radius: 17
                color: tile.on ? Theme.accent : Theme.surface
                Icon { anchors.centerIn: parent; name: tile.glyph; size: 18; color: tile.on ? "white" : Theme.textSecondary }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Text { Layout.fillWidth: true; text: tile.title; elide: Text.ElideRight; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.DemiBold }
                Text { Layout.fillWidth: true; text: tile.subtitle; elide: Text.ElideRight; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: 11 }
            }
            Rectangle {
                visible: tile.more
                Layout.preferredWidth: 26; Layout.preferredHeight: 26; radius: 13
                color: moreArea.containsMouse ? Theme.surface : "transparent"
                Icon { anchors.centerIn: parent; name: "chevronRight"; size: 16 }
                MouseArea { id: moreArea; anchors.fill: parent; hoverEnabled: true; onClicked: tile.details() }
            }
        }
    }
    component RoundButton: Rectangle {
        id: rb
        property string glyph
        property string tip
        signal clicked()
        Layout.preferredWidth: 40; Layout.preferredHeight: 40; radius: 20
        color: rbArea.containsMouse ? Theme.surfaceHover : Theme.surfaceSunken
        Icon { anchors.centerIn: parent; name: rb.glyph; size: 18; color: Theme.text }
        MouseArea { id: rbArea; anchors.fill: parent; hoverEnabled: true; onClicked: rb.clicked() }
    }

    readonly property bool hasStatus: status !== null
    readonly property string netKind: hasStatus ? status.networkKind : ""

    width: 360
    implicitHeight: content.implicitHeight + 2 * padding
    padding: 16
    level: 4
    radius: 22

    ColumnLayout {
        id: content
        width: parent.width
        spacing: 14

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            rowSpacing: 10
            columnSpacing: 10
            Tile {
                visible: root.hasStatus && (root.status.hasWifi || root.netKind !== "wired")
                glyph: root.hasStatus && root.status.wifiEnabled ? "wifi" : "wifiOff"
                title: qsTr("Wi-Fi")
                subtitle: !root.hasStatus ? "" : !root.status.wifiEnabled ? qsTr("Off")
                        : root.netKind === "wifi" ? root.status.network : qsTr("Not connected")
                on: root.hasStatus && root.status.wifiEnabled
                more: true
                onToggled: root.status.setWifiEnabled(!root.status.wifiEnabled)
                onDetails: root.openCommand("kcmshell6 kcm_networkmanagement")
            }
            Tile {
                visible: root.netKind === "wired"
                glyph: "ethernet"
                title: qsTr("Wired")
                subtitle: qsTr("Connected")
                on: true
                more: true
                onToggled: root.openCommand("kcmshell6 kcm_networkmanagement")
                onDetails: root.openCommand("kcmshell6 kcm_networkmanagement")
            }
            Tile {
                glyph: "bellOff"
                title: qsTr("Do not disturb")
                subtitle: on ? qsTr("On") : qsTr("Off")
                on: root.notifier !== null && root.notifier.doNotDisturb
                onToggled: root.notifier.doNotDisturb = !root.notifier.doNotDisturb
            }
        }

        LevelSlider {
            visible: root.hasStatus && root.status.volume >= 0
            Layout.fillWidth: true
            glyph: root.hasStatus && (root.status.muted || root.status.volume === 0) ? "volumeMute" : "volume"
            value: root.hasStatus ? root.status.volume : 0
            dimmed: root.hasStatus && root.status.muted
            onMoved: v => root.status.setVolume(v)
            onIconClicked: root.status.setMuted(!root.status.muted)
        }
        LevelSlider {
            visible: root.hasStatus && root.status.brightness >= 0
            Layout.fillWidth: true
            glyph: "sun"
            value: root.hasStatus ? root.status.brightness : 0
            onMoved: v => root.status.setBrightness(v)
        }

        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.divider }

        // Battery and power
        RowLayout {
            visible: root.confirm.length === 0
            Layout.fillWidth: true
            spacing: 8
            RowLayout {
                visible: root.hasStatus && root.status.battery >= 0
                spacing: 6
                Icon { name: "battery"; size: 20; color: Theme.text }
                Text {
                    text: root.hasStatus ? (root.status.battery + "%" + (root.status.charging ? qsTr(" · Charging") : "")) : ""
                    color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 12
                }
            }
            Item { Layout.fillWidth: true }
            RoundButton { glyph: "settings"; tip: qsTr("Settings"); onClicked: root.openCommand("systemsettings") }
            RoundButton { glyph: "lock"; tip: qsTr("Lock"); onClicked: root.status.lock() }
            RoundButton { glyph: "logOut"; tip: qsTr("Log out"); onClicked: root.confirm = "logOut" }
            RoundButton { glyph: "power"; tip: qsTr("Restart or shut down"); onClicked: root.confirm = "powerOff" }
        }
        ColumnLayout {
            visible: root.confirm.length > 0
            Layout.fillWidth: true
            spacing: 10
            Label {
                role: "body"
                text: root.confirm === "logOut" ? qsTr("Log out now? Unsaved work in open apps may be lost.")
                                                : qsTr("Restart or shut down? Unsaved work in open apps may be lost.")
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                PillButton { text: qsTr("Cancel"); onClicked: root.confirm = "" }
                Item { Layout.fillWidth: true }
                PillButton { visible: root.confirm === "logOut"; text: qsTr("Log out"); danger: true; onClicked: { root.confirm = ""; root.status.logOut() } }
                PillButton { visible: root.confirm === "powerOff"; text: qsTr("Sleep"); onClicked: { root.confirm = ""; root.status.suspend() } }
                PillButton { visible: root.confirm === "powerOff"; text: qsTr("Restart"); onClicked: { root.confirm = ""; root.status.restart() } }
                PillButton { visible: root.confirm === "powerOff"; text: qsTr("Shut down"); danger: true; onClicked: { root.confirm = ""; root.status.powerOff() } }
            }
        }
    }
}
