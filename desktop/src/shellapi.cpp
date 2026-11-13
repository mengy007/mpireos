#include "shellapi.h"

#include <QDir>
#include <QFile>
#include <QProcess>

ShellApi::ShellApi(QObject *parent)
    : QObject(parent)
{
    readBattery();
    m_poll.setInterval(30000);
    connect(&m_poll, &QTimer::timeout, this, &ShellApi::readBattery);
    m_poll.start();
}

void ShellApi::launch(const QString &command)
{
    QStringList args = QProcess::splitCommand(command);
    if (args.isEmpty())
        return;
    const QString program = args.takeFirst();
    if (!QProcess::startDetached(program, args))
        qWarning("mpire-shell: could not start %s", qPrintable(command));
}

void ShellApi::readBattery()
{
    int level = -1;
    const QDir supplies(QStringLiteral("/sys/class/power_supply"));
    for (const QString &name : supplies.entryList({QStringLiteral("BAT*")}, QDir::Dirs | QDir::System)) {
        QFile f(supplies.filePath(name + QStringLiteral("/capacity")));
        if (f.open(QIODevice::ReadOnly)) {
            bool ok = false;
            const int v = f.readAll().trimmed().toInt(&ok);
            if (ok) {
                level = v;
                break;
            }
        }
    }
    if (level != m_battery) {
        m_battery = level;
        emit batteryChanged();
    }
}
