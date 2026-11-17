// The top bar's system tray: other apps' status icons (Discord, Steam, Nextcloud,
// password managers, ...), shown to the left of Mpire Desktop's own icons.
//
// Apps publish tray icons with the StatusNotifierItem D-Bus protocol (KDE's,
// which libappindicator/Ayatana, Qt, Electron, and GTK apps all use). mpire-shell
// is a StatusNotifierHost: it reads each item's icon, title, and status, and
// asks the app to activate, scroll, or show its menu. The menus come over
// com.canonical.dbusmenu and are drawn by the shell itself (TrayMenu.qml), so
// they look like the rest of Mpire Desktop.
//
// Someone has to own org.kde.StatusNotifierWatcher, the registry apps announce
// their items to. In the interim Plasma session KDE's kded already does; when
// nobody does (mpire-compositor's session), mpire-shell runs its own.
//
// Old X11 apps that still use XEmbed tray icons reach us through
// xembedsniproxy (plasma-workspace), which turns each one into a
// StatusNotifierItem.
#pragma once

#include <QDBusContext>
#include <QDBusObjectPath>
#include <QHash>
#include <QIcon>
#include <QImage>
#include <QObject>
#include <QPointer>
#include <QQuickImageProvider>
#include <QStringList>
#include <QTimer>
#include <QVariantList>

class QDBusServiceWatcher;
class QDBusPendingCallWatcher;

// org.kde.StatusNotifierWatcher, when no one else provides it.
class TrayWatcher : public QObject, protected QDBusContext
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.kde.StatusNotifierWatcher")
    Q_PROPERTY(QStringList RegisteredStatusNotifierItems READ registeredItems)
    Q_PROPERTY(bool IsStatusNotifierHostRegistered READ isHostRegistered)
    Q_PROPERTY(int ProtocolVersion READ protocolVersion)

public:
    explicit TrayWatcher(QObject *parent = nullptr);

    QStringList registeredItems() const { return m_items; }
    bool isHostRegistered() const { return !m_hosts.isEmpty(); }
    int protocolVersion() const { return 0; }

public slots:
    void RegisterStatusNotifierItem(const QString &serviceOrPath);
    void RegisterStatusNotifierHost(const QString &service);

signals:
    void StatusNotifierItemRegistered(const QString &item);
    void StatusNotifierItemUnregistered(const QString &item);
    void StatusNotifierHostRegistered();
    void StatusNotifierHostUnregistered();

private:
    void serviceGone(const QString &service);

    QStringList m_items;              // "busname/object/path"
    QStringList m_hosts;
    QDBusServiceWatcher *m_serviceWatcher;
};

// One app's status icon.
class TrayItem : public QObject
{
    Q_OBJECT
public:
    TrayItem(const QString &key, QObject *parent);

    QString key;                      // as registered: "busname/object/path"
    QString service;
    QString path;
    int serial = 0;                   // bumped when the icon changes (QML reloads it)

    // From the item's properties
    QString id, title, status, category, iconName, attentionIconName, iconThemePath, tooltip;
    QList<QImage> pixmaps, attentionPixmaps;
    QString menuPath;
    bool itemIsMenu = false;
    bool loaded = false;

    void refresh();
    QImage image(const QSize &size) const;
    QVariantMap toVariant() const;

signals:
    void changed();

private:
    void load(QDBusPendingCallWatcher *call);
    QTimer m_debounce;
};

class SystemTray : public QObject
{
    Q_OBJECT
    // Visible items, newest first (the top bar lays them out right to left of
    // its own icons): {key, id, title, tooltip, status, category, icon (an
    // image://tray URL), attention}
    Q_PROPERTY(QVariantList items READ items NOTIFY itemsChanged)
    // The open menu: entries {id, label, enabled, separator, checkable,
    // checked, radio, icon, submenu: [...]}, and where it opens.
    Q_PROPERTY(QVariantList menu READ menu NOTIFY menuChanged)
    Q_PROPERTY(QString menuKey READ menuKey NOTIFY menuChanged)
    Q_PROPERTY(QString menuTitle READ menuTitle NOTIFY menuChanged)
    Q_PROPERTY(qreal menuX READ menuX NOTIFY menuChanged)

public:
    explicit SystemTray(QObject *parent = nullptr);

    // Become the session's tray host (and its watcher, if no one else is).
    void start();

    QVariantList items() const;
    QVariantList menu() const { return m_menu; }
    QString menuKey() const { return m_menuKey; }
    QString menuTitle() const { return m_menuTitle; }
    qreal menuX() const { return m_menuX; }

    // Click on the icon: the app's main action, or its menu when the item is
    // only a menu (or the app has no main action). x: the icon's center.
    Q_INVOKABLE void activate(const QString &key, qreal x);
    // Middle click.
    Q_INVOKABLE void secondaryActivate(const QString &key, qreal x);
    // Right click: the item's menu.
    Q_INVOKABLE void openMenu(const QString &key, qreal x);
    Q_INVOKABLE void scroll(const QString &key, int delta, bool horizontal);
    // A menu entry was picked.
    Q_INVOKABLE void menuClicked(int id);
    Q_INVOKABLE void menuClosed();

    QImage iconImage(const QString &key, const QSize &size) const;
    QImage menuIconImage(int id, const QSize &size) const;

signals:
    void itemsChanged();
    void menuChanged();
    // The menu is ready to show (the shell opens the "tray-menu" panel).
    void menuRequested();

private slots:
    void itemRegistered(const QString &key);
    void itemUnregistered(const QString &key);
    void menuLayoutUpdated();

private:
    void registerWithWatcher();
    void loadMenu();
    TrayItem *find(const QString &key) const;
    QVariantList parseMenu(const class QDBusArgument &arg, bool *anyVisible);

    QList<TrayItem *> m_items;
    TrayWatcher *m_ownWatcher = nullptr;
    QDBusServiceWatcher *m_watcherWatcher = nullptr;
    QDBusServiceWatcher *m_itemWatcher = nullptr;
    QString m_hostService;

    QVariantList m_menu;
    QString m_menuKey, m_menuTitle, m_menuService, m_menuPath;
    qreal m_menuX = 0;
    QHash<int, QImage> m_menuIcons;
    bool m_menuWanted = false;        // show once the layout arrives
};

// image://tray/<key>/<serial> and image://tray/menu/<id>/<n>
class TrayIconProvider : public QQuickImageProvider
{
public:
    explicit TrayIconProvider(SystemTray *tray)
        : QQuickImageProvider(QQuickImageProvider::Image), m_tray(tray) {}
    QImage requestImage(const QString &id, QSize *size, const QSize &requested) override;

private:
    QPointer<SystemTray> m_tray;
};
