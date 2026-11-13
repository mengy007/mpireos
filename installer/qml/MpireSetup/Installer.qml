pragma Singleton
import QtQuick

// Everything the pages know about the machine and the install: detected defaults,
// the plan the user builds up, and progress.
//
// mpire-setup sets `system` (src/systembridge.cpp) when it starts. On the live ISO
// that bridge lists the real disks and runs the privileged backend, mpire-install.
// Without it (demo mode, tools/preview.py) this uses sample data and a simulated
// install, and never touches a disk.
QtObject {
    id: root

    property QtObject system: null
    readonly property bool real: system !== null && system.live

    // ---- Detected system ----
    readonly property var sampleDisks: [
        { id: "/dev/nvme0n1", name: "Samsung SSD 980", size: "512 GB · nvme0n1", otherOs: "Windows", hasData: true }
    ]
    readonly property var disks: real ? system.disks : sampleDisks
    // Each language brings a sensible keyboard. `keyboard` is an XKB layout code.
    readonly property var languages: [
        { code: "en_US", name: "English (United States)", keyboard: "us" },
        { code: "es_US", name: "Español (Estados Unidos)", keyboard: "latam" },
        { code: "fr_CA", name: "Français (Canada)", keyboard: "ca" },
        { code: "zh_CN", name: "中文 (简体)", keyboard: "us" },
        { code: "vi_VN", name: "Tiếng Việt", keyboard: "us" }
    ]
    readonly property var keyboards: [
        { code: "us", name: "English (US)" },
        { code: "gb", name: "English (UK)" },
        { code: "latam", name: "Spanish (Latin American)" },
        { code: "ca", name: "French (Canada)" },
        { code: "de", name: "German" }
    ]
    property string keyboardOverride: ""          // set when the user picks one on Review
    readonly property string keyboardCode: keyboardOverride || languages[languageIndex].keyboard
    readonly property string detectedKeyboard: keyboardName(keyboardCode)
    property string detectedTimezone: real ? system.timezone : "America/Los_Angeles"

    function keyboardName(code) {
        for (const k of keyboards) if (k.code === code) return k.name
        return code
    }
    function keyboardCodeFor(name) {
        for (const k of keyboards) if (k.name === name) return k.code
        return ""
    }

    // ---- The install plan the pages build up ----
    property int languageIndex: 0
    property int diskIndex: 0
    property string diskMode: "erase"        // "erase" or "alongside"
    readonly property bool alongsideSupported: false   // mpire-install only erases so far
    property bool encrypt: false
    property string fullName: ""
    property string userName: ""
    property string password: ""

    readonly property var noDisk: ({ id: "", name: qsTr("No disk found"), size: "", otherOs: "", hasData: false })
    readonly property var disk: disks.length > 0 ? disks[Math.min(diskIndex, disks.length - 1)] : noDisk
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
            keyboard: keyboardCode,
            timezone: detectedTimezone,
            disk: disk.id,
            mode: diskMode,
            encrypt: encrypt,
            user: { fullName: fullName, name: userName, password: password },
            hostname: computerName
        }
    }

    // ---- Progress ----
    property real progress: 0
    property string status: ""
    property bool running: false
    property bool finished: false
    property bool failed: false
    property string errorMessage: ""
    readonly property string logPath: real ? system.logPath : "/var/log/mpire-install.log"
    property int stepIndex: 0
    property int stepTotal: 1

    readonly property var sampleSteps: [
        "Preparing your disk",
        "Copying MpireOS",
        "Setting up your account",
        "Installing the boot loader",
        "Setting up snapshots",
        "Finishing up"
    ]

    function start() {
        progress = 0
        status = qsTr("Getting ready")
        finished = false
        failed = false
        errorMessage = ""
        running = true
        if (!real) {
            const p = plan()
            p.user.password = "(hidden)"
            console.log("Install plan (demo, nothing is changed):", JSON.stringify(p))
            ticker.start()
            return
        }
        if (!system.start(plan()))
            fail(qsTr("The installer could not start."))
    }

    function restart() {
        if (real) system.reboot()
        else Qt.quit()
    }

    function fail(message) {
        running = false
        failed = true
        errorMessage = message
    }

    property Connections backend: Connections {
        target: root.system
        function onEvent(e) {
            switch (e.event) {
            case "step":
                root.stepIndex = e.index
                root.stepTotal = Math.max(1, e.total)
                root.status = qsTr(e.title)
                root.progress = e.index / root.stepTotal
                break
            case "substep":
                root.progress = (root.stepIndex + Math.min(1, e.value)) / root.stepTotal
                break
            case "progress":
                root.progress = e.value
                break
            case "done":
                root.progress = 1
                root.running = false
                root.finished = true
                break
            case "error":
                root.fail(e.message)
                break
            }
        }
        function onFinished(code, lastOutput) {
            if (code !== 0 && !root.failed)
                root.fail(lastOutput || qsTr("The installer stopped unexpectedly (code %1).").arg(code))
        }
    }

    property Timer ticker: Timer {
        interval: 120
        repeat: true
        onTriggered: {
            root.progress = Math.min(1, root.progress + 0.006)
            root.status = root.sampleSteps[Math.min(root.sampleSteps.length - 1, Math.floor(root.progress * root.sampleSteps.length))]
            if (root.progress >= 1) {
                stop()
                root.running = false
                root.finished = true
            }
        }
    }
}
