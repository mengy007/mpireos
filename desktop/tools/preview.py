#!/usr/bin/env python3
"""Render Mpire Desktop previews without a compositor.

    pip install PySide6-Essentials
    python3 desktop/tools/preview.py desktop  [--shot out.png]
    python3 desktop/tools/preview.py greeter  [--shot out.png]
"""
import argparse
import sys
from pathlib import Path

from PySide6.QtCore import QDate, QDateTime, QTime, QTimer, QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtQuick import QQuickView

ROOT = Path(__file__).resolve().parent.parent
SCENES = {"desktop": ROOT / "shell" / "Desktop.qml", "greeter": ROOT / "greeter" / "Main.qml"}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("scene", choices=SCENES)
    parser.add_argument("--shot", type=Path, help="save a screenshot and exit")
    parser.add_argument("--size", default="1366x936")
    parser.add_argument("--time", help="fixed time for screenshots, e.g. 2026-11-12T10:53")
    args = parser.parse_args()
    w, h = (int(x) for x in args.size.split("x"))

    app = QGuiApplication(sys.argv)
    view = QQuickView()
    view.engine().addImportPath(str(ROOT / "style"))
    view.setResizeMode(QQuickView.SizeRootObjectToView)
    view.resize(w, h)
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
