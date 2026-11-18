import QtQuick
import QtQuick.Layouts
import MpireOS.Style

// AI settings: which AI answers, and adding one from the cloud (with an API
// key), from this computer, or from another computer on the network. Opened
// from the assistant, from search ("AI settings"), or `mpire-shell --show ai-settings`.
// Keys go straight to mpire-ai, which encrypts them on this computer.
Card {
    id: root
    property var ai: null                     // AiAssistant (src/ai.h), or a stand-in
    property string tab: "cloud"              // cloud | local | network
    property string preset: "anthropic"
    property real maxHeight: 760
    signal done()

    function reset(toTab) {
        if (ai) { ai.refresh(); ai.clearNotice() }
        // Open where the AI in use lives, unless asked for a particular place.
        tab = toTab || (ai && ai.current.where ? ai.current.where : "cloud")
        keyField.text = ""
        if (ai && tab === "local" && !ai.discovering) ai.discover(false)
    }
    function whereLabel(where) {
        return where === "local" ? qsTr("This computer") : where === "network" ? qsTr("Your network") : qsTr("Cloud")
    }
    function glyphFor(where) {
        return where === "local" ? "monitor" : where === "network" ? "network" : "cloud"
    }
    readonly property var presetInfo: {
        const list = ai ? ai.presets : []
        for (let i = 0; i < list.length; i++) if (list[i].id === preset) return list[i]
        return {}
    }

    onTabChanged: if (ai && tab === "local" && ai.servers.length === 0 && !ai.discovering) ai.discover(false)

    padding: 0
    level: 4
    radius: 22
    implicitHeight: Math.min(maxHeight, body.implicitHeight + 64 + 1)

    component SectionTitle: Text {
        color: Theme.textTertiary
        font.family: Theme.fontFamily
        font.pixelSize: 11
        font.weight: Font.DemiBold
        font.letterSpacing: 0.6
        font.capitalization: Font.AllUppercase
    }
    component GlyphTile: Rectangle {
        property string glyph
        property bool strong: false
        implicitWidth: 36; implicitHeight: 36; radius: 11
        color: strong ? Theme.accent : Theme.accentSoft
        Icon { anchors.centerIn: parent; name: parent.glyph; size: 18; color: parent.strong ? "white" : Theme.accentText }
    }
    // A found model server, with a button to use it.
    component ServerRow: Rectangle {
        id: srow
        required property var modelData
        Layout.fillWidth: true
        Layout.preferredHeight: 58
        radius: 14
        color: Theme.surfaceSunken
        border.color: Theme.border
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 12
            GlyphTile { glyph: srow.modelData.where === "local" ? "monitor" : "network" }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text { Layout.fillWidth: true; elide: Text.ElideRight; text: srow.modelData.label; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.DemiBold }
                Text {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: srow.modelData.url + "  ·  " + (srow.modelData.models.length === 1 ? qsTr("1 model")
                          : qsTr("%1 models").arg(srow.modelData.models.length))
                    color: Theme.textTertiary; font.family: Theme.fontFamily; font.pixelSize: 11
                }
            }
            PillButton {
                text: srow.modelData.added ? qsTr("Added") : qsTr("Use")
                accent: !srow.modelData.added
                onClicked: if (!srow.modelData.added) root.ai.addServer(srow.modelData)
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Header
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 64
            Layout.leftMargin: 20
            Layout.rightMargin: 16
            spacing: 12
            Rectangle {
                Layout.preferredWidth: 36; Layout.preferredHeight: 36; radius: 12
                gradient: Gradient {
                    GradientStop { position: 0; color: Theme.accent }
                    GradientStop { position: 1; color: Theme.accentDeep }
                }
                Icon { anchors.centerIn: parent; name: "sparkles"; size: 20; color: "white" }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text { text: qsTr("AI"); color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 17; font.weight: Font.DemiBold; font.letterSpacing: -0.3 }
                Text {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: qsTr("Choose which AI answers when you ask MpireOS.")
                    color: Theme.textTertiary; font.family: Theme.fontFamily; font.pixelSize: 12
                }
            }
            PillButton { text: qsTr("Done"); accent: true; onClicked: root.done() }
        }
        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.divider }

        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: body.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: body
                width: parent.width
                spacing: 0

                // ---- Your AI ----
                SectionTitle { Layout.leftMargin: 22; Layout.topMargin: 18; text: qsTr("Your AI") }
                Text {
                    visible: root.ai && root.ai.providers.length === 0
                    Layout.leftMargin: 22
                    Layout.topMargin: 10
                    text: qsTr("Nothing yet. Add one below.")
                    color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: 13
                }
                Repeater {
                    model: root.ai ? root.ai.providers : []
                    delegate: Rectangle {
                        id: prow
                        required property var modelData
                        readonly property bool chosen: modelData.isDefault === true
                        readonly property bool picking: modelPicker.forId === modelData.id
                        Layout.fillWidth: true
                        Layout.leftMargin: 16
                        Layout.rightMargin: 16
                        Layout.topMargin: 8
                        Layout.preferredHeight: 62 + (picking ? modelPicker.implicitHeight + 8 : 0)
                        radius: 14
                        color: chosen ? Theme.selection : Theme.surface
                        border.color: chosen ? Theme.accent : Theme.border
                        border.width: chosen ? 1.5 : 1
                        RowLayout {
                            x: 12; y: 0
                            width: parent.width - 24
                            height: 62
                            spacing: 12
                            GlyphTile { glyph: root.glyphFor(prow.modelData.where); strong: prow.chosen }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Text { Layout.fillWidth: true; elide: Text.ElideRight; text: prow.modelData.name; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.DemiBold }
                                RowLayout {
                                    spacing: 6
                                    // The model: click to choose another.
                                    Rectangle {
                                        Layout.preferredHeight: 20
                                        Layout.preferredWidth: modelLabel.implicitWidth + 22
                                        radius: 6
                                        color: modelArea.containsMouse ? Theme.surfaceHover : Theme.surfaceSunken
                                        Row {
                                            anchors.centerIn: parent
                                            spacing: 2
                                            Text { id: modelLabel; text: prow.modelData.model || qsTr("Choose model"); color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: 11 }
                                            Icon { name: "chevronDown"; size: 11; anchors.verticalCenter: parent.verticalCenter }
                                        }
                                        MouseArea {
                                            id: modelArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                modelPicker.forId = prow.picking ? "" : prow.modelData.id
                                                if (modelPicker.forId) root.ai.loadModels(prow.modelData.id)
                                            }
                                        }
                                    }
                                    Text {
                                        text: root.whereLabel(prow.modelData.where)
                                              + (prow.modelData.needsKey ? "  ·  " + (prow.modelData.hasKey ? prow.modelData.keyLabel : qsTr("Needs an API key")) : "")
                                        color: prow.modelData.needsKey && !prow.modelData.hasKey ? Theme.danger : Theme.textTertiary
                                        font.family: Theme.fontFamily; font.pixelSize: 11
                                    }
                                }
                            }
                            Text {
                                visible: prow.chosen
                                text: qsTr("Answering")
                                color: Theme.accentText; font.family: Theme.fontFamily; font.pixelSize: 11; font.weight: Font.DemiBold
                            }
                            PillButton { visible: !prow.chosen; text: qsTr("Use"); onClicked: root.ai.setDefault(prow.modelData.id) }
                            Rectangle {
                                width: 28; height: 28; radius: 9
                                color: delArea.containsMouse ? Theme.roseTint : "transparent"
                                Icon { anchors.centerIn: parent; name: "trash"; size: 15; color: delArea.containsMouse ? Theme.danger : Theme.textTertiary }
                                MouseArea { id: delArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.ai.remove(prow.modelData.id) }
                            }
                        }
                        // Model list, under the row.
                        Flow {
                            visible: prow.picking
                            x: 60; y: 62
                            width: parent.width - 72
                            spacing: 6
                            Repeater {
                                model: prow.picking && root.ai ? (root.ai.models[prow.modelData.id] || []) : []
                                delegate: Rectangle {
                                    required property string modelData
                                    width: mText.implicitWidth + 20; height: 26; radius: 8
                                    color: modelData === prow.modelData.model ? Theme.accent : mArea.containsMouse ? Theme.surfaceHover : Theme.surfaceSunken
                                    Text { id: mText; anchors.centerIn: parent; text: modelData; font.family: Theme.fontFamily; font.pixelSize: 11
                                           color: modelData === prow.modelData.model ? "white" : Theme.text }
                                    MouseArea { id: mArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                onClicked: { root.ai.setModel(prow.modelData.id, modelData); modelPicker.forId = "" } }
                                }
                            }
                        }
                    }
                }
                QtObject { id: modelPicker; property string forId: ""; property real implicitHeight: 64 }

                // ---- Add AI ----
                SectionTitle { Layout.leftMargin: 22; Layout.topMargin: 24; text: qsTr("Add AI") }
                // Where it runs
                Tabs {
                    Layout.fillWidth: true
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    Layout.topMargin: 6
                    model: [{ id: "cloud", glyph: "cloud", label: qsTr("Cloud") },
                            { id: "local", glyph: "monitor", label: qsTr("This computer") },
                            { id: "network", glyph: "network", label: qsTr("Your network") }]
                    current: root.tab
                    onPicked: id => { root.tab = id; root.ai.clearNotice() }
                }

                // Cloud: pick a service, paste a key.
                ColumnLayout {
                    visible: root.tab === "cloud"
                    Layout.fillWidth: true
                    Layout.leftMargin: 22
                    Layout.rightMargin: 22
                    Layout.topMargin: 14
                    spacing: 12
                    Flow {
                        Layout.fillWidth: true
                        spacing: 8
                        Repeater {
                            model: root.ai ? root.ai.presets : []
                            delegate: Rectangle {
                                required property var modelData
                                readonly property bool on: root.preset === modelData.id
                                width: Math.floor((parent.width - 4 * 8) / 5); height: 54; radius: 12
                                color: on ? Theme.selection : presetArea.containsMouse ? Theme.surfaceHover : Theme.surface
                                border.color: on ? Theme.accent : Theme.border
                                border.width: on ? 1.5 : 1
                                Column {
                                    anchors.left: parent.left; anchors.leftMargin: 11
                                    anchors.right: parent.right; anchors.rightMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2
                                    Text { text: modelData.name; width: parent.width; elide: Text.ElideRight; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.DemiBold }
                                    Text { text: modelData.blurb; width: parent.width; elide: Text.ElideRight; color: Theme.textTertiary; font.family: Theme.fontFamily; font.pixelSize: 10 }
                                }
                                MouseArea { id: presetArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { root.preset = modelData.id; root.ai.clearNotice() } }
                            }
                        }
                    }
                    Field {
                        id: urlField
                        visible: root.preset === "custom"
                        Layout.fillWidth: true
                        glyph: "globe"
                        placeholder: qsTr("API address, like https://api.example.com/v1")
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Field {
                            id: keyField
                            Layout.fillWidth: true
                            glyph: "key"
                            secret: true
                            placeholder: qsTr("Paste your %1 API key").arg(root.presetInfo.name || "")
                            onAccepted: connect.clicked()
                        }
                        PillButton {
                            id: connect
                            Layout.preferredHeight: 38
                            accent: true
                            text: root.ai && root.ai.working ? qsTr("Connecting…") : qsTr("Connect")
                            onClicked: {
                                if (keyField.text.trim().length === 0) { keyField.focusField(); return }
                                root.ai.addPreset(root.preset, keyField.text, root.preset === "custom" ? urlField.text : "")
                                keyField.text = ""
                            }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Icon { name: "shield"; size: 14; color: Theme.success }
                        Text {
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                            text: qsTr("Your key is encrypted on this computer and only sent to %1.").arg(root.presetInfo.name || qsTr("that service"))
                            color: Theme.textTertiary; font.family: Theme.fontFamily; font.pixelSize: 11
                        }
                        Text {
                            visible: (root.presetInfo.keyUrl || "").length > 0
                            text: qsTr("Get a key")
                            color: Theme.accentText; font.family: Theme.fontFamily; font.pixelSize: 11; font.weight: Font.DemiBold
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: shellApi.openUrl(root.presetInfo.keyUrl) }
                        }
                    }
                }

                // This computer: servers already running, or set up Ollama.
                ColumnLayout {
                    visible: root.tab === "local"
                    Layout.fillWidth: true
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    Layout.topMargin: 14
                    spacing: 8
                    Repeater {
                        model: root.ai ? root.ai.servers.filter(s => s.where === "local") : []
                        delegate: ServerRow {}
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 84
                        radius: 14
                        color: Theme.lavenderTint
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 12
                            GlyphTile { glyph: "shield" }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Text { text: qsTr("Run AI privately on this computer"); color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.DemiBold }
                                Text {
                                    Layout.fillWidth: true
                                    wrapMode: Text.Wrap
                                    text: qsTr("Installs Ollama and a model sized for your memory. Nothing you ask leaves the computer.")
                                    color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: 11
                                }
                            }
                            PillButton { text: qsTr("Set Up"); accent: true; onClicked: root.ai.setupLocal() }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 6
                        Text {
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                            text: root.ai && root.ai.discovering ? qsTr("Looking for Ollama, LM Studio, llama.cpp, and vLLM…")
                                : qsTr("Ollama, LM Studio, llama.cpp, and vLLM are found when they're running.")
                            color: Theme.textTertiary; font.family: Theme.fontFamily; font.pixelSize: 11
                        }
                        PillButton { text: qsTr("Look Again"); onClicked: root.ai.discover(false) }
                    }
                }

                // Your network: search the LAN, or type an address.
                ColumnLayout {
                    visible: root.tab === "network"
                    Layout.fillWidth: true
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    Layout.topMargin: 14
                    spacing: 8
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 6
                        spacing: 10
                        Text {
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                            text: root.ai && root.ai.discovering ? qsTr("Looking on your network…")
                                : root.ai && root.ai.searchedNetwork && root.ai.servers.filter(s => s.where === "network").length === 0
                                ? qsTr("Nothing found. The server may only listen on its own computer (for Ollama, set OLLAMA_HOST=0.0.0.0).")
                                : qsTr("Use a model server on another computer, like a desktop with a big GPU.")
                            color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: 12
                        }
                        PillButton { accent: true; text: qsTr("Find on My Network"); onClicked: root.ai.discover(true) }
                    }
                    Repeater {
                        model: root.ai ? root.ai.servers.filter(s => s.where === "network") : []
                        delegate: ServerRow {}
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Field {
                            id: addressField
                            Layout.fillWidth: true
                            glyph: "network"
                            placeholder: qsTr("Or type an address, like 192.168.1.20 or studio.local:1234")
                            onAccepted: addAddress.clicked()
                        }
                        PillButton {
                            id: addAddress
                            Layout.preferredHeight: 38
                            text: qsTr("Add")
                            onClicked: { root.ai.addAddress(addressField.text); addressField.text = "" }
                        }
                    }
                }

                // What happened
                RowLayout {
                    visible: root.ai !== null && (root.ai.notice.length > 0)
                    Layout.fillWidth: true
                    Layout.leftMargin: 22
                    Layout.rightMargin: 22
                    Layout.topMargin: 12
                    spacing: 6
                    Icon { name: root.ai && root.ai.noticeError ? "x" : "check"; size: 14; color: root.ai && root.ai.noticeError ? Theme.danger : Theme.success }
                    Text {
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        text: root.ai ? root.ai.notice : ""
                        color: root.ai && root.ai.noticeError ? Theme.danger : Theme.textSecondary
                        font.family: Theme.fontFamily; font.pixelSize: 12
                    }
                }

                // ---- For apps ----
                Rectangle { Layout.fillWidth: true; Layout.topMargin: 22; Layout.preferredHeight: 1; color: Theme.divider }
                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 22
                    Layout.rightMargin: 22
                    Layout.topMargin: 14
                    Layout.bottomMargin: 18
                    spacing: 12
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text { text: qsTr("Let apps use AI"); color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.DemiBold }
                        Text {
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                            text: qsTr("Apps and coding tools on this computer can use your AI through an OpenAI-compatible address, http://127.0.0.1:11500/v1, without seeing your keys.")
                            color: Theme.textTertiary; font.family: Theme.fontFamily; font.pixelSize: 11
                        }
                    }
                    Toggle { checked: root.ai !== null && root.ai.gateway; onToggled: on => root.ai.setGateway(on) }
                }
            }
        }
    }
}
