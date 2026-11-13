// What the shell's QML can ask of the system: launch things, and read a few
// live values. Exposed to QML as the context property `shellApi`.
#pragma once

#include <QObject>
#include <QTimer>

class ShellApi : public QObject
{
    Q_OBJECT
    Q_PROPERTY(int battery READ battery NOTIFY batteryChanged)   // percent, -1 without a battery

public:
    explicit ShellApi(QObject *parent = nullptr);

    int battery() const { return m_battery; }

    // Runs a command line such as "kcmshell6 kcm_networkmanagement", detached.
    Q_INVOKABLE void launch(const QString &command);

signals:
    void batteryChanged();

private:
    void readBattery();

    int m_battery = -1;
    QTimer m_poll;
};
