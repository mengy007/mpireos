#!/usr/bin/env python3
"""Render Mpire Desktop previews without a compositor.

    pip install PySide6-Essentials
    python3 desktop/tools/preview.py desktop  [--shot out.png]
    python3 desktop/tools/preview.py greeter  [--shot out.png] [--fake-sddm]
    python3 desktop/tools/preview.py shell-background|shell-topbar|shell-dock [--shot out.png]

--fake-sddm gives the login screen stand-ins for SDDM's sddm, userModel, and
sessionModel objects, so the code path used under SDDM is exercised.
"""
import argparse
import sys
from pathlib import Path

from PySide6.QtCore import QByteArray, QDate, QDateTime, QObject, Property, QTime, QTimer, QUrl, Qt, Signal, Slot
from PySide6.QtGui import QGuiApplication, QStandardItem, QStandardItemModel
from PySide6.QtQuick import QQuickView

ROOT = Path(__file__).resolve().parent.parent
SCENES = {
    "desktop": ROOT / "shell" / "Desktop.qml",
    "greeter": ROOT / "greeter" / "Main.qml",
    "shell-background": ROOT / "shell" / "surfaces" / "BackgroundSurface.qml",
    "shell-topbar": ROOT / "shell" / "surfaces" / "TopBarSurface.qml",
    "shell-dock": ROOT / "shell" / "surfaces" / "DockSurface.qml",
}


class FakeShellApi(QObject):
    """Stands in for mpire-shell's ShellApi (src/shellapi.h)."""
    batteryChanged = Signal()

    @Property(int, notify=batteryChanged)
    def battery(self):
        return -1

    @Slot(str)
    def launch(self, command):
        print("launch:", command)


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
    args = parser.parse_args()
    w, h = (int(x) for x in args.size.split("x"))

    app = QGuiApplication(sys.argv)
    view = QQuickView()
    view.engine().addImportPath(str(ROOT / "style"))
    view.setResizeMode(QQuickView.SizeRootObjectToView)
    view.resize(w, h)
    ctx = view.rootContext()
    keep = [FakeShellApi()]
    ctx.setContextProperty("shellApi", keep[0])
    if args.fake_sddm:
        keep += [FakeSddm(), FakeUsers(), FakeSessions()]
        ctx.setContextProperty("sddm", keep[1])
        ctx.setContextProperty("userModel", keep[2])
        ctx.setContextProperty("sessionModel", keep[3])
    view.setSource(QUrl.fromLocalFile(str(SCENES[args.scene])))
    if view.status() != QQuickView.Ready:
        for e in view.errors():
            print(e.toString(), file=sys.stderr)
        return 1
    if args.time:
        dt = QDateTime.fromString(args.time, "yyyy-MM-ddTHH:mm")
        view.rootObject().setProperty("now", dt)
    view.show()
    if args.shot:
        def shoot():
            view.grabWindow().save(str(args.shot))
            app.quit()
        QTimer.singleShot(900, shoot)
    return app.exec()


if __name__ == "__main__":
    sys.exit(main())
