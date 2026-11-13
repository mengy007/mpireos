// The link between Mpire Setup's pages and the real machine: which disks exist,
// and running the privileged backend (mpire-install) with the user's plan.
#pragma once

#include <QObject>
#include <QProcess>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>

class SystemBridge : public QObject
{
    Q_OBJECT
    // True on the MpireOS live ISO. Elsewhere the installer runs as a demo and never
    // touches a disk.
    Q_PROPERTY(bool live READ live CONSTANT)
    Q_PROPERTY(QVariantList disks READ disks NOTIFY disksChanged)
    Q_PROPERTY(QString timezone READ timezone CONSTANT)
    Q_PROPERTY(QString logPath READ logPath CONSTANT)

public:
    explicit SystemBridge(bool forceDemo, QObject *parent = nullptr);

    bool live() const { return m_live; }
    QVariantList disks() const { return m_disks; }
    QString timezone() const;
    QString logPath() const { return QStringLiteral("/var/log/mpire-install.log"); }

    Q_INVOKABLE void refreshDisks();
    // Writes the plan to a private file and starts mpire-install as root.
    Q_INVOKABLE bool start(const QVariantMap &plan);
    Q_INVOKABLE void reboot();

signals:
    void disksChanged();
    // One JSON line from mpire-install: {"event": "step" | "substep" | "progress" | "done" | "error", ...}
    void event(const QVariantMap &event);
    // The backend exited. lastOutput holds its last non-JSON lines, for error messages.
    void finished(int exitCode, const QString &lastOutput);

private:
    void readOutput();
    QString bootDisk() const;

    bool m_live = false;
    QVariantList m_disks;
    QProcess m_process;
    QString m_planPath;
    QByteArray m_buffer;
    QStringList m_tail;
};
