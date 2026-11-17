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
#include <QRegion>
#include <QScreen>
#include <QUrl>

#include <LayerShellQt/Window>

#include "apps.h"
#include "desktopsettings.h"
#include "filesearch.h"
#include "iconprovider.h"
#include "notifications.h"
#include "shellapi.h"
#include "systemstatus.h"
#include "tray.h"

using LayerShellQt::Window;

namespace {

constexpr int kTopBarHeight = 30;        // Theme.topBarHeight
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
    const QCommandLineOption show(QStringLiteral("show"), QStringLiteral("Open a panel in the running shell: search, launcher, quick-settings, notifications, desktop-menu, wallpaper."), QStringLiteral("panel"));
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
    DesktopSettings desktopSettings;
    FileSearch files;
    SystemTray tray;

    QDBusConnection bus = QDBusConnection::sessionBus();
    if (!bus.registerObject(QString::fromLatin1(kPath), &api, QDBusConnection::ExportScriptableSlots)
        || !bus.registerService(QString::fromLatin1(kService)))
        qWarning("mpire-shell: could not register %s on the session bus; shortcuts won't open panels", kService);
    if (!notifications.registerOnBus())
        qWarning("mpire-shell: another notification server is running; apps' notifications won't show here");
    tray.start();

    QQmlEngine engine;
    engine.addImageProvider(QStringLiteral("icon"), new IconProvider);
    engine.addImageProvider(QStringLiteral("tray"), new TrayIconProvider(&tray));
    engine.rootContext()->setContextProperty(QStringLiteral("shellApi"), &api);
    engine.rootContext()->setContextProperty(QStringLiteral("appIndex"), &apps);
    engine.rootContext()->setContextProperty(QStringLiteral("notifications"), &notifications);
    engine.rootContext()->setContextProperty(QStringLiteral("systemStatus"), &status);
    engine.rootContext()->setContextProperty(QStringLiteral("desktopSettings"), &desktopSettings);
    engine.rootContext()->setContextProperty(QStringLiteral("fileSearch"), &files);
    engine.rootContext()->setContextProperty(QStringLiteral("systemTray"), &tray);

    QScreen *screen = QGuiApplication::primaryScreen();
    const QSize size = screen->size();
    const auto allEdges = Window::Anchors(Window::AnchorTop | Window::AnchorBottom | Window::AnchorLeft | Window::AnchorRight);

    // Desktop: the wallpaper, under every window, ignoring other surfaces' zones.
    // Right-clicking it opens the desktop menu (a panel, below).
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

    // Dock: centered at the bottom; by default it hides itself and slides up
    // when the pointer reaches the bottom edge (DockSurface.qml) and reserves
    // no space, so maximized windows use the full height. With auto-hide off
    // (desktop menu), it stays up and windows keep clear of it.
    QQuickView *dock = makeSurface(&engine, QStringLiteral("surfaces/DockSurface.qml"), screen);
    QQuickItem *dockItem = dock->rootObject();
    Window *dk = layer(dock, Window::LayerTop,
                       Window::Anchors(Window::AnchorBottom | Window::AnchorLeft | Window::AnchorRight),
                       QStringLiteral("mpire-dock"));
    dock->resize(size.width(), int(dockItem->implicitHeight()));
    const auto applyDockZone = [dk, dockItem, &desktopSettings] {
        dk->setExclusiveZone(desktopSettings.dockAutoHide() ? 0 : int(dockItem->implicitHeight()));
    };
    QObject::connect(&desktopSettings, &DesktopSettings::dockAutoHideChanged, dock, applyDockZone);
    applyDockZone();
    if (auto *input = dockItem->findChild<QQuickItem *>(QStringLiteral("inputArea"))) {
        const auto applyMask = [dock, input] {
            dock->setMask(QRegion(QRectF(input->x(), input->y(), input->width(), input->height()).toAlignedRect()));
        };
        for (auto signal : {&QQuickItem::xChanged, &QQuickItem::yChanged, &QQuickItem::widthChanged, &QQuickItem::heightChanged})
            QObject::connect(input, signal, dock, applyMask);
        applyMask();
    }
    dock->show();

    // Panels (universal search, launcher, quick settings, notification list,
    // desktop menu, wallpaper picker, tray menus): one full-screen overlay, shown only while a panel is
    // open. Clicking outside closes it.
    QQuickView *panels = makeSurface(&engine, QStringLiteral("surfaces/PanelSurface.qml"), screen);
    Window *pn = layer(panels, Window::LayerOverlay, allEdges, QStringLiteral("mpire-panels"));
    pn->setExclusiveZone(-1);
    panels->resize(size);
    // While the system file chooser is open (wallpaper picker's "Add a
    // picture"), step aside so it isn't hidden under the overlay.
    QObject::connect(&desktopSettings, &DesktopSettings::browsingChanged, panels, [&desktopSettings, &api, panels] {
        if (desktopSettings.browsing())
            panels->hide();
        else if (!api.panel().isEmpty())
            panels->show();
    });
    // A tray icon's menu opens as a panel once the app has sent it, and the
    // app hears when it closes.
    QObject::connect(&tray, &SystemTray::menuRequested, &api, [&api] { api.ShowPanel(QStringLiteral("tray-menu")); });
    QObject::connect(&api, &ShellApi::panelChanged, &tray, [&api, &tray] {
        if (api.panel() != QLatin1String("tray-menu") && !tray.menuKey().isEmpty())
            tray.menuClosed();
    });
    QObject::connect(&api, &ShellApi::panelChanged, panels, [&api, panels, pn, &desktopSettings] {
        if (api.panel().isEmpty()) {
            panels->hide();
            return;
        }
        // Search and the launcher take the keyboard for typing, and tray menus
        // for their arrow keys; other panels only when clicked.
        const bool typing = api.panel() == QLatin1String("launcher") || api.panel() == QLatin1String("search")
            || api.panel() == QLatin1String("tray-menu");
        pn->setKeyboardInteractivity(typing ? Window::KeyboardInteractivityExclusive : Window::KeyboardInteractivityOnDemand);
        if (desktopSettings.browsing())
            return;
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
