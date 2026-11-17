// mpire-tray-test: a stand-in third-party app with a tray icon and menu, for
// checking the top bar's system tray (CI boot test and by hand). It uses Qt's
// own QSystemTrayIcon, which publishes a StatusNotifierItem + dbusmenu, like
// any Qt or KDE app.
//
//   mpire-tray-test [--name Sync] [--color "#5B8DEF"]
//
// Run it with DBUS_SESSION_BUS_ADDRESS=disabled: and QT_QPA_PLATFORM=xcb and Qt
// falls back to an old-style XEmbed tray icon instead, which reaches the top
// bar through xembedsniproxy.
#include <QAction>
#include <QActionGroup>
#include <QApplication>
#include <QCommandLineParser>
#include <QMenu>
#include <QPainter>
#include <QPainterPath>
#include <QSystemTrayIcon>
#include <cstdio>

static QIcon makeIcon(const QColor &color, const QString &letter)
{
    QIcon icon;
    for (int n : {16, 22, 32, 64}) {
        QPixmap pm(n, n);
        pm.fill(Qt::transparent);
        QPainter p(&pm);
        p.setRenderHint(QPainter::Antialiasing);
        QPainterPath path;
        path.addRoundedRect(QRectF(0.5, 0.5, n - 1, n - 1), n * 0.3, n * 0.3);
        p.fillPath(path, color);
        QFont f = p.font();
        f.setPixelSize(int(n * 0.6));
        f.setBold(true);
        p.setFont(f);
        p.setPen(Qt::white);
        p.drawText(QRectF(0, 0, n, n), Qt::AlignCenter, letter);
        p.end();
        icon.addPixmap(pm);
    }
    return icon;
}

int main(int argc, char *argv[])
{
    QApplication app(argc, argv);
    app.setQuitOnLastWindowClosed(false);
    QCommandLineParser cli;
    cli.addHelpOption();
    const QCommandLineOption name(QStringLiteral("name"), QStringLiteral("The app's name."), QStringLiteral("name"), QStringLiteral("Sync"));
    const QCommandLineOption color(QStringLiteral("color"), QStringLiteral("Icon color."), QStringLiteral("color"), QStringLiteral("#5B8DEF"));
    cli.addOptions({name, color});
    cli.process(app);
    const QString appName = cli.value(name);
    app.setApplicationName(appName);

    QSystemTrayIcon tray(makeIcon(QColor(cli.value(color)), appName.left(1).toUpper()));
    tray.setToolTip(appName + QStringLiteral(" is up to date"));
    QMenu menu;
    QAction *status = menu.addAction(appName + QStringLiteral(": all files up to date"));
    status->setEnabled(false);
    menu.addSeparator();
    QObject::connect(menu.addAction(QIcon::fromTheme(QStringLiteral("folder")), QStringLiteral("Open Folder")), &QAction::triggered,
                     [] { std::puts("tray-test: Open Folder"); std::fflush(stdout); });
    QAction *pause = menu.addAction(QStringLiteral("Pause Syncing"));
    pause->setCheckable(true);
    QObject::connect(pause, &QAction::toggled, [](bool on) { std::printf("tray-test: paused %d\n", on); std::fflush(stdout); });
    QMenu *speed = menu.addMenu(QStringLiteral("Speed Limit"));
    auto *group = new QActionGroup(&menu);
    for (const char *s : {"No Limit", "1 MB/s", "250 KB/s"}) {
        QAction *a = speed->addAction(QString::fromLatin1(s));
        a->setCheckable(true);
        a->setActionGroup(group);
        a->setChecked(QLatin1String(s) == QLatin1String("No Limit"));
    }
    menu.addSeparator();
    menu.addAction(QStringLiteral("Preferences…"));
    QObject::connect(menu.addAction(QStringLiteral("Quit ") + appName), &QAction::triggered, &app, &QApplication::quit);
    tray.setContextMenu(&menu);
    QObject::connect(&tray, &QSystemTrayIcon::activated, [](QSystemTrayIcon::ActivationReason r) {
        std::printf("tray-test: activated %d\n", int(r));
        std::fflush(stdout);
    });
    tray.show();
    std::printf("tray-test: %s shown (tray available: %d)\n", qPrintable(appName), int(QSystemTrayIcon::isSystemTrayAvailable()));
    std::fflush(stdout);
    return app.exec();
}
