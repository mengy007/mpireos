#!/usr/bin/env python3
"""Render Mpire Desktop previews without a compositor.

    pip install PySide6-Essentials
    python3 desktop/tools/preview.py desktop  [--shot out.png]
    python3 desktop/tools/preview.py greeter  [--shot out.png] [--fake-sddm]
    python3 desktop/tools/preview.py shell-background|shell-topbar|shell-dock [--shot out.png]
    python3 desktop/tools/preview.py panels --panel launcher|quick-settings|notifications|popups
                                            [--query "text"] [--shot out.png]

--fake-sddm gives the login screen stand-ins for SDDM's sddm, userModel, and
sessionModel objects, so the code path used under SDDM is exercised.
"""
import argparse
import sys
from pathlib import Path

from PySide6.QtCore import QByteArray, QDate, QDateTime, QObject, Property, QRectF, QTime, QTimer, QUrl, Qt, Signal, Slot
from PySide6.QtGui import QColor, QFont, QGuiApplication, QPainter, QPixmap, QStandardItem, QStandardItemModel
from PySide6.QtQuick import QQuickImageProvider, QQuickView

ROOT = Path(__file__).resolve().parent.parent
SCENES = {
    "desktop": ROOT / "shell" / "Desktop.qml",
    "greeter": ROOT / "greeter" / "Main.qml",
    "shell-background": ROOT / "shell" / "surfaces" / "BackgroundSurface.qml",
    "shell-topbar": ROOT / "shell" / "surfaces" / "TopBarSurface.qml",
    "shell-dock": ROOT / "shell" / "surfaces" / "DockSurface.qml",
    "panels": ROOT / "tools" / "PanelPreview.qml",
}

SAMPLE_APPS = [
    ("org.kde.dolphin.desktop", "Dolphin", "File Manager", "system-file-manager"),
    ("firefox.desktop", "Firefox", "Web Browser", "firefox"),
    ("org.kde.kate.desktop", "Kate", "Text Editor", "kate"),
    ("org.kde.konsole.desktop", "Konsole", "Terminal", "utilities-terminal"),
    ("org.kde.gwenview.desktop", "Gwenview", "Image Viewer", "gwenview"),
    ("systemsettings.desktop", "System Settings", "Settings", "preferences-system"),
    ("org.kde.discover.desktop", "Discover", "Software Center", "plasmadiscover"),
    ("org.kde.okular.desktop", "Okular", "Document Viewer", "okular"),
    ("org.kde.ark.desktop", "Ark", "Archiving Tool", "ark"),
    ("org.kde.spectacle.desktop", "Spectacle", "Screenshot Capture Utility", "spectacle"),
    ("org.kde.kcalc.desktop", "KCalc", "Scientific Calculator", "accessories-calculator"),
    ("org.kde.plasma-systemmonitor.desktop", "System Monitor", "System Monitor", "utilities-system-monitor"),
    ("mpire-setup.desktop", "Install MpireOS", "Installer", "system-software-install"),
    ("org.kde.elisa.desktop", "Elisa", "Music Player", "elisa"),
    ("vlc.desktop", "VLC media player", "Media Player", "vlc"),
    ("org.kde.kwrite.desktop", "KWrite", "Text Editor", "kwrite"),
]
ICON_COLORS = ["#83A9D8", "#8CCBBB", "#F2CF77", "#0B3A44", "#B6A1E4", "#B9C2D0", "#269CA1", "#E6B072", "#EEAEBF"]


class LetterIcons(QQuickImageProvider):
    """Stands in for mpire-shell's icon theme provider: a pastel tile with a letter."""

    def __init__(self):
        super().__init__(QQuickImageProvider.Pixmap)

    def requestPixmap(self, id, size, requested):
        n = max(requested.width(), 64) if requested.isValid() else 64
        pm = QPixmap(n, n)
        pm.fill(Qt.transparent)
        p = QPainter(pm)
        p.setRenderHint(QPainter.Antialiasing)
        name = QUrl.fromPercentEncoding(id.encode())
        p.setBrush(QColor(ICON_COLORS[sum(map(ord, name)) % len(ICON_COLORS)]))
        p.setPen(Qt.NoPen)
        p.drawRoundedRect(QRectF(0, 0, n, n), n * 0.28, n * 0.28)
        f = QFont("Inter")
        f.setPixelSize(int(n * 0.46))
        f.setWeight(QFont.DemiBold)
        p.setFont(f)
        p.setPen(QColor("white"))
        p.drawText(QRectF(0, 0, n, n), Qt.AlignCenter, name.split("-")[-1][:1].upper())
        p.end()
        return pm


class FakeAppIndex(QObject):
    appsChanged = Signal()

    @Property("QVariantList", notify=appsChanged)
    def apps(self):
        return [dict(id=i, name=n, genericName=g, comment="", keywords="", icon=ic, exec=i, terminal=False)
                for i, n, g, ic in sorted(SAMPLE_APPS, key=lambda a: a[1].lower())]

    @Slot(str, result=bool)
    def launch(self, id):
        print("launch app:", id)
        return True


class FakeNotifications(QObject):
    """Stands in for NotificationServer (src/notifications.h)."""
    popupsChanged = Signal()
    historyChanged = Signal()
    doNotDisturbChanged = Signal()

    def __init__(self, now):
        super().__init__()
        self._dnd = False
        mins = lambda m: now.addSecs(-60 * m)
        self._items = [
            dict(id=3, appName="Calendar", appIcon="calendar", summary="Design review in 10 minutes",
                 body="Mpire Desktop step 2: launcher, notifications, quick settings.", urgency=1, time=mins(0),
                 actions=[dict(key="default", label="Open"), dict(key="join", label="Join call"), dict(key="snooze", label="Snooze")]),
            dict(id=2, appName="Discover", appIcon="plasmadiscover", summary="Updates are ready",
                 body="12 updates, including <b>Firefox</b> and the kernel. MpireOS takes a snapshot first.",
                 urgency=1, time=mins(14), actions=[dict(key="install", label="Install")]),
            dict(id=1, appName="Files", appIcon="system-file-manager", summary="Copy finished",
                 body="Moved 48 photos to Pictures/Joshua Tree.", urgency=1, time=mins(63), actions=[]),
        ]
        self._popups = [3, 2]

    @Property("QVariantList", notify=popupsChanged)
    def popups(self):
        return [i for i in self._items if i["id"] in self._popups]

    @Property("QVariantList", notify=historyChanged)
    def history(self):
        return self._items

    @Property(int, notify=historyChanged)
    def unread(self):
        return 2

    def _get_dnd(self):
        return self._dnd

    def _set_dnd(self, v):
        self._dnd = v
        self.doNotDisturbChanged.emit()

    doNotDisturb = Property(bool, _get_dnd, _set_dnd, notify=doNotDisturbChanged)

    @Slot(int)
    def dismiss(self, id):
        self._items = [i for i in self._items if i["id"] != id]
        self.hidePopup(id)
        self.historyChanged.emit()

    @Slot(int)
    def hidePopup(self, id):
        self._popups = [p for p in self._popups if p != id]
        self.popupsChanged.emit()

    @Slot(int, str)
    def invoke(self, id, key):
        print("action:", id, key)
        self.dismiss(id)

    @Slot()
    def clearAll(self):
        self._items, self._popups = [], []
        self.popupsChanged.emit()
        self.historyChanged.emit()

    @Slot()
    def markRead(self):
        pass


class FakeSystemStatus(QObject):
    """Stands in for SystemStatus (src/systemstatus.h)."""
    changed = Signal()
    battery = Property(int, lambda self: 82, notify=changed)
    charging = Property(bool, lambda self: False, notify=changed)
    network = Property(str, lambda self: "Home", notify=changed)
    networkKind = Property(str, lambda self: "wifi", notify=changed)
    wifiEnabled = Property(bool, lambda self: True, notify=changed)
    hasWifi = Property(bool, lambda self: True, notify=changed)
    volume = Property(int, lambda self: 64, notify=changed)
    muted = Property(bool, lambda self: False, notify=changed)
    brightness = Property(int, lambda self: 72, notify=changed)

    @Slot()
    def refresh(self):
        pass

    @Slot(bool)
    def setWifiEnabled(self, on): print("wifi:", on)

    @Slot(int)
    def setVolume(self, v): print("volume:", v)

    @Slot(bool)
    def setMuted(self, on): print("muted:", on)

    @Slot(int)
    def setBrightness(self, v): print("brightness:", v)

    @Slot()
    def lock(self): print("lock")

    @Slot()
    def logOut(self): print("log out")

    @Slot()
    def suspend(self): print("suspend")

    @Slot()
    def restart(self): print("restart")

    @Slot()
    def powerOff(self): print("power off")


class FakeShellApi(QObject):
    """Stands in for mpire-shell's ShellApi (src/shellapi.h)."""
    panelChanged = Signal()

    def __init__(self, panel=""):
        super().__init__()
        self._panel = panel

    def _get_panel(self):
        return self._panel

    def _set_panel(self, p):
        self._panel = p
        self.panelChanged.emit()

    panel = Property(str, _get_panel, _set_panel, notify=panelChanged)

    @Slot(str)
    def TogglePanel(self, name):
        self._set_panel("" if self._panel == name else name)

    @Slot(str)
    def launch(self, command):
        print("launch:", command)

    @Slot(str)
    def openUrl(self, url):
        print("open:", url)

    @Slot(str)
    def copy(self, text):
        print("copy:", text)


class FakeSddm(QObject):
    loginFailed = Signal()
    loginSucceeded = Signal()

    @Slot(str, str, int)
    def login(self, user, password, session):
        print("login:", user, session)
        self.loginFailed.emit()


class FakeSessions(QObject):
    @Property(int, constant=True)
    def lastIndex(self):
        return 0


class FakeUsers(QStandardItemModel):
    NAME, REAL = Qt.UserRole + 1, Qt.UserRole + 2

    def __init__(self):
        super().__init__()
        for name, real in [("meng", "Meng"), ("guest", "")]:
            item = QStandardItem()
            item.setData(name, self.NAME)
            item.setData(real, self.REAL)
            self.appendRow(item)

    def roleNames(self):
        return {self.NAME: QByteArray(b"name"), self.REAL: QByteArray(b"realName")}

    @Property(str, constant=True)
    def lastUser(self):
        return ""


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("scene", choices=SCENES)
    parser.add_argument("--shot", type=Path, help="save a screenshot and exit")
    parser.add_argument("--size", default="1366x936")
    parser.add_argument("--time", help="fixed time for screenshots, e.g. 2026-11-12T10:53")
    parser.add_argument("--fake-sddm", action="store_true", help="greeter: provide stand-in SDDM objects")
    parser.add_argument("--panel", default="", help="panels: launcher, quick-settings, notifications, or popups")
    parser.add_argument("--query", default="", help="panels: text typed into the launcher")
    args = parser.parse_args()
    w, h = (int(x) for x in args.size.split("x"))

    app = QGuiApplication(sys.argv)
    view = QQuickView()
    view.engine().addImportPath(str(ROOT / "style"))
    view.setResizeMode(QQuickView.SizeRootObjectToView)
    view.resize(w, h)
    if args.scene.startswith("shell-"):
        view.setColor(Qt.transparent)   # surfaces are transparent, as in mpire-shell
    ctx = view.rootContext()
    now = QDateTime.fromString(args.time, "yyyy-MM-ddTHH:mm") if args.time else QDateTime.currentDateTime()
    keep = [FakeShellApi("" if args.panel == "popups" else args.panel), FakeAppIndex(), FakeNotifications(now), FakeSystemStatus()]
    ctx.setContextProperty("shellApi", keep[0])
    ctx.setContextProperty("appIndex", keep[1])
    ctx.setContextProperty("notifications", keep[2])
    ctx.setContextProperty("systemStatus", keep[3])
    view.engine().addImageProvider("icon", LetterIcons())
    if args.fake_sddm:
        sddm, users, sessions = FakeSddm(), FakeUsers(), FakeSessions()
        keep += [sddm, users, sessions]
        ctx.setContextProperty("sddm", sddm)
        ctx.setContextProperty("userModel", users)
        ctx.setContextProperty("sessionModel", sessions)
    view.setSource(QUrl.fromLocalFile(str(SCENES[args.scene])))
    if view.status() != QQuickView.Ready:
        for e in view.errors():
            print(e.toString(), file=sys.stderr)
        return 1
    if args.time:
        view.rootObject().setProperty("now", now)
    view.show()
    if args.panel:
        keep[0].panelChanged.emit()          # as when mpire-shell opens a panel
    if args.query:
        launcher = view.rootObject().findChild(QObject, "launcher")
        if launcher is not None:
            launcher.setProperty("query", args.query)
    if args.shot:
        def shoot():
            view.grabWindow().save(str(args.shot))
            app.quit()
        QTimer.singleShot(900, shoot)
    return app.exec()


if __name__ == "__main__":
    sys.exit(main())
