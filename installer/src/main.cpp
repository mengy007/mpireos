// Mpire Setup: the MpireOS graphical installer.
// This is the frontend only. It never touches disks; it hands an install plan
// to the privileged backend (see docs/architecture.md, "Installer").
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQuickWindow>
#include <QCommandLineParser>
#include <QDir>

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
    parser.process(app);

    QQmlApplicationEngine engine;
    const QString qmlDir = QStringLiteral(MPIRE_SETUP_QML_DIR);
    engine.addImportPath(qmlDir);
    engine.load(QUrl::fromLocalFile(QDir(qmlDir).filePath("Main.qml")));
    if (engine.rootObjects().isEmpty())
        return 1;

    if (!parser.isSet(windowed)) {
        if (auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().first()))
            window->showFullScreen();
    }
    return app.exec();
}
