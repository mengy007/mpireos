import QtQuick
import QtQuick.Layouts
import MpireOS.Style

// The assistant (Meta+A, the sparkle in the top bar, or a question asked in
// universal search): a conversation with whichever AI the person chose in AI
// settings, which can be in the cloud, on this computer, or on their network.
// The AI itself is mpire-ai (src/ai.h); this only shows the conversation.
// Keys: Enter sends, Shift+Enter starts a new line, Esc closes.
Card {
    id: root
    property var ai: null                     // AiAssistant (src/ai.h), or a stand-in
    signal openSettings(string tab)
    signal close()

    readonly property bool ready: ai !== null && ai.ready
    readonly property var current: ai ? ai.current : ({})
    readonly property bool talking: ai !== null && (ai.messages.length > 0 || ai.busy)

    function reset() {
        if (ai) ai.refresh()
        input.forceActiveFocus()
    }
    function send() {
        const text = input.text.trim()
        if (!text || !ai) return
        if (!ready) { root.openSettings(""); return }
        ai.ask(text)
        input.text = ""
    }
    function whereLabel(where) {
        return where === "local" ? qsTr("On this computer") : where === "network" ? qsTr("On your network") : qsTr("Cloud")
    }

    padding: 0
    level: 4
    radius: 22

    // A small icon button for the header.
    component HeaderButton: Rectangle {
        property string glyph
        signal clicked()
        width: 30; height: 30; radius: 10
        color: hb.pressed ? Theme.selection : hb.containsMouse ? Theme.surfaceHover : "transparent"
        Icon { anchors.centerIn: parent; name: parent.glyph; size: 17; color: Theme.textSecondary }
        MouseArea { id: hb; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: parent.clicked() }
    }

    // The sparkle tile: MpireOS's AI mark.
    component AiMark: Rectangle {
        property real size: 34
        width: size; height: size; radius: size * 0.32
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0; color: Theme.accent }
            GradientStop { position: 1; color: Theme.accentDeep }
        }
        Icon { anchors.centerIn: parent; name: "sparkles"; size: parent.size * 0.56; color: "white" }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Header: who's answering, new chat, settings, close.
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 64
            Layout.leftMargin: 16
            Layout.rightMargin: 12
            spacing: 11
            AiMark { size: 34 }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                    text: qsTr("Assistant")
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                    font.letterSpacing: -0.2
                }
                Text {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: !root.ai || !root.ai.available ? qsTr("mpire-ai is not installed")
                        : !root.current.name ? qsTr("Not set up yet")
                        : root.current.name + (root.current.model ? "  ·  " + root.current.model : "")
                    color: Theme.textTertiary
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                }
            }
            HeaderButton { glyph: "plus"; visible: root.talking; onClicked: { root.ai.clear(); input.forceActiveFocus() } }
            HeaderButton { glyph: "settings"; onClicked: root.openSettings("") }
            HeaderButton { glyph: "x"; onClicked: root.close() }
        }
        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.divider }

        // Body
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // Not set up: the three ways to bring AI in.
            ColumnLayout {
                visible: !root.ready
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 22 }
                spacing: 0
                AiMark { size: 52; Layout.alignment: Qt.AlignHCenter }
                Text {
                    Layout.fillWidth: true
                    Layout.topMargin: 16
                    horizontalAlignment: Text.AlignHCenter
                    text: qsTr("Bring AI to your desktop")
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 19
                    font.weight: Font.DemiBold
                    font.letterSpacing: -0.4
                }
                Text {
                    Layout.fillWidth: true
                    Layout.topMargin: 6
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    text: root.current.name
                        ? qsTr("%1 needs its API key before it can answer.").arg(root.current.name)
                        : qsTr("Pick where your AI runs. You can change it any time.")
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: 13
                }
                Repeater {
                    model: [
                        { tab: "cloud", glyph: "cloud", title: qsTr("A cloud service"), text: qsTr("Anthropic, OpenAI, Gemini, and more") },
                        { tab: "local", glyph: "monitor", title: qsTr("This computer"), text: qsTr("Private and offline, with Ollama or LM Studio") },
                        { tab: "network", glyph: "network", title: qsTr("Your network"), text: qsTr("A model server on another computer at home or work") }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        Layout.topMargin: index === 0 ? 20 : 8
                        Layout.preferredHeight: 62
                        radius: 14
                        color: optArea.containsMouse ? Theme.surfaceHover : Theme.surfaceSunken
                        border.color: optArea.containsMouse ? Theme.accentSoft : Theme.border
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            spacing: 12
                            Rectangle {
                                Layout.preferredWidth: 34; Layout.preferredHeight: 34; radius: 10
                                color: Theme.accentSoft
                                Icon { anchors.centerIn: parent; name: modelData.glyph; size: 18; color: Theme.accentText }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                Text { text: modelData.title; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.DemiBold }
                                Text { Layout.fillWidth: true; text: modelData.text; elide: Text.ElideRight; color: Theme.textTertiary; font.family: Theme.fontFamily; font.pixelSize: 11 }
                            }
                            Icon { name: "chevronRight"; size: 16; color: Theme.textTertiary }
                        }
                        MouseArea { id: optArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.openSettings(modelData.tab) }
                    }
                }
            }

            // Ready, nothing asked yet: a greeting and a few ideas.
            ColumnLayout {
                visible: root.ready && !root.talking
                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 22 }
                spacing: 0
                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: qsTr("How can I help?")
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 24
                    font.weight: Font.DemiBold
                    font.letterSpacing: -0.6
                }
                Text {
                    Layout.fillWidth: true
                    Layout.topMargin: 6
                    horizontalAlignment: Text.AlignHCenter
                    text: root.whereLabel(root.current.where) + "  ·  " + (root.current.name || "")
                    color: Theme.textTertiary
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                }
                Flow {
                    Layout.fillWidth: true
                    Layout.topMargin: 22
                    spacing: 8
                    Repeater {
                        model: [qsTr("How do I install an app?"), qsTr("Explain what a Btrfs snapshot is"),
                                qsTr("Write a polite reply declining a meeting"), qsTr("Make a weekly meal plan")]
                        delegate: Rectangle {
                            required property string modelData
                            width: chipText.implicitWidth + 28
                            height: 34
                            radius: 17
                            color: chipArea.containsMouse ? Theme.accentSoft : Theme.surfaceSunken
                            border.color: chipArea.containsMouse ? Theme.accent : Theme.border
                            Text { id: chipText; anchors.centerIn: parent; text: modelData; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 12 }
                            MouseArea { id: chipArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.ai.ask(modelData) }
                        }
                    }
                }
            }

            // The conversation
            ListView {
                id: list
                visible: root.ready && root.talking
                anchors.fill: parent
                anchors.margins: 16
                clip: true
                spacing: 14
                model: root.ai ? root.ai.messages : []
                boundsBehavior: Flickable.StopAtBounds
                onCountChanged: Qt.callLater(positionViewAtEnd)
                Connections {
                    target: root.ai
                    function onPartialChanged() { Qt.callLater(list.positionViewAtEnd) }
                }
                delegate: Item {
                    id: msg
                    required property var modelData
                    readonly property bool mine: modelData.role === "user"
                    width: ListView.view.width
                    height: mine ? bubble.height : reply.implicitHeight
                    Rectangle {
                        id: bubble
                        visible: msg.mine
                        anchors.right: parent.right
                        width: Math.min(msg.width * 0.82, userText.implicitWidth + 28)
                        height: userText.implicitHeight + 18
                        radius: 16
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: Theme.accent }
                            GradientStop { position: 1; color: Qt.darker(Theme.accent, 1.12) }
                        }
                        Text {
                            id: userText
                            anchors.fill: parent
                            anchors.margins: 9
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            text: msg.mine ? msg.modelData.text : ""
                            wrapMode: Text.Wrap
                            color: "white"
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            lineHeight: 1.2
                        }
                    }
                    Reply {
                        id: reply
                        visible: !msg.mine
                        width: parent.width
                        text: msg.mine ? "" : msg.modelData.text
                        error: msg.modelData.error === true
                        provider: msg.modelData.provider || ""
                        onCopy: root.ai && msg.modelData.text ? shellApi.copy(msg.modelData.text) : undefined
                        onFix: root.openSettings("")
                    }
                }
                // The reply as it streams in.
                footer: Item {
                    width: ListView.view.width
                    height: root.ai && root.ai.busy ? live.implicitHeight + 14 : 0
                    visible: height > 0
                    Reply {
                        id: live
                        y: 14
                        width: parent.width
                        text: root.ai ? root.ai.partial : ""
                        streaming: true
                    }
                }
            }
        }

        // The question field
        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.divider }
        Rectangle {
            Layout.fillWidth: true
            Layout.margins: 12
            Layout.preferredHeight: Math.min(132, input.contentHeight + 26)
            radius: 16
            color: Theme.surfaceSunken
            border.width: input.activeFocus ? 1.5 : 1
            border.color: input.activeFocus ? Theme.accent : Theme.border
            Flickable {
                id: flick
                anchors { left: parent.left; right: sendButton.left; top: parent.top; bottom: parent.bottom; leftMargin: 14; rightMargin: 8; topMargin: 13; bottomMargin: 13 }
                contentHeight: input.contentHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                TextEdit {
                    id: input
                    width: flick.width
                    focus: true
                    wrapMode: TextEdit.Wrap
                    color: Theme.text
                    selectionColor: Theme.accentSoft
                    selectedTextColor: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    onCursorRectangleChanged: {
                        if (cursorRectangle.y + cursorRectangle.height > flick.contentY + flick.height)
                            flick.contentY = cursorRectangle.y + cursorRectangle.height - flick.height
                    }
                    Keys.onPressed: event => {
                        if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && !(event.modifiers & Qt.ShiftModifier)) {
                            root.send()
                            event.accepted = true
                        } else if (event.key === Qt.Key_Escape) {
                            root.close()
                            event.accepted = true
                        }
                    }
                    Text {
                        visible: input.text.length === 0
                        text: root.ready ? qsTr("Ask anything…") : qsTr("Set up AI to start asking")
                        color: Theme.textTertiary
                        font: input.font
                    }
                }
            }
            // Send, or stop while a reply streams in.
            Rectangle {
                id: sendButton
                readonly property bool stopping: root.ai !== null && root.ai.busy
                readonly property bool live: stopping || input.text.trim().length > 0
                anchors { right: parent.right; bottom: parent.bottom; margins: 7 }
                width: 32; height: 32; radius: 16
                color: live ? (sendArea.pressed ? Theme.accentPressed : Theme.accent) : Theme.controlOff
                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                Icon { anchors.centerIn: parent; name: sendButton.stopping ? "stop" : "arrowUp"; size: 16; weight: 2.2; color: "white" }
                MouseArea {
                    id: sendArea
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: sendButton.stopping ? root.ai.stop() : root.send()
                }
            }
        }
        Text {
            Layout.fillWidth: true
            Layout.bottomMargin: 10
            Layout.topMargin: -4
            horizontalAlignment: Text.AlignHCenter
            text: qsTr("AI can make mistakes. Check anything important.")
            color: Theme.textTertiary
            font.family: Theme.fontFamily
            font.pixelSize: 10
        }
    }
}
