// Mpire Desktop's notification server: it owns org.freedesktop.Notifications on
// the session bus (the freedesktop.org Desktop Notifications spec, 1.2), so apps'
// notifications show as MpireOS popups and collect in the notification list.
#pragma once

#include <QDateTime>
#include <QHash>
#include <QObject>
#include <QStringList>
#include <QTimer>
#include <QVariantList>
#include <QVariantMap>

class NotificationServer : public QObject
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.freedesktop.Notifications")
    // Shown as popups now: [{id, appName, appIcon, summary, body, actions: [{key, label}], urgency, time}]
    Q_PROPERTY(QVariantList popups READ popups NOTIFY popupsChanged)
    // Everything not yet dismissed, newest first (same fields).
    Q_PROPERTY(QVariantList history READ history NOTIFY historyChanged)
    Q_PROPERTY(int unread READ unread NOTIFY historyChanged)
    // Popups stay quiet; notifications still collect in the list. Critical ones still show.
    Q_PROPERTY(bool doNotDisturb READ doNotDisturb WRITE setDoNotDisturb NOTIFY doNotDisturbChanged)

public:
    explicit NotificationServer(QObject *parent = nullptr);
    bool registerOnBus();     // false when another notification server already runs

    QVariantList popups() const;
    QVariantList history() const;
    int unread() const { return m_unread; }
    bool doNotDisturb() const { return m_dnd; }
    void setDoNotDisturb(bool on);

    // For QML
    Q_INVOKABLE void dismiss(uint id);            // closes it everywhere (reason 2: dismissed by the user)
    Q_INVOKABLE void hidePopup(uint id);          // leaves it in the list
    Q_INVOKABLE void invoke(uint id, const QString &actionKey);
    Q_INVOKABLE void clearAll();
    Q_INVOKABLE void markRead();
    // Adds a notification from inside the shell (and from tools/preview.py).
    Q_INVOKABLE uint post(const QString &appName, const QString &icon, const QString &summary, const QString &body);

public slots:
    // org.freedesktop.Notifications
    QStringList GetCapabilities();
    uint Notify(const QString &app_name, uint replaces_id, const QString &app_icon, const QString &summary,
                const QString &body, const QStringList &actions, const QVariantMap &hints, int expire_timeout);
    void CloseNotification(uint id);
    QString GetServerInformation(QString &vendor, QString &version, QString &spec_version);

signals:
    void NotificationClosed(uint id, uint reason);
    void ActionInvoked(uint id, const QString &action_key);

    void popupsChanged();
    void historyChanged();
    void doNotDisturbChanged();

private:
    struct Item {
        QVariantMap data;
        bool popup = false;
        QTimer *timer = nullptr;
    };
    void close(uint id, uint reason);
    void expire(uint id);

    QHash<uint, Item> m_items;
    QList<uint> m_order;           // newest first
    uint m_next = 1;
    int m_unread = 0;
    bool m_dnd = false;
};
