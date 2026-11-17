#include "tray.h"

#include <QCoreApplication>
#include <QDBusArgument>
#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusMessage>
#include <QDBusMetaType>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDBusServiceWatcher>
#include <QDBusVariant>
#include <QDateTime>
#include <QDir>
#include <QDirIterator>
#include <QFileInfo>
#include <QPainter>
#include <QRegularExpression>
#include <QUrl>
#include <QtEndian>

namespace {

const QString kWatcherService = QStringLiteral("org.kde.StatusNotifierWatcher");
const QString kWatcherPath = QStringLiteral("/StatusNotifierWatcher");
const QString kWatcherIface = QStringLiteral("org.kde.StatusNotifierWatcher");
const QString kItemIface = QStringLiteral("org.kde.StatusNotifierItem");
const QString kMenuIface = QStringLiteral("com.canonical.dbusmenu");
const QString kPropsIface = QStringLiteral("org.freedesktop.DBus.Properties");

// "busname/object/path" or "busname" (then the path is /StatusNotifierItem).
void splitKey(const QString &key, QString *service, QString *path)
{
    const int slash = key.indexOf(QLatin1Char('/'));
    *service = slash < 0 ? key : key.left(slash);
    *path = slash < 0 ? QStringLiteral("/StatusNotifierItem") : key.mid(slash);
}

// a(iiay): ARGB32 images in network byte order.
QList<QImage> readPixmaps(const QDBusArgument &arg)
{
    QList<QImage> out;
    if (arg.currentType() != QDBusArgument::ArrayType)
        return out;
    arg.beginArray();
    while (!arg.atEnd()) {
        int w = 0, h = 0;
        QByteArray data;
        arg.beginStructure();
        arg >> w >> h >> data;
        arg.endStructure();
        if (w <= 0 || h <= 0 || data.size() < w * h * 4)
            continue;
        QImage img(w, h, QImage::Format_ARGB32);
        const auto *src = reinterpret_cast<const quint32 *>(data.constData());
        for (int y = 0; y < h; ++y) {
            auto *line = reinterpret_cast<quint32 *>(img.scanLine(y));
            for (int x = 0; x < w; ++x)
                line[x] = qFromBigEndian(src[y * w + x]);
        }
        out << img;
    }
    arg.endArray();
    return out;
}

QList<QImage> pixmapsFrom(const QVariant &v)
{
    if (v.canConvert<QDBusArgument>())
        return readPixmaps(v.value<QDBusArgument>());
    return {};
}

// The closest image at least as big as `size`, else the biggest.
QImage pick(const QList<QImage> &images, const QSize &size)
{
    QImage best;
    for (const QImage &img : images) {
        if (best.isNull()) { best = img; continue; }
        const bool bigEnough = img.width() >= size.width();
        const bool bestBigEnough = best.width() >= size.width();
        if ((bigEnough && (!bestBigEnough || img.width() < best.width())) || (!bestBigEnough && img.width() > best.width()))
            best = img;
    }
    return best;
}

// An icon by name: a file path, a file in the app's own icon folder, or the theme.
QIcon iconByName(const QString &name, const QString &themePath)
{
    if (name.isEmpty())
        return {};
    if (name.startsWith(QLatin1Char('/')))
        return QIcon(name);
    if (!themePath.isEmpty() && QDir(themePath).exists()) {
        // Apps such as Steam ship their tray icons in their own folder,
        // either loose or in an icon-theme layout.
        for (const QString &ext : {QStringLiteral(".svg"), QStringLiteral(".png"), QStringLiteral(".xpm")}) {
            const QString loose = QDir(themePath).filePath(name + ext);
            if (QFileInfo::exists(loose))
                return QIcon(loose);
        }
        QDirIterator it(themePath, {name + QStringLiteral(".svg"), name + QStringLiteral(".png")}, QDir::Files,
                        QDirIterator::Subdirectories);
        QIcon icon;
        while (it.hasNext())
            icon.addFile(it.next());
        if (!icon.isNull())
            return icon;
    }
    return QIcon::fromTheme(name);
}

QString plain(QString text)
{
    // Tooltips may be (simple) HTML.
    text.remove(QRegularExpression(QStringLiteral("<[^>]*>")));
    return text.replace(QStringLiteral("&amp;"), QStringLiteral("&")).trimmed();
}

} // namespace

// ---------------------------------------------------------------------------
// TrayWatcher

TrayWatcher::TrayWatcher(QObject *parent)
    : QObject(parent)
    , m_serviceWatcher(new QDBusServiceWatcher(this))
{
    m_serviceWatcher->setConnection(QDBusConnection::sessionBus());
    m_serviceWatcher->setWatchMode(QDBusServiceWatcher::WatchForUnregistration);
    connect(m_serviceWatcher, &QDBusServiceWatcher::serviceUnregistered, this, &TrayWatcher::serviceGone);
}

void TrayWatcher::RegisterStatusNotifierItem(const QString &serviceOrPath)
{
    // Apps pass their bus name, a well-known name, or (Ayatana) an object path
    // on their own connection.
    QString service = serviceOrPath, path = QStringLiteral("/StatusNotifierItem");
    if (serviceOrPath.startsWith(QLatin1Char('/'))) {
        service = calledFromDBus() ? message().service() : QString();
        path = serviceOrPath;
    }
    if (service.isEmpty())
        return;
    const QString key = service + path;
    if (m_items.contains(key))
        return;
    m_items << key;
    m_serviceWatcher->addWatchedService(service);
    emit StatusNotifierItemRegistered(key);
}

void TrayWatcher::RegisterStatusNotifierHost(const QString &service)
{
    if (m_hosts.contains(service))
        return;
    m_hosts << service;
    m_serviceWatcher->addWatchedService(service);
    emit StatusNotifierHostRegistered();
}

void TrayWatcher::serviceGone(const QString &service)
{
    for (const QString &key : QStringList(m_items)) {
        QString s, p;
        splitKey(key, &s, &p);
        if (s == service) {
            m_items.removeAll(key);
            emit StatusNotifierItemUnregistered(key);
        }
    }
    if (m_hosts.removeAll(service) > 0)
        emit StatusNotifierHostUnregistered();
    m_serviceWatcher->removeWatchedService(service);
}

// ---------------------------------------------------------------------------
// TrayItem

TrayItem::TrayItem(const QString &k, QObject *parent)
    : QObject(parent)
    , key(k)
{
    splitKey(key, &service, &path);
    m_debounce.setSingleShot(true);
    m_debounce.setInterval(60);
    connect(&m_debounce, &QTimer::timeout, this, [this] {
        QDBusMessage get = QDBusMessage::createMethodCall(service, path, kPropsIface, QStringLiteral("GetAll"));
        get << kItemIface;
        auto *call = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(get, 5000), this);
        connect(call, &QDBusPendingCallWatcher::finished, this, &TrayItem::load);
    });
    QDBusConnection bus = QDBusConnection::sessionBus();
    for (const char *sig : {"NewTitle", "NewIcon", "NewAttentionIcon", "NewOverlayIcon", "NewToolTip", "NewStatus", "NewMenu"})
        bus.connect(service, path, kItemIface, QString::fromLatin1(sig), this, SLOT(refresh()));
}

void TrayItem::refresh()
{
    m_debounce.start();
}

void TrayItem::load(QDBusPendingCallWatcher *call)
{
    call->deleteLater();
    QDBusPendingReply<QVariantMap> reply = *call;
    if (reply.isError()) {
        qWarning("mpire-shell: tray item %s: %s", qPrintable(key), qPrintable(reply.error().message()));
        return;
    }
    const QVariantMap p = reply.value();
    id = p.value(QStringLiteral("Id")).toString();
    title = p.value(QStringLiteral("Title")).toString();
    status = p.value(QStringLiteral("Status")).toString();
    category = p.value(QStringLiteral("Category")).toString();
    iconName = p.value(QStringLiteral("IconName")).toString();
    attentionIconName = p.value(QStringLiteral("AttentionIconName")).toString();
    iconThemePath = p.value(QStringLiteral("IconThemePath")).toString();
    pixmaps = pixmapsFrom(p.value(QStringLiteral("IconPixmap")));
    attentionPixmaps = pixmapsFrom(p.value(QStringLiteral("AttentionIconPixmap")));
    itemIsMenu = p.value(QStringLiteral("ItemIsMenu")).toBool();
    menuPath = p.value(QStringLiteral("Menu")).value<QDBusObjectPath>().path();
    if (menuPath == QLatin1String("/"))
        menuPath.clear();

    // ToolTip: (s icon, a(iiay) pixmaps, s title, s text)
    tooltip.clear();
    const QVariant tip = p.value(QStringLiteral("ToolTip"));
    if (tip.canConvert<QDBusArgument>()) {
        const QDBusArgument arg = tip.value<QDBusArgument>();
        QString tipIcon, tipTitle, tipText;
        arg.beginStructure();
        arg >> tipIcon;
        readPixmaps(arg);
        arg >> tipTitle >> tipText;
        arg.endStructure();
        tooltip = plain(tipText.isEmpty() ? tipTitle : tipTitle.isEmpty() ? tipText : tipTitle + QStringLiteral(" — ") + tipText);
    }
    loaded = true;
    ++serial;
    emit changed();
}

QImage TrayItem::image(const QSize &size) const
{
    const bool attention = status == QLatin1String("NeedsAttention");
    const QString name = attention && !attentionIconName.isEmpty() ? attentionIconName : iconName;
    const QList<QImage> &images = attention && !attentionPixmaps.isEmpty() ? attentionPixmaps : pixmaps;
    // Pixmaps are the app's exact artwork; names go through the icon theme.
    const QIcon icon = iconByName(name, iconThemePath);
    if (!icon.isNull()) {
        const QImage img = icon.pixmap(size).toImage();
        if (!img.isNull())
            return img;
    }
    const QImage img = pick(images, size);
    if (!img.isNull())
        return img.scaled(size, Qt::KeepAspectRatio, Qt::SmoothTransformation);
    return QIcon::fromTheme(QStringLiteral("application-x-executable")).pixmap(size).toImage();
}

QVariantMap TrayItem::toVariant() const
{
    return {
        {QStringLiteral("key"), key},
        {QStringLiteral("id"), id},
        {QStringLiteral("title"), title.isEmpty() ? id : title},
        {QStringLiteral("tooltip"), tooltip},
        {QStringLiteral("status"), status},
        {QStringLiteral("category"), category},
        {QStringLiteral("attention"), status == QLatin1String("NeedsAttention")},
        {QStringLiteral("icon"), QStringLiteral("image://tray/item/%1/%2")
                                     .arg(QString::fromLatin1(QUrl::toPercentEncoding(key)), QString::number(serial))},
    };
}

// ---------------------------------------------------------------------------
// SystemTray

SystemTray::SystemTray(QObject *parent)
    : QObject(parent)
{
}

void SystemTray::start()
{
    QDBusConnection bus = QDBusConnection::sessionBus();

    // Items go away when their app quits, even if the watcher is slow to say so.
    m_itemWatcher = new QDBusServiceWatcher(this);
    m_itemWatcher->setConnection(bus);
    m_itemWatcher->setWatchMode(QDBusServiceWatcher::WatchForUnregistration);
    connect(m_itemWatcher, &QDBusServiceWatcher::serviceUnregistered, this, [this](const QString &service) {
        for (TrayItem *item : QList<TrayItem *>(m_items))
            if (item->service == service)
                itemUnregistered(item->key);
        m_itemWatcher->removeWatchedService(service);
    });

    // Run the watcher ourselves when no one else does.
    if (!bus.interface()->isServiceRegistered(kWatcherService)) {
        auto *watcher = new TrayWatcher(this);
        if (bus.registerObject(kWatcherPath, watcher, QDBusConnection::ExportAllSlots | QDBusConnection::ExportAllSignals
                                                          | QDBusConnection::ExportAllProperties)
            && bus.registerService(kWatcherService)) {
            m_ownWatcher = watcher;
            connect(watcher, &TrayWatcher::StatusNotifierItemRegistered, this, &SystemTray::itemRegistered);
            connect(watcher, &TrayWatcher::StatusNotifierItemUnregistered, this, &SystemTray::itemUnregistered);
            qInfo("mpire-shell: running the tray's StatusNotifierWatcher");
        } else {
            bus.unregisterObject(kWatcherPath);
            delete watcher;
        }
    }

    m_hostService = QStringLiteral("org.kde.StatusNotifierHost-%1").arg(QCoreApplication::applicationPid());
    bus.registerService(m_hostService);

    if (m_ownWatcher) {
        m_ownWatcher->RegisterStatusNotifierHost(m_hostService);
        return;
    }
    bus.connect(kWatcherService, kWatcherPath, kWatcherIface, QStringLiteral("StatusNotifierItemRegistered"),
                this, SLOT(itemRegistered(QString)));
    bus.connect(kWatcherService, kWatcherPath, kWatcherIface, QStringLiteral("StatusNotifierItemUnregistered"),
                this, SLOT(itemUnregistered(QString)));
    // When the watcher (re)starts, introduce ourselves again.
    m_watcherWatcher = new QDBusServiceWatcher(kWatcherService, bus, QDBusServiceWatcher::WatchForRegistration, this);
    connect(m_watcherWatcher, &QDBusServiceWatcher::serviceRegistered, this, &SystemTray::registerWithWatcher);
    registerWithWatcher();
}

void SystemTray::registerWithWatcher()
{
    QDBusConnection bus = QDBusConnection::sessionBus();
    QDBusMessage reg = QDBusMessage::createMethodCall(kWatcherService, kWatcherPath, kWatcherIface,
                                                      QStringLiteral("RegisterStatusNotifierHost"));
    reg << m_hostService;
    bus.asyncCall(reg);

    QDBusMessage get = QDBusMessage::createMethodCall(kWatcherService, kWatcherPath, kPropsIface, QStringLiteral("Get"));
    get << kWatcherIface << QStringLiteral("RegisteredStatusNotifierItems");
    auto *call = new QDBusPendingCallWatcher(bus.asyncCall(get, 5000), this);
    connect(call, &QDBusPendingCallWatcher::finished, this, [this](QDBusPendingCallWatcher *c) {
        c->deleteLater();
        QDBusPendingReply<QDBusVariant> reply = *c;
        if (reply.isError()) {
            qWarning("mpire-shell: no StatusNotifierWatcher: %s", qPrintable(reply.error().message()));
            return;
        }
        const QStringList keys = reply.value().variant().toStringList();
        for (TrayItem *item : QList<TrayItem *>(m_items))
            if (!keys.contains(item->key))
                itemUnregistered(item->key);
        for (const QString &key : keys)
            itemRegistered(key);
    });
}

TrayItem *SystemTray::find(const QString &key) const
{
    for (TrayItem *item : m_items)
        if (item->key == key)
            return item;
    return nullptr;
}

void SystemTray::itemRegistered(const QString &key)
{
    if (key.isEmpty() || find(key))
        return;
    auto *item = new TrayItem(key, this);
    m_items.prepend(item);               // newest on the left, as on macOS
    m_itemWatcher->addWatchedService(item->service);
    connect(item, &TrayItem::changed, this, &SystemTray::itemsChanged);
    item->refresh();
}

void SystemTray::itemUnregistered(const QString &key)
{
    TrayItem *item = find(key);
    if (!item)
        return;
    m_items.removeAll(item);
    item->deleteLater();
    if (m_menuKey == key) {
        m_menu.clear();
        m_menuKey.clear();
        emit menuChanged();
    }
    emit itemsChanged();
}

QVariantList SystemTray::items() const
{
    QVariantList out;
    for (const TrayItem *item : m_items) {
        // Passive items have nothing to say right now (the spec lets hosts hide them).
        if (!item->loaded || item->status == QLatin1String("Passive"))
            continue;
        out << item->toVariant();
    }
    return out;
}

void SystemTray::activate(const QString &key, qreal x)
{
    TrayItem *item = find(key);
    if (!item)
        return;
    if (item->itemIsMenu && !item->menuPath.isEmpty()) {
        openMenu(key, x);
        return;
    }
    QDBusMessage call = QDBusMessage::createMethodCall(item->service, item->path, kItemIface, QStringLiteral("Activate"));
    call << int(x) << int(0);
    auto *w = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(call, 3000), this);
    const QString k = key;
    connect(w, &QDBusPendingCallWatcher::finished, this, [this, k, x](QDBusPendingCallWatcher *c) {
        c->deleteLater();
        // Ayatana (libappindicator) items have no main action: show the menu.
        if (c->isError())
            openMenu(k, x);
    });
}

void SystemTray::secondaryActivate(const QString &key, qreal x)
{
    if (TrayItem *item = find(key)) {
        QDBusMessage call = QDBusMessage::createMethodCall(item->service, item->path, kItemIface,
                                                           QStringLiteral("SecondaryActivate"));
        call << int(x) << int(0);
        QDBusConnection::sessionBus().asyncCall(call);
    }
}

void SystemTray::scroll(const QString &key, int delta, bool horizontal)
{
    if (TrayItem *item = find(key)) {
        QDBusMessage call = QDBusMessage::createMethodCall(item->service, item->path, kItemIface, QStringLiteral("Scroll"));
        call << delta << (horizontal ? QStringLiteral("horizontal") : QStringLiteral("vertical"));
        QDBusConnection::sessionBus().asyncCall(call);
    }
}

void SystemTray::openMenu(const QString &key, qreal x)
{
    TrayItem *item = find(key);
    if (!item)
        return;
    if (item->menuPath.isEmpty()) {
        // No exported menu: let the app show its own.
        QDBusMessage call = QDBusMessage::createMethodCall(item->service, item->path, kItemIface, QStringLiteral("ContextMenu"));
        call << int(x) << int(0);
        QDBusConnection::sessionBus().asyncCall(call);
        return;
    }
    QDBusConnection bus = QDBusConnection::sessionBus();
    if (!m_menuPath.isEmpty())
        bus.disconnect(m_menuService, m_menuPath, kMenuIface, QStringLiteral("LayoutUpdated"), this, SLOT(menuLayoutUpdated()));
    m_menuKey = key;
    m_menuTitle = item->title.isEmpty() ? item->id : item->title;
    m_menuService = item->service;
    m_menuPath = item->menuPath;
    m_menuX = x;
    m_menuWanted = true;
    bus.connect(m_menuService, m_menuPath, kMenuIface, QStringLiteral("LayoutUpdated"), this, SLOT(menuLayoutUpdated()));

    // Tell the app the menu is about to open (some fill it in only then), then read it.
    QDBusMessage about = QDBusMessage::createMethodCall(m_menuService, m_menuPath, kMenuIface, QStringLiteral("AboutToShow"));
    about << 0;
    auto *w = new QDBusPendingCallWatcher(bus.asyncCall(about, 1000), this);
    connect(w, &QDBusPendingCallWatcher::finished, this, [this](QDBusPendingCallWatcher *c) {
        c->deleteLater();
        loadMenu();
    });
    QDBusMessage opened = QDBusMessage::createMethodCall(m_menuService, m_menuPath, kMenuIface, QStringLiteral("Event"));
    opened << 0 << QStringLiteral("opened") << QVariant::fromValue(QDBusVariant(QString())) << uint(QDateTime::currentSecsSinceEpoch());
    bus.asyncCall(opened);
}

void SystemTray::menuLayoutUpdated()
{
    if (!m_menuKey.isEmpty())
        loadMenu();
}

void SystemTray::loadMenu()
{
    QDBusMessage get = QDBusMessage::createMethodCall(m_menuService, m_menuPath, kMenuIface, QStringLiteral("GetLayout"));
    get << 0 << -1 << QStringList();
    auto *w = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(get, 3000), this);
    const QString key = m_menuKey;
    connect(w, &QDBusPendingCallWatcher::finished, this, [this, key](QDBusPendingCallWatcher *c) {
        c->deleteLater();
        if (key != m_menuKey)
            return;
        const QDBusMessage reply = c->reply();
        if (reply.type() != QDBusMessage::ReplyMessage || reply.arguments().size() < 2) {
            qWarning("mpire-shell: tray menu of %s: %s", qPrintable(key), qPrintable(reply.errorMessage()));
            return;
        }
        m_menuIcons.clear();
        const QDBusArgument layout = reply.arguments().at(1).value<QDBusArgument>();
        // (i id, a{sv} properties, av children): the root's children are the menu.
        int rootId = 0;
        QVariantMap rootProps;
        layout.beginStructure();
        layout >> rootId >> rootProps;
        bool any = false;
        m_menu = parseMenu(layout, &any);
        layout.endStructure();
        emit menuChanged();
        if (m_menuWanted) {
            m_menuWanted = false;
            emit menuRequested();
        }
    });
}

// av of (ia{sv}av)
QVariantList SystemTray::parseMenu(const QDBusArgument &arg, bool *anyVisible)
{
    QVariantList out;
    arg.beginArray();
    while (!arg.atEnd()) {
        QDBusVariant wrapped;
        arg >> wrapped;
        const QDBusArgument child = wrapped.variant().value<QDBusArgument>();
        int id = 0;
        QVariantMap props;
        child.beginStructure();
        child >> id >> props;
        bool childVisible = false;
        const QVariantList children = parseMenu(child, &childVisible);
        child.endStructure();

        if (!props.value(QStringLiteral("visible"), true).toBool())
            continue;
        *anyVisible = true;
        QString label = props.value(QStringLiteral("label")).toString();
        // "_" marks the access key; "__" is a real underscore.
        label.replace(QStringLiteral("__"), QStringLiteral("\x01"));
        label.remove(QLatin1Char('_'));
        label.replace(QStringLiteral("\x01"), QStringLiteral("_"));
        const QString toggle = props.value(QStringLiteral("toggle-type")).toString();
        QString icon;
        const QByteArray data = props.value(QStringLiteral("icon-data")).toByteArray();
        if (!data.isEmpty()) {
            QImage img;
            if (img.loadFromData(data)) {
                m_menuIcons.insert(id, img);
                icon = QStringLiteral("image://tray/menu/%1/%2").arg(id).arg(m_menuIcons.size());
            }
        } else if (!props.value(QStringLiteral("icon-name")).toString().isEmpty()) {
            icon = QStringLiteral("image://icon/") + QString::fromLatin1(QUrl::toPercentEncoding(props.value(QStringLiteral("icon-name")).toString()));
        }
        out << QVariantMap{
            {QStringLiteral("id"), id},
            {QStringLiteral("label"), label},
            {QStringLiteral("enabled"), props.value(QStringLiteral("enabled"), true).toBool()},
            {QStringLiteral("separator"), props.value(QStringLiteral("type")).toString() == QLatin1String("separator")},
            {QStringLiteral("checkable"), !toggle.isEmpty()},
            {QStringLiteral("radio"), toggle == QLatin1String("radio")},
            {QStringLiteral("checked"), props.value(QStringLiteral("toggle-state")).toInt() == 1},
            {QStringLiteral("icon"), icon},
            {QStringLiteral("submenu"), children},
        };
    }
    arg.endArray();
    // No separators at the ends, or two in a row.
    for (int i = out.size() - 1; i >= 0; --i) {
        const bool sep = out[i].toMap().value(QStringLiteral("separator")).toBool();
        const bool prevSep = i > 0 && out[i - 1].toMap().value(QStringLiteral("separator")).toBool();
        if (sep && (i == out.size() - 1 || i == 0 || prevSep))
            out.removeAt(i);
    }
    return out;
}

void SystemTray::menuClicked(int id)
{
    if (m_menuPath.isEmpty())
        return;
    QDBusMessage ev = QDBusMessage::createMethodCall(m_menuService, m_menuPath, kMenuIface, QStringLiteral("Event"));
    ev << id << QStringLiteral("clicked") << QVariant::fromValue(QDBusVariant(0)) << uint(QDateTime::currentSecsSinceEpoch());
    QDBusConnection::sessionBus().asyncCall(ev);
}

void SystemTray::menuClosed()
{
    if (m_menuPath.isEmpty())
        return;
    QDBusConnection bus = QDBusConnection::sessionBus();
    QDBusMessage ev = QDBusMessage::createMethodCall(m_menuService, m_menuPath, kMenuIface, QStringLiteral("Event"));
    ev << 0 << QStringLiteral("closed") << QVariant::fromValue(QDBusVariant(QString())) << uint(QDateTime::currentSecsSinceEpoch());
    bus.asyncCall(ev);
    bus.disconnect(m_menuService, m_menuPath, kMenuIface, QStringLiteral("LayoutUpdated"), this, SLOT(menuLayoutUpdated()));
    m_menuPath.clear();
    m_menuKey.clear();
    m_menuWanted = false;
    emit menuChanged();
}

QImage SystemTray::iconImage(const QString &key, const QSize &size) const
{
    if (TrayItem *item = find(key))
        return item->image(size);
    return {};
}

QImage SystemTray::menuIconImage(int id, const QSize &size) const
{
    const QImage img = m_menuIcons.value(id);
    return img.isNull() ? img : img.scaled(size, Qt::KeepAspectRatio, Qt::SmoothTransformation);
}

// ---------------------------------------------------------------------------

QImage TrayIconProvider::requestImage(const QString &id, QSize *size, const QSize &requested)
{
    const QSize want = requested.isValid() && !requested.isEmpty() ? requested : QSize(32, 32);
    QImage img;
    const QStringList parts = id.split(QLatin1Char('/'));
    if (m_tray && parts.size() >= 2) {
        if (parts[0] == QLatin1String("item"))
            img = m_tray->iconImage(QUrl::fromPercentEncoding(parts[1].toUtf8()), want);
        else if (parts[0] == QLatin1String("menu"))
            img = m_tray->menuIconImage(parts[1].toInt(), want);
    }
    if (img.isNull()) {
        img = QImage(want, QImage::Format_ARGB32_Premultiplied);
        img.fill(Qt::transparent);
    }
    if (size)
        *size = img.size();
    return img;
}
