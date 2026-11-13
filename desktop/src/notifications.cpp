#include "notifications.h"

#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QRegularExpression>
#include <QUrl>

namespace {
constexpr int kDefaultTimeoutMs = 6000;
constexpr int kMaxKept = 50;

enum Reason : uint { Expired = 1, Dismissed = 2, Closed = 3 };

// Bodies may carry a little markup (spec: b, i, u, a, img). QML shows them as
// StyledText; drop anything else.
QString cleanBody(QString body)
{
    static const QRegularExpression tags(QStringLiteral("<(?!/?(b|i|u|a|br)\\b)[^>]*>"),
                                         QRegularExpression::CaseInsensitiveOption);
    body.remove(tags);
    body.replace(QLatin1Char('\n'), QLatin1String("<br>"));
    return body;
}
} // namespace

NotificationServer::NotificationServer(QObject *parent)
    : QObject(parent)
{
}

bool NotificationServer::registerOnBus()
{
    QDBusConnection bus = QDBusConnection::sessionBus();
    if (!bus.isConnected())
        return false;
    if (!bus.registerObject(QStringLiteral("/org/freedesktop/Notifications"), this,
                            QDBusConnection::ExportAllSlots | QDBusConnection::ExportAllSignals))
        return false;
    const auto reply = bus.interface()->registerService(QStringLiteral("org.freedesktop.Notifications"),
                                                        QDBusConnectionInterface::ReplaceExistingService,
                                                        QDBusConnectionInterface::AllowReplacement);
    return reply.isValid() && reply.value() == QDBusConnectionInterface::ServiceRegistered;
}

QVariantList NotificationServer::popups() const
{
    QVariantList out;
    for (uint id : m_order) {
        const Item &it = m_items[id];
        if (it.popup)
            out.append(it.data);
    }
    return out;
}

QVariantList NotificationServer::history() const
{
    QVariantList out;
    for (uint id : m_order)
        out.append(m_items[id].data);
    return out;
}

void NotificationServer::setDoNotDisturb(bool on)
{
    if (on == m_dnd)
        return;
    m_dnd = on;
    emit doNotDisturbChanged();
}

QStringList NotificationServer::GetCapabilities()
{
    return {QStringLiteral("body"), QStringLiteral("body-markup"), QStringLiteral("body-hyperlinks"),
            QStringLiteral("actions"), QStringLiteral("persistence")};
}

QString NotificationServer::GetServerInformation(QString &vendor, QString &version, QString &spec_version)
{
    vendor = QStringLiteral("MpireOS");
    version = QStringLiteral("0.3");
    spec_version = QStringLiteral("1.2");
    return QStringLiteral("Mpire Desktop");
}

uint NotificationServer::Notify(const QString &app_name, uint replaces_id, const QString &app_icon,
                                const QString &summary, const QString &body, const QStringList &actions,
                                const QVariantMap &hints, int expire_timeout)
{
    const uint id = (replaces_id && m_items.contains(replaces_id)) ? replaces_id : m_next++;
    Item &it = m_items[id];
    if (it.timer) {
        it.timer->deleteLater();
        it.timer = nullptr;
    }
    m_order.removeAll(id);
    m_order.prepend(id);

    QVariantList actionList;
    for (int i = 0; i + 1 < actions.size(); i += 2)
        actionList.append(QVariantMap{{"key", actions[i]}, {"label", actions[i + 1]}});

    QString icon = app_icon;
    if (icon.startsWith(QLatin1String("file://")))
        icon = QUrl(icon).toLocalFile();
    if (icon.isEmpty())
        icon = hints.value(QStringLiteral("desktop-entry")).toString();
    if (icon.isEmpty())
        icon = hints.value(QStringLiteral("image-path")).toString();
    const int urgency = hints.value(QStringLiteral("urgency"), 1).toInt();

    it.data = QVariantMap{
        {"id", id},
        {"appName", app_name.isEmpty() ? tr("Notification") : app_name},
        {"appIcon", icon},
        {"summary", summary},
        {"body", cleanBody(body)},
        {"actions", actionList},
        {"urgency", urgency},
        {"time", QDateTime::currentDateTime()},
    };
    it.popup = !m_dnd || urgency >= 2;

    // Critical notifications stay until dismissed; 0 means "never expire".
    const int timeout = expire_timeout < 0 ? kDefaultTimeoutMs : expire_timeout;
    if (it.popup && urgency < 2 && timeout > 0) {
        it.timer = new QTimer(this);
        it.timer->setSingleShot(true);
        connect(it.timer, &QTimer::timeout, this, [this, id] { expire(id); });
        it.timer->start(timeout);
    }

    while (m_order.size() > kMaxKept)
        close(m_order.last(), Expired);
    ++m_unread;
    emit popupsChanged();
    emit historyChanged();
    return id;
}

uint NotificationServer::post(const QString &appName, const QString &icon, const QString &summary, const QString &body)
{
    return Notify(appName, 0, icon, summary, body, {}, {}, -1);
}

void NotificationServer::expire(uint id)
{
    // Expired popups leave the screen but stay in the list until dismissed.
    auto it = m_items.find(id);
    if (it == m_items.end())
        return;
    if (it->timer) {
        it->timer->deleteLater();
        it->timer = nullptr;
    }
    it->popup = false;
    emit popupsChanged();
}

void NotificationServer::hidePopup(uint id)
{
    expire(id);
}

void NotificationServer::close(uint id, uint reason)
{
    auto it = m_items.find(id);
    if (it == m_items.end())
        return;
    if (it->timer)
        it->timer->deleteLater();
    m_items.erase(it);
    m_order.removeAll(id);
    emit NotificationClosed(id, reason);
}

void NotificationServer::CloseNotification(uint id)
{
    close(id, Closed);
    emit popupsChanged();
    emit historyChanged();
}

void NotificationServer::dismiss(uint id)
{
    close(id, Dismissed);
    m_unread = qMin(m_unread, int(m_order.size()));
    emit popupsChanged();
    emit historyChanged();
}

void NotificationServer::invoke(uint id, const QString &actionKey)
{
    if (!m_items.contains(id))
        return;
    emit ActionInvoked(id, actionKey);
    dismiss(id);
}

void NotificationServer::clearAll()
{
    const QList<uint> ids = m_order;
    for (uint id : ids)
        close(id, Dismissed);
    m_unread = 0;
    emit popupsChanged();
    emit historyChanged();
}

void NotificationServer::markRead()
{
    if (m_unread == 0)
        return;
    m_unread = 0;
    emit historyChanged();
}
