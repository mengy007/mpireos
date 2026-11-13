// What quick settings shows and changes: network, volume, brightness, battery,
// and the session/power actions. Uses the system's own tools (nmcli, wpctl,
// brightnessctl, systemctl), each run asynchronously.
#pragma once

#include <QObject>
#include <QTimer>
#include <functional>

class SystemStatus : public QObject
{
    Q_OBJECT
    Q_PROPERTY(int battery READ battery NOTIFY changed)            // percent, -1 without a battery
    Q_PROPERTY(bool charging READ charging NOTIFY changed)
    Q_PROPERTY(QString network READ network NOTIFY changed)        // connection name, "" when offline
    Q_PROPERTY(QString networkKind READ networkKind NOTIFY changed) // "wifi", "wired", or ""
    Q_PROPERTY(bool wifiEnabled READ wifiEnabled NOTIFY changed)
    Q_PROPERTY(bool hasWifi READ hasWifi NOTIFY changed)
    Q_PROPERTY(int volume READ volume NOTIFY changed)              // 0-100, -1 without an audio output
    Q_PROPERTY(bool muted READ muted NOTIFY changed)
    Q_PROPERTY(int brightness READ brightness NOTIFY changed)      // 0-100, -1 without a backlight

public:
    explicit SystemStatus(QObject *parent = nullptr);

    int battery() const { return m_battery; }
    bool charging() const { return m_charging; }
    QString network() const { return m_network; }
    QString networkKind() const { return m_networkKind; }
    bool wifiEnabled() const { return m_wifiEnabled; }
    bool hasWifi() const { return m_hasWifi; }
    int volume() const { return m_volume; }
    bool muted() const { return m_muted; }
    int brightness() const { return m_brightness; }

    Q_INVOKABLE void refresh();
    Q_INVOKABLE void setWifiEnabled(bool on);
    Q_INVOKABLE void setVolume(int percent);
    Q_INVOKABLE void setMuted(bool on);
    Q_INVOKABLE void setBrightness(int percent);

    Q_INVOKABLE void lock();
    Q_INVOKABLE void logOut();
    Q_INVOKABLE void suspend();
    Q_INVOKABLE void restart();
    Q_INVOKABLE void powerOff();

signals:
    void changed();

private:
    void run(const QString &program, const QStringList &args,
             std::function<void(int, const QString &)> done = {});
    void readBattery();

    int m_battery = -1;
    bool m_charging = false;
    QString m_network;
    QString m_networkKind;
    bool m_wifiEnabled = false;
    bool m_hasWifi = false;
    int m_volume = -1;
    bool m_muted = false;
    int m_brightness = -1;
    QTimer m_poll;
};
