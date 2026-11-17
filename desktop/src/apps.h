// The installed apps, read from .desktop files in the XDG applications
// directories, for the launcher. Reloads when those directories change.
#pragma once

#include <QFileSystemWatcher>
#include <QObject>
#include <QTimer>
#include <QVariantList>

class AppIndex : public QObject
{
    Q_OBJECT
    // Each entry: {id, name, genericName, comment, keywords, icon, exec, terminal}
    Q_PROPERTY(QVariantList apps READ apps NOTIFY appsChanged)

public:
    explicit AppIndex(QObject *parent = nullptr);

    QVariantList apps() const { return m_apps; }

    // Starts the app with this desktop file id (e.g. "org.kde.dolphin.desktop").
    Q_INVOKABLE bool launch(const QString &id);

    // The Exec line with its field codes (%f, %U, ...) removed, split into arguments.
    static QStringList commandFor(const QString &exec);

signals:
    void appsChanged();

private:
    void reload();

    QVariantList m_apps;
    QFileSystemWatcher m_watcher;
    QTimer m_reload;
};
