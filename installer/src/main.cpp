// Mpire Setup: the MpireOS graphical installer.
// This is the frontend only. It never touches disks; it hands an install plan
// to the privileged backend (see docs/architecture.md, "Installer").
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQuickWindow>
#include <QCommandLineParser>
#include <QDir>

#include "systembridge.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    app.setApplicationName("mpire-setup");
    app.setApplicationDisplayName("Install MpireOS");
    app.setOrganizationName("MpireOS");

    QCommandLineParser parser;
    parser.addHelpOption();
    QCommandLineOption windowed("windowed", "Run in a window instead of full screen.");
    parser.addOption(windowed);
    QCommandLineOption demo("demo", "Never touch disks: show sample disks and a simulated install.");
    parser.addOption(demo);
    parser.process(app);

    SystemBridge system(parser.isSet(demo));

    QQmlApplicationEngine engine;
    const QString qmlDir = QStringLiteral(MPIRE_SETUP_QML_DIR);
    engine.addImportPath(qmlDir);
    // Hand the real machine to the Installer singleton before any page reads it.
    // Without it (demo mode, or tools/preview.py) the singleton uses sample data.
    if (auto *installer = engine.singletonInstance<QObject *>("MpireSetup", "Installer"))
        installer->setProperty("system", QVariant::fromValue<QObject *>(&system));
    else
        qWarning("mpire-setup: Installer singleton not found; running as a demo");
    engine.load(QUrl::fromLocalFile(QDir(qmlDir).filePath("Main.qml")));
    if (engine.rootObjects().isEmpty())
        return 1;

    if (!parser.isSet(windowed)) {
        if (auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().first()))
            window->showFullScreen();
    }
    return app.exec();
}
