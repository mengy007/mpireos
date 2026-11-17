#!/usr/bin/env python3
"""Render Mpire Desktop previews without a compositor.

    pip install PySide6-Essentials
    python3 desktop/tools/preview.py desktop  [--shot out.png]
    python3 desktop/tools/preview.py greeter  [--shot out.png] [--fake-sddm]
    python3 desktop/tools/preview.py shell-background|shell-topbar|shell-dock [--shot out.png]
    python3 desktop/tools/preview.py panels --panel search|launcher|quick-settings|notifications|popups|desktop-menu|wallpaper|tray-menu
                                            [--query "text"] [--menu-at 520,300] [--wallpaper mpire:lagoon] [--shot out.png]

The top bar shows sample apps' tray icons (Sync, Chat, Steam-like "Games"),
and search finds sample files.

--fake-sddm gives the login screen stand-ins for SDDM's sddm, userModel, and
sessionModel objects, so the code path used under SDDM is exercised.
"""
import argparse
import sys
from pathlib import Path

from PySide6.QtCore import QByteArray, QPointF, QDate, QDateTime, QObject, Property, QRectF, QTime, QTimer, QUrl, Qt, Signal, Slot
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


class FakeDesktopSettings(QObject):
    """Stands in for DesktopSettings (src/desktopsettings.h)."""
    wallpaperChanged = Signal()
    fillModeChanged = Signal()
    dockAutoHideChanged = Signal()
    picturesChanged = Signal()
    browsingChanged = Signal()

    def __init__(self, wallpaper="mpire:mist", pictures=()):
        super().__init__()
        self._wallpaper, self._fill, self._autohide = wallpaper, "fill", True
        self._pictures = [dict(url=QUrl.fromLocalFile(str(p)).toString(), name=p.stem.replace("-", " ").capitalize())
                          for p in pictures]

    def _get_wallpaper(self): return self._wallpaper
    def _set_wallpaper(self, v):
        print("wallpaper:", v)
        self._wallpaper = v
        self.wallpaperChanged.emit()
    wallpaper = Property(str, _get_wallpaper, _set_wallpaper, notify=wallpaperChanged)

    def _get_fill(self): return self._fill
    def _set_fill(self, v):
        self._fill = v
        self.fillModeChanged.emit()
    fillMode = Property(str, _get_fill, _set_fill, notify=fillModeChanged)

    def _get_autohide(self): return self._autohide
    def _set_autohide(self, v):
        print("dock auto-hide:", v)
        self._autohide = v
        self.dockAutoHideChanged.emit()
    dockAutoHide = Property(bool, _get_autohide, _set_autohide, notify=dockAutoHideChanged)

    pictures = Property("QVariantList", lambda self: self._pictures, notify=picturesChanged)
    browsing = Property(bool, lambda self: False, notify=browsingChanged)

    @Slot()
    def refreshPictures(self): pass

    @Slot()
    def browse(self): print("browse for a picture")


TRAY_SAMPLES = [
    # key, title, color, letter, attention
    ("org.example.Chat/StatusNotifierItem", "Chat", "#7C66D6", "C", True),
    ("org.example.Games/StatusNotifierItem", "Games", "#0B3A44", "G", False),
    ("org.example.Sync/StatusNotifierItem", "Sync", "#5B8DEF", "S", False),
]


class TrayIcons(QQuickImageProvider):
    """Stands in for TrayIconProvider: the sample apps' icons."""

    def __init__(self):
        super().__init__(QQuickImageProvider.Pixmap)

    def requestPixmap(self, id, size, requested):
        n = max(requested.width(), 32) if requested.isValid() else 32
        key = QUrl.fromPercentEncoding(id.split("/")[1].encode()) if "/" in id else id
        color, letter = next(((c, l) for k, _, c, l, _ in TRAY_SAMPLES if k == key), ("#B9C2D0", "?"))
        pm = QPixmap(n, n)
        pm.fill(Qt.transparent)
        p = QPainter(pm)
        p.setRenderHint(QPainter.Antialiasing)
        p.setBrush(QColor(color))
        p.setPen(Qt.NoPen)
        p.drawRoundedRect(QRectF(0, 0, n, n), n * 0.3, n * 0.3)
        f = QFont("Inter")
        f.setPixelSize(int(n * 0.6))
        f.setWeight(QFont.Bold)
        p.setFont(f)
        p.setPen(QColor("white"))
        p.drawText(QRectF(0, 0, n, n), Qt.AlignCenter, letter)
        p.end()
        return pm


class FakeSystemTray(QObject):
    """Stands in for SystemTray (src/tray.h)."""
    itemsChanged = Signal()
    menuChanged = Signal()

    def __init__(self, menu_open=False):
        super().__init__()
        self._key = TRAY_SAMPLES[2][0] if menu_open else ""

    @Property("QVariantList", notify=itemsChanged)
    def items(self):
        return [dict(key=k, id=t, title=t, tooltip=t, status="NeedsAttention" if a else "Active", category="ApplicationStatus",
                     attention=a, icon="image://tray/item/%s/1" % QUrl.toPercentEncoding(k).data().decode())
                for k, t, _, _, a in TRAY_SAMPLES]

    @Property("QVariantList", notify=menuChanged)
    def menu(self):
        e = lambda i, label, **kw: dict(id=i, label=label, enabled=kw.get("enabled", True), separator=kw.get("sep", False),
                                        checkable=kw.get("checkable", False), checked=kw.get("checked", False),
                                        radio=kw.get("radio", False), icon="", submenu=kw.get("submenu", []))
        return [e(1, "Sync: all files up to date", enabled=False), e(2, "", sep=True), e(3, "Open Folder"),
                e(4, "Pause Syncing", checkable=True, checked=True),
                e(5, "Speed Limit", submenu=[e(6, "No Limit", checkable=True, radio=True, checked=True),
                                              e(7, "1 MB/s", checkable=True, radio=True)]),
                e(8, "", sep=True), e(9, "Preferences…"), e(10, "Quit Sync")]

    menuKey = Property(str, lambda self: self._key, notify=menuChanged)
    menuTitle = Property(str, lambda self: "Sync", notify=menuChanged)
    menuX = Property(float, lambda self: 1366 - 214.0, notify=menuChanged)

    @Slot(str, float)
    def activate(self, key, x): print("tray activate:", key)

    @Slot(str, float)
    def openMenu(self, key, x): print("tray menu:", key)

    @Slot(int)
    def menuClicked(self, id): print("tray menu clicked:", id)


SAMPLE_FILES = [
    ("Quarterly report.pdf", "~/Documents", "application-pdf", "PDF document", "1.2 MB", False, 1),
    ("Report drafts", "~/Documents", "folder", "Folder", "", True, 3),
    ("report-q3-figures.ods", "~/Documents/Work", "x-office-spreadsheet", "ODS spreadsheet", "86.4 KB", False, 9),
    ("Joshua Tree report.jpg", "~/Pictures", "image-jpeg", "JPEG image", "3.1 MB", False, 30),
]


class FakeFileSearch(QObject):
    """Stands in for FileSearch (src/filesearch.h)."""
    revisionChanged = Signal()
    revision = Property(int, lambda self: 1, notify=revisionChanged)
    scanning = Property(bool, lambda self: False, notify=revisionChanged)

    @Slot(str, int, result="QVariantList")
    def search(self, query, limit):
        q = query.strip().lower()
        if len(q) < 2:
            return []
        now = QDateTime.currentDateTime()
        out = []
        for name, folder, icon, kind, size, is_dir, days in SAMPLE_FILES:
            if q.split()[0] in name.lower():
                path = folder.replace("~", "/home/meng") + "/" + name
                out.append(dict(path=path, url=QUrl.fromLocalFile(path).toString(), name=name, folder=folder, isDir=is_dir,
                                icon=icon, kind=kind, size=size, modified=now.addDays(-days), image=False,
                                rank=(96 if name.lower().startswith(q) else 74) - days * 0.1))
        return out[:limit]

    @Slot()
    def refresh(self): pass

    @Slot(str)
    def reveal(self, path): print("reveal:", path)


class FakeShellApi(QObject):
    """Stands in for mpire-shell's ShellApi (src/shellapi.h)."""
    panelChanged = Signal()

    def __init__(self, panel="", menu_at=(-1, -1)):
        super().__init__()
        self._panel = panel
        self._menu = QPointF(*menu_at)

    menuPosition = Property(QPointF, lambda self: self._menu, notify=panelChanged)

    @Slot(float, float)
    def openDesktopMenu(self, x, y):
        self._menu = QPointF(x, y)
        self._set_panel("desktop-menu")

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
    parser.add_argument("--panel", default="", help="panels: search, launcher, quick-settings, notifications, popups, desktop-menu, wallpaper, or tray-menu")
    parser.add_argument("--query", default="", help="panels: text typed into search or the launcher")
    parser.add_argument("--menu-at", default="-1,-1", help="panels: where the desktop menu opens, x,y")
    parser.add_argument("--wallpaper", default="mpire:mist", help="the desktop's wallpaper, e.g. mpire:lagoon")
    parser.add_argument("--pictures", type=Path, nargs="*", default=[], help="wallpaper picker: sample pictures")
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
    menu_at = tuple(float(v) for v in args.menu_at.split(","))
    keep = [FakeShellApi("" if args.panel == "popups" else args.panel, menu_at), FakeAppIndex(), FakeNotifications(now),
            FakeSystemStatus(), FakeDesktopSettings(args.wallpaper, args.pictures),
            FakeSystemTray(args.panel == "tray-menu"), FakeFileSearch()]
    ctx.setContextProperty("shellApi", keep[0])
    ctx.setContextProperty("appIndex", keep[1])
    ctx.setContextProperty("notifications", keep[2])
    ctx.setContextProperty("systemStatus", keep[3])
    ctx.setContextProperty("desktopSettings", keep[4])
    ctx.setContextProperty("systemTray", keep[5])
    ctx.setContextProperty("fileSearch", keep[6])
    view.engine().addImageProvider("icon", LetterIcons())
    view.engine().addImageProvider("tray", TrayIcons())
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
        target = view.rootObject().findChild(QObject, "search" if args.panel == "search" else "launcher")
        if target is not None:
            target.setProperty("query", args.query)
    if args.shot:
        def shoot():
            view.grabWindow().save(str(args.shot))
            app.quit()
        QTimer.singleShot(900, shoot)
    return app.exec()


if __name__ == "__main__":
    sys.exit(main())
