// mpire-shell: the Mpire Desktop shell. It draws the desktop, the top bar, and
// the dock as layer-shell surfaces on a Wayland compositor (KWin for now,
// mpire-compositor later). See docs/architecture.md, "Desktop".
#include <QCommandLineParser>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDir>
#include <QGuiApplication>
#include <QIcon>
#include <QQmlContext>
#include <QQmlEngine>
#include <QQuickItem>
#include <QQuickView>
#include <QScreen>
#include <QUrl>

#include <LayerShellQt/Window>

#include "apps.h"
#include "iconprovider.h"
#include "notifications.h"
#include "shellapi.h"
#include "systemstatus.h"

using LayerShellQt::Window;

namespace {

constexpr int kTopBarHeight = 44;
constexpr int kDockMargin = 24;
constexpr int kPopupWidth = 392;         // 360 card + room for its shadow
const char *kService = "org.mpireos.Shell";
const char *kPath = "/org/mpireos/Shell";

// `mpire-shell --show launcher` and friends: ask the running shell over D-Bus.
int remote(const QString &method, const QString &panel)
{
    QDBusMessage call = QDBusMessage::createMethodCall(QString::fromLatin1(kService), QString::fromLatin1(kPath),
                                                       QString::fromLatin1(kService), method);
    if (!panel.isNull())
        call << panel;
    const QDBusMessage reply = QDBusConnection::sessionBus().call(call, QDBus::Block, 3000);
    if (reply.type() == QDBusMessage::ErrorMessage) {
        qCritical("mpire-shell: the shell is not running (%s)", qPrintable(reply.errorMessage()));
        return 1;
    }
    return 0;
}

QQuickView *makeSurface(QQmlEngine *engine, const QString &file, QScreen *screen)
{
    auto *view = new QQuickView(engine, nullptr);
    view->setScreen(screen);
    view->setColor(Qt::transparent);
    view->setResizeMode(QQuickView::SizeRootObjectToView);
    view->setSource(QUrl::fromLocalFile(QDir(QStringLiteral(MPIRE_SHELL_QML_DIR)).filePath(file)));
    if (view->status() != QQuickView::Ready) {
        for (const auto &e : view->errors())
            qCritical("mpire-shell: %s", qPrintable(e.toString()));
        qFatal("mpire-shell: could not load %s", qPrintable(file));
    }
    return view;
}

Window *layer(QQuickView *view, Window::Layer which, Window::Anchors anchors, const QString &scope)
{
    // Must happen before the window is shown: it makes the window a layer surface.
    Window *w = Window::get(view);
    w->setLayer(which);
    w->setAnchors(anchors);
    w->setScope(scope);
    w->setKeyboardInteractivity(Window::KeyboardInteractivityNone);
    return w;
}

} // namespace

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("mpire-shell"));
    app.setOrganizationName(QStringLiteral("MpireOS"));
    app.setQuitOnLastWindowClosed(false);

    QCommandLineParser cli;
    cli.setApplicationDescription(QStringLiteral("Mpire Desktop's shell: desktop, top bar, dock, and panels."));
    cli.addHelpOption();
    const QCommandLineOption show(QStringLiteral("show"), QStringLiteral("Open a panel in the running shell: launcher, quick-settings, notifications."), QStringLiteral("panel"));
    const QCommandLineOption toggle(QStringLiteral("toggle"), QStringLiteral("Open or close a panel in the running shell."), QStringLiteral("panel"));
    const QCommandLineOption hide(QStringLiteral("hide"), QStringLiteral("Close the open panel in the running shell."));
    cli.addOptions({show, toggle, hide});
    cli.process(app);
    if (cli.isSet(show))
        return remote(QStringLiteral("ShowPanel"), cli.value(show));
    if (cli.isSet(toggle))
        return remote(QStringLiteral("TogglePanel"), cli.value(toggle));
    if (cli.isSet(hide))
        return remote(QStringLiteral("HidePanel"), QString());

    if (QGuiApplication::platformName() != QLatin1String("wayland"))
        qWarning("mpire-shell: not running on Wayland (%s); surfaces will be plain windows",
                 qPrintable(QGuiApplication::platformName()));
    if (QIcon::themeName().isEmpty() || QIcon::themeName() == QLatin1String("hicolor"))
        QIcon::setThemeName(QStringLiteral("breeze"));

    ShellApi api;
    AppIndex apps;
    NotificationServer notifications;
    SystemStatus status;

    QDBusConnection bus = QDBusConnection::sessionBus();
    if (!bus.registerObject(QString::fromLatin1(kPath), &api, QDBusConnection::ExportScriptableSlots)
        || !bus.registerService(QString::fromLatin1(kService)))
        qWarning("mpire-shell: could not register %s on the session bus; shortcuts won't open panels", kService);
    if (!notifications.registerOnBus())
        qWarning("mpire-shell: another notification server is running; apps' notifications won't show here");

    QQmlEngine engine;
    engine.addImageProvider(QStringLiteral("icon"), new IconProvider);
    engine.rootContext()->setContextProperty(QStringLiteral("shellApi"), &api);
    engine.rootContext()->setContextProperty(QStringLiteral("appIndex"), &apps);
    engine.rootContext()->setContextProperty(QStringLiteral("notifications"), &notifications);
    engine.rootContext()->setContextProperty(QStringLiteral("systemStatus"), &status);

    QScreen *screen = QGuiApplication::primaryScreen();
    const QSize size = screen->size();
    const auto allEdges = Window::Anchors(Window::AnchorTop | Window::AnchorBottom | Window::AnchorLeft | Window::AnchorRight);

    // Desktop: wallpaper and widgets, under every window, ignoring other surfaces' zones.
    QQuickView *background = makeSurface(&engine, QStringLiteral("surfaces/BackgroundSurface.qml"), screen);
    Window *bg = layer(background, Window::LayerBackground, allEdges, QStringLiteral("mpire-desktop"));
    bg->setExclusiveZone(-1);
    background->resize(size);
    background->show();

    // Top bar: full width, and windows don't go under it.
    QQuickView *topBar = makeSurface(&engine, QStringLiteral("surfaces/TopBarSurface.qml"), screen);
    Window *tb = layer(topBar, Window::LayerTop,
                       Window::Anchors(Window::AnchorTop | Window::AnchorLeft | Window::AnchorRight),
                       QStringLiteral("mpire-topbar"));
    tb->setExclusiveZone(kTopBarHeight);
    topBar->resize(size.width(), kTopBarHeight);
    topBar->show();

    // Dock: floating above the bottom edge, centered; maximized windows stop above it.
    QQuickView *dock = makeSurface(&engine, QStringLiteral("surfaces/DockSurface.qml"), screen);
    QQuickItem *dockItem = dock->rootObject();
    const QSize dockSize(int(dockItem->implicitWidth()), int(dockItem->implicitHeight()));
    Window *dk = layer(dock, Window::LayerTop, Window::Anchors(Window::AnchorBottom), QStringLiteral("mpire-dock"));
    dk->setMargins(QMargins(0, 0, 0, kDockMargin));
    dk->setExclusiveZone(dockSize.height() + kDockMargin);
    dock->resize(dockSize);
    dock->show();

    // Panels (launcher, quick settings, notification list): one full-screen
    // overlay, shown only while a panel is open. Clicking outside closes it.
    QQuickView *panels = makeSurface(&engine, QStringLiteral("surfaces/PanelSurface.qml"), screen);
    Window *pn = layer(panels, Window::LayerOverlay, allEdges, QStringLiteral("mpire-panels"));
    pn->setExclusiveZone(-1);
    panels->resize(size);
    QObject::connect(&api, &ShellApi::panelChanged, panels, [&api, panels, pn] {
        if (api.panel().isEmpty()) {
            panels->hide();
            return;
        }
        // The launcher takes the keyboard for typing; other panels only when clicked.
        pn->setKeyboardInteractivity(api.panel() == QLatin1String("launcher") ? Window::KeyboardInteractivityExclusive
                                                                              : Window::KeyboardInteractivityOnDemand);
        if (!panels->isVisible())
            panels->show();
        panels->requestActivate();
    });

    // Notification popups: top right, below the top bar, as tall as the popups.
    QQuickView *popups = makeSurface(&engine, QStringLiteral("surfaces/PopupSurface.qml"), screen);
    Window *pp = layer(popups, Window::LayerOverlay, Window::Anchors(Window::AnchorTop | Window::AnchorRight),
                       QStringLiteral("mpire-notifications"));
    pp->setMargins(QMargins(0, 4, 4, 0));
    QQuickItem *popupItem = popups->rootObject();
    const auto fitPopups = [popups, popupItem] {
        const int h = int(popupItem->implicitHeight());
        if (h <= 0) {
            popups->hide();
            return;
        }
        popups->resize(kPopupWidth, h);
        if (!popups->isVisible())
            popups->show();
    };
    QObject::connect(popupItem, &QQuickItem::implicitHeightChanged, popups, fitPopups);
    fitPopups();

    return app.exec();
}
