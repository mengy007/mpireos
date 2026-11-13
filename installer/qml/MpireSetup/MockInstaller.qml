pragma Singleton
import QtQuick

// Stand-in for the privileged install backend. It exposes the same shape the
// real D-Bus backend will: detected defaults, the install plan, and progress.
// Swapping it out must not require changes to the pages.
QtObject {
    id: root

    // ---- Detected system (the real backend fills these in) ----
    readonly property var disks: [
        { id: "nvme0n1", name: "Samsung SSD 980", size: "512 GB", otherOs: "Windows 11" }
    ]
    readonly property var languages: [
        { code: "en_US", name: "English (United States)" },
        { code: "es_US", name: "Español (Estados Unidos)" },
        { code: "fr_CA", name: "Français (Canada)" },
        { code: "zh_CN", name: "中文 (简体)" },
        { code: "vi_VN", name: "Tiếng Việt" }
    ]
    property string detectedKeyboard: "English (US)"
    property string detectedTimezone: "America/Los_Angeles"

    // ---- The install plan the pages build up ----
    property int languageIndex: 0
    property int diskIndex: 0
    property string diskMode: "erase"        // "erase" or "alongside"
    property bool encrypt: false
    property string fullName: ""
    property string userName: ""
    property string password: ""

    readonly property var disk: disks[diskIndex]
    readonly property string computerName: {
        const base = userName.length > 0 ? userName : "mpireos"
        return base + "-computer"
    }

    function suggestUserName(name) {
        const first = name.trim().split(/\s+/)[0] || ""
        return first.toLowerCase().normalize("NFD").replace(/[^a-z0-9]/g, "").slice(0, 32)
    }

    function plan() {
        return {
            language: languages[languageIndex].code,
            keyboard: detectedKeyboard,
            timezone: detectedTimezone,
            disk: disk.id,
            mode: diskMode,
            encrypt: encrypt,
            user: { fullName: fullName, name: userName },
            hostname: computerName
        }
    }

    // ---- Progress ----
    property real progress: 0
    property string status: ""
    property bool running: false
    property bool finished: false

    readonly property var steps: [
        "Preparing your disk",
        "Copying MpireOS",
        "Setting up your account",
        "Installing the boot loader",
        "Setting up snapshots",
        "Finishing up"
    ]

    function start() {
        console.log("Install plan:", JSON.stringify(plan()))
        progress = 0
        finished = false
        running = true
        ticker.start()
    }

    property Timer ticker: Timer {
        interval: 120
        repeat: true
        onTriggered: {
            root.progress = Math.min(1, root.progress + 0.006)
            root.status = root.steps[Math.min(root.steps.length - 1, Math.floor(root.progress * root.steps.length))]
            if (root.progress >= 1) {
                stop()
                root.running = false
                root.finished = true
            }
        }
    }
}
