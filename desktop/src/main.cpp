// mpire-shell: the Mpire Desktop shell. It draws the desktop, the top bar, and
// the dock as layer-shell surfaces on a Wayland compositor (KWin for now,
// mpire-compositor later). See docs/architecture.md, "Desktop".
#include <QDir>
#include <QGuiApplication>
#include <QQmlContext>
#include <QQmlEngine>
#include <QQuickItem>
#include <QQuickView>
#include <QScreen>

#include <LayerShellQt/Window>

#include "shellapi.h"

using LayerShellQt::Window;

namespace {

constexpr int kTopBarHeight = 44;
constexpr int kDockMargin = 24;

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

    if (QGuiApplication::platformName() != QLatin1String("wayland"))
        qWarning("mpire-shell: not running on Wayland (%s); surfaces will be plain windows",
                 qPrintable(QGuiApplication::platformName()));

    ShellApi api;
    QQmlEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("shellApi"), &api);

    QScreen *screen = QGuiApplication::primaryScreen();
    const QSize size = screen->size();

    // Desktop: wallpaper and widgets, under every window, ignoring other surfaces' zones.
    QQuickView *background = makeSurface(&engine, QStringLiteral("surfaces/BackgroundSurface.qml"), screen);
    Window *bg = layer(background, Window::LayerBackground,
                       Window::Anchors(Window::AnchorTop | Window::AnchorBottom | Window::AnchorLeft | Window::AnchorRight),
                       QStringLiteral("mpire-desktop"));
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

    return app.exec();
}
