#!/usr/bin/env python3
"""Preview Mpire Setup without building the C++ app.

    pip install PySide6-Essentials
    python3 installer/tools/preview.py               # interactive window
    python3 installer/tools/preview.py --shots DIR   # save a screenshot of every screen
"""
import argparse
import sys
from pathlib import Path

from PySide6.QtCore import Q_ARG, QMetaObject, QTimer, QUrl
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuick import QQuickWindow
from shiboken6 import Shiboken

QML_DIR = Path(__file__).resolve().parent.parent / "qml"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--shots", type=Path, help="save screenshots of each screen to this folder")
    args = parser.parse_args()

    app = QGuiApplication(sys.argv)
    engine = QQmlApplicationEngine()
    engine.addImportPath(str(QML_DIR))
    engine.load(QUrl.fromLocalFile(str(QML_DIR / "Main.qml")))
    if not engine.rootObjects():
        return 1
    if not args.shots:
        return app.exec()

    root = engine.rootObjects()[0]
    window = Shiboken.wrapInstance(Shiboken.getCppPointer(root)[0], QQuickWindow)
    installer = root.property("installer")
    args.shots.mkdir(parents=True, exist_ok=True)
    names = ["1-welcome", "2-disk", "3-account", "4-review", "5-installing", "6-done"]
    state = {"i": 0}

    def step():
        i = state["i"]
        if i == 2:
            installer.setProperty("fullName", "Jordan Lee")
            installer.setProperty("userName", "jordan")
            installer.setProperty("password", "correct horse")
        if i == 4:
            installer.setProperty("status", "Copying MpireOS")
            installer.setProperty("progress", 0.42)
        if i == 5:
            installer.setProperty("progress", 1.0)
        QMetaObject.invokeMethod(root, "go", Q_ARG("QVariant", i))
        QTimer.singleShot(700, lambda: shoot(i))

    def shoot(i):
        try:
            window.grabWindow().save(str(args.shots / f"{names[i]}.png"))
        except Exception:
            app.exit(1)
            raise
        state["i"] += 1
        if state["i"] < len(names):
            step()
        else:
            app.quit()

    QTimer.singleShot(500, step)
    return app.exec()


if __name__ == "__main__":
    sys.exit(main())
