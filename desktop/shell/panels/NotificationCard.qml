import QtQuick
import QtQuick.Layouts
import MpireOS.Style

// One notification: app, time, title, text, and its buttons. Used for popups
// (floating card) and in the notification list (flat row).
Card {
    id: root
    property var item: ({})          // NotificationServer entry (src/notifications.h)
    property bool popup: true
    property date now: new Date()
    signal dismissed()
    signal activated(string actionKey)
    signal linkOpened(string url)

    readonly property var buttons: (item.actions || []).filter(a => a.key !== "default")
    readonly property bool hasDefault: (item.actions || []).some(a => a.key === "default")

    function age(t) {
        if (!t) return ""
        const mins = Math.floor((now - t) / 60000)
        if (mins < 1) return qsTr("now")
        if (mins < 60) return qsTr("%1m").arg(mins)
        if (mins < 24 * 60) return qsTr("%1h").arg(Math.floor(mins / 60))
        return Qt.formatDate(t, "MMM d")
    }

    width: 360
    implicitHeight: body.implicitHeight + 2 * padding
    padding: 16
    level: popup ? 3 : 0
    color: popup ? Theme.surface : (hover.hovered ? Theme.surfaceHover : Theme.surfaceSunken)
    radius: popup ? 18 : 14

    HoverHandler { id: hover }
    TapHandler { onTapped: root.activated(root.hasDefault ? "default" : "") }

    ColumnLayout {
        id: body
        width: parent.width
        spacing: 4
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            ResultIcon { icon: root.item.appIcon || ""; glyph: "bell"; size: 18 }
            Text {
                Layout.fillWidth: true
                text: root.item.appName || ""
                elide: Text.ElideRight
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: 11
                font.weight: Font.DemiBold
            }
            Text {
                visible: !hover.hovered
                text: root.age(root.item.time)
                color: Theme.textTertiary
                font.family: Theme.fontFamily
                font.pixelSize: 11
            }
            Rectangle {
                visible: hover.hovered
                Layout.preferredWidth: 20; Layout.preferredHeight: 20; radius: 10
                color: closeArea.containsMouse ? Theme.divider : "transparent"
                Icon { anchors.centerIn: parent; name: "x"; size: 14 }
                MouseArea { id: closeArea; anchors.fill: parent; hoverEnabled: true; onClicked: root.dismissed() }
            }
        }
        Text {
            Layout.fillWidth: true
            Layout.topMargin: 2
            text: root.item.summary || ""
            elide: Text.ElideRight
            color: Theme.text
            font.family: Theme.fontFamily
            font.pixelSize: 14
            font.weight: Font.DemiBold
        }
        Text {
            Layout.fillWidth: true
            visible: text.length > 0
            text: root.item.body || ""
            textFormat: Text.StyledText
            wrapMode: Text.Wrap
            maximumLineCount: root.popup ? 3 : 4
            elide: Text.ElideRight
            color: Theme.textSecondary
            linkColor: Theme.accentText
            font.family: Theme.fontFamily
            font.pixelSize: 13
            lineHeight: 1.15
            onLinkActivated: link => root.linkOpened(link)
        }
        Flow {
            Layout.fillWidth: true
            Layout.topMargin: 8
            visible: root.buttons.length > 0
            spacing: 8
            Repeater {
                model: root.buttons
                PillButton {
                    required property var modelData
                    required property int index
                    text: modelData.label
                    accent: index === 0
                    onClicked: root.activated(modelData.key)
                }
            }
        }
    }
}
