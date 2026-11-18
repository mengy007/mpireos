#include "workspaces.h"

#include <QDBusArgument>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDBusVariant>
#include <QVariantMap>

#include <algorithm>

namespace {

const QString kService = QStringLiteral("org.kde.KWin");
const QString kPath = QStringLiteral("/VirtualDesktopManager");
const QString kInterface = QStringLiteral("org.kde.KWin.VirtualDesktopManager");
const QString kProperties = QStringLiteral("org.freedesktop.DBus.Properties");

struct Desktop {
    uint position = 0;
    QString id;
    QString name;
};

// KWin's "desktops" property: a(uss), position, id, name.
QList<Desktop> readDesktops(const QVariant &value)
{
    QList<Desktop> out;
    const auto arg = value.value<QDBusArgument>();
    if (arg.currentType() != QDBusArgument::ArrayType)
        return out;
    arg.beginArray();
    while (!arg.atEnd()) {
        Desktop d;
        arg.beginStructure();
        arg >> d.position >> d.id >> d.name;
        arg.endStructure();
        out << d;
    }
    arg.endArray();
    std::sort(out.begin(), out.end(), [](const Desktop &a, const Desktop &b) { return a.position < b.position; });
    return out;
}

} // namespace

Workspaces::Workspaces(QObject *parent)
    : QObject(parent)
{
    QDBusConnection bus = QDBusConnection::sessionBus();
    bus.connect(kService, kPath, kInterface, QStringLiteral("currentChanged"), this, SLOT(onCurrentChanged(QString)));
    for (const char *signal : {"countChanged", "desktopCreated", "desktopRemoved", "desktopDataChanged", "rowsChanged"})
        bus.connect(kService, kPath, kInterface, QString::fromLatin1(signal), this, SLOT(onLayoutChanged()));
    refresh();
}

void Workspaces::refresh()
{
    QDBusMessage call = QDBusMessage::createMethodCall(kService, kPath, kProperties, QStringLiteral("GetAll"));
    call << kInterface;
    auto *watcher = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(call), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this](QDBusPendingCallWatcher *w) {
        w->deleteLater();
        QDBusPendingReply<QVariantMap> reply = *w;
        if (reply.isError())
            return;                       // no virtual desktop manager: no indicators
        const QVariantMap props = reply.value();
        QStringList ids, names;
        for (const Desktop &d : readDesktops(props.value(QStringLiteral("desktops")))) {
            ids << d.id;
            names << d.name;
        }
        const QString current = props.value(QStringLiteral("current")).toString();
        if (ids == m_ids && names == m_names && current == m_current)
            return;
        m_ids = ids;
        m_names = names;
        m_current = current;
        emit changed();
    });
}

void Workspaces::activate(int index)
{
    if (index < 0 || index >= m_ids.size() || m_ids.at(index) == m_current)
        return;
    QDBusMessage call = QDBusMessage::createMethodCall(kService, kPath, kProperties, QStringLiteral("Set"));
    call << kInterface << QStringLiteral("current") << QVariant::fromValue(QDBusVariant(m_ids.at(index)));
    QDBusConnection::sessionBus().asyncCall(call);
    // Show the switch right away; currentChanged confirms it.
    m_current = m_ids.at(index);
    emit changed();
}

void Workspaces::onCurrentChanged(const QString &id)
{
    if (id == m_current)
        return;
    m_current = id;
    if (!m_ids.contains(id))
        refresh();
    emit changed();
}

void Workspaces::onLayoutChanged()
{
    refresh();
}
