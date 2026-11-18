// Workspaces (virtual desktops) for the top bar's indicators: how many there
// are, which one is showing, and switching between them. Talks to the
// compositor's virtual desktop manager over D-Bus (KWin's
// org.kde.KWin.VirtualDesktopManager for now; mpire-compositor later).
#pragma once

#include <QObject>
#include <QStringList>

class Workspaces : public QObject
{
    Q_OBJECT
    Q_PROPERTY(int count READ count NOTIFY changed)
    Q_PROPERTY(int current READ current NOTIFY changed)        // 0-based, -1 before the first answer
    Q_PROPERTY(QStringList names READ names NOTIFY changed)

public:
    explicit Workspaces(QObject *parent = nullptr);

    int count() const { return m_ids.size(); }
    int current() const { return m_ids.indexOf(m_current); }
    QStringList names() const { return m_names; }

    Q_INVOKABLE void activate(int index);
    Q_INVOKABLE void refresh();

signals:
    void changed();

private slots:
    void onCurrentChanged(const QString &id);
    void onLayoutChanged();

private:
    QStringList m_ids;
    QStringList m_names;
    QString m_current;
};
