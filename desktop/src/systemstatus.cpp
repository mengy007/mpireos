#include "systemstatus.h"

#include <QDBusConnection>
#include <QDBusMessage>
#include <QDir>
#include <QFile>
#include <QProcess>
#include <QRegularExpression>

SystemStatus::SystemStatus(QObject *parent)
    : QObject(parent)
{
    m_poll.setInterval(15000);
    connect(&m_poll, &QTimer::timeout, this, &SystemStatus::refresh);
    m_poll.start();
    refresh();
}

void SystemStatus::run(const QString &program, const QStringList &args, std::function<void(int, const QString &)> done)
{
    auto *p = new QProcess(this);
    p->setProcessChannelMode(QProcess::SeparateChannels);
    connect(p, &QProcess::finished, this, [p, done](int code, QProcess::ExitStatus) {
        if (done)
            done(code, QString::fromUtf8(p->readAllStandardOutput()));
        p->deleteLater();
    });
    connect(p, &QProcess::errorOccurred, this, [p, done](QProcess::ProcessError e) {
        if (e == QProcess::FailedToStart) {        // tool not installed
            if (done)
                done(-1, {});
            p->deleteLater();
        }
    });
    p->start(program, args);
}

void SystemStatus::readBattery()
{
    int level = -1;
    bool charging = false;
    const QDir supplies(QStringLiteral("/sys/class/power_supply"));
    for (const QString &name : supplies.entryList({QStringLiteral("BAT*")}, QDir::Dirs | QDir::System)) {
        QFile cap(supplies.filePath(name + QStringLiteral("/capacity")));
        QFile status(supplies.filePath(name + QStringLiteral("/status")));
        if (cap.open(QIODevice::ReadOnly)) {
            bool ok = false;
            const int v = cap.readAll().trimmed().toInt(&ok);
            if (ok) {
                level = v;
                if (status.open(QIODevice::ReadOnly))
                    charging = status.readAll().trimmed() != "Discharging";
                break;
            }
        }
    }
    if (level != m_battery || charging != m_charging) {
        m_battery = level;
        m_charging = charging;
        emit changed();
    }
}

void SystemStatus::refresh()
{
    readBattery();

    // Network: the first connected device, preferring Wi-Fi.
    run(QStringLiteral("nmcli"), {QStringLiteral("-t"), QStringLiteral("-f"), QStringLiteral("TYPE,STATE,CONNECTION"), QStringLiteral("device")},
        [this](int code, const QString &out) {
            QString name, kind;
            bool hasWifi = false;
            if (code == 0) {
                for (const QString &line : out.split(QLatin1Char('\n'), Qt::SkipEmptyParts)) {
                    const QStringList f = line.split(QLatin1Char(':'));
                    if (f.size() < 3)
                        continue;
                    const bool connected = f[1] == QLatin1String("connected");
                    if (f[0] == QLatin1String("wifi")) {
                        hasWifi = true;
                        if (connected) { name = f[2]; kind = QStringLiteral("wifi"); }
                    } else if (f[0] == QLatin1String("ethernet") && connected && kind.isEmpty()) {
                        name = tr("Wired"); kind = QStringLiteral("wired");
                    }
                }
            }
            if (name != m_network || kind != m_networkKind || hasWifi != m_hasWifi) {
                m_network = name; m_networkKind = kind; m_hasWifi = hasWifi;
                emit changed();
            }
        });
    run(QStringLiteral("nmcli"), {QStringLiteral("radio"), QStringLiteral("wifi")}, [this](int code, const QString &out) {
        const bool on = code == 0 && out.trimmed() == QLatin1String("enabled");
        if (on != m_wifiEnabled) { m_wifiEnabled = on; emit changed(); }
    });

    // Volume: "Volume: 0.40" or "Volume: 0.40 [MUTED]"
    run(QStringLiteral("wpctl"), {QStringLiteral("get-volume"), QStringLiteral("@DEFAULT_AUDIO_SINK@")},
        [this](int code, const QString &out) {
            int vol = -1;
            bool muted = false;
            static const QRegularExpression re(QStringLiteral("Volume:\\s*([0-9.]+)"));
            const auto m = re.match(out);
            if (code == 0 && m.hasMatch()) {
                vol = qBound(0, qRound(m.captured(1).toDouble() * 100), 150);
                muted = out.contains(QLatin1String("MUTED"));
            }
            if (vol != m_volume || muted != m_muted) { m_volume = vol; m_muted = muted; emit changed(); }
        });

    // Brightness: "intel_backlight,backlight,400,40%,1000"
    run(QStringLiteral("brightnessctl"), {QStringLiteral("-m"), QStringLiteral("-c"), QStringLiteral("backlight")},
        [this](int code, const QString &out) {
            int b = -1;
            const QStringList f = out.trimmed().split(QLatin1Char(','));
            if (code == 0 && f.size() >= 4)
                b = f[3].chopped(1).toInt();
            if (b != m_brightness) { m_brightness = b; emit changed(); }
        });
}

void SystemStatus::setWifiEnabled(bool on)
{
    m_wifiEnabled = on;
    emit changed();
    run(QStringLiteral("nmcli"), {QStringLiteral("radio"), QStringLiteral("wifi"), on ? QStringLiteral("on") : QStringLiteral("off")},
        [this](int, const QString &) { QTimer::singleShot(1500, this, &SystemStatus::refresh); });
}

void SystemStatus::setVolume(int percent)
{
    percent = qBound(0, percent, 100);
    m_volume = percent;
    emit changed();
    run(QStringLiteral("wpctl"), {QStringLiteral("set-volume"), QStringLiteral("@DEFAULT_AUDIO_SINK@"),
                                  QString::number(percent / 100.0, 'f', 2)});
    if (m_muted && percent > 0)
        setMuted(false);
}

void SystemStatus::setMuted(bool on)
{
    m_muted = on;
    emit changed();
    run(QStringLiteral("wpctl"), {QStringLiteral("set-mute"), QStringLiteral("@DEFAULT_AUDIO_SINK@"), on ? QStringLiteral("1") : QStringLiteral("0")});
}

void SystemStatus::setBrightness(int percent)
{
    percent = qBound(1, percent, 100);      // never fully dark
    m_brightness = percent;
    emit changed();
    run(QStringLiteral("brightnessctl"), {QStringLiteral("-c"), QStringLiteral("backlight"), QStringLiteral("set"),
                                          QString::number(percent) + QLatin1Char('%')});
}

void SystemStatus::lock()
{
    run(QStringLiteral("loginctl"), {QStringLiteral("lock-session")});
}

void SystemStatus::logOut()
{
    // Plasma's session manager (ksmserver) saves the session and ends it cleanly;
    // without it, end the login session directly.
    QDBusMessage call = QDBusMessage::createMethodCall(QStringLiteral("org.kde.Shutdown"), QStringLiteral("/Shutdown"),
                                                       QStringLiteral("org.kde.Shutdown"), QStringLiteral("logout"));
    if (!QDBusConnection::sessionBus().send(call) || qEnvironmentVariableIsEmpty("KDE_FULL_SESSION"))
        run(QStringLiteral("loginctl"), {QStringLiteral("terminate-session"), qEnvironmentVariable("XDG_SESSION_ID")});
}

void SystemStatus::suspend() { run(QStringLiteral("systemctl"), {QStringLiteral("suspend")}); }
void SystemStatus::restart() { run(QStringLiteral("systemctl"), {QStringLiteral("reboot")}); }
void SystemStatus::powerOff() { run(QStringLiteral("systemctl"), {QStringLiteral("poweroff")}); }
