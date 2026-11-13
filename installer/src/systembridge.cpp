#include "systembridge.h"

#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QTimeZone>
#include <QtMath>

namespace {

const char *kLiveMarker = "/run/archiso/bootmnt";      // only exists on the live ISO
const char *kBackend = "/usr/local/bin/mpire-install";
constexpr qint64 kMinimumDiskBytes = 12'000'000'000;    // the live system needs ~8 GB

QString run(const QString &program, const QStringList &args)
{
    QProcess p;
    p.start(program, args);
    if (!p.waitForFinished(10000) || p.exitCode() != 0)
        return {};
    return QString::fromUtf8(p.readAllStandardOutput()).trimmed();
}

bool flag(const QJsonValue &v)   // lsblk prints booleans or "0"/"1" depending on version
{
    return v.isBool() ? v.toBool() : (v.toString() == QLatin1String("1") || v.toInt() == 1);
}

qint64 bytes(const QJsonValue &v)
{
    return v.isString() ? v.toString().toLongLong() : qint64(v.toDouble());
}

QString humanSize(qint64 b)
{
    const double gb = b / 1e9;
    if (gb >= 1000)
        return QStringLiteral("%1 TB").arg(gb / 1000, 0, 'f', gb >= 10000 ? 0 : 1);
    return QStringLiteral("%1 GB").arg(qRound(gb));
}

// What is already on a disk, judged from its partitions. Used only for wording
// ("This removes Windows 11 and..."), never to decide anything destructive.
QString otherSystem(const QJsonArray &children)
{
    QString found;
    for (const QJsonValue &c : children) {
        const QJsonObject p = c.toObject();
        const QString fs = p.value("fstype").toString();
        const QString label = p.value("partlabel").toString() + p.value("label").toString();
        if (fs == QLatin1String("ntfs") || fs == QLatin1String("BitLocker")
            || label.contains(QLatin1String("Microsoft"), Qt::CaseInsensitive))
            return QStringLiteral("Windows");
        if (fs == QLatin1String("apfs") || fs == QLatin1String("hfsplus"))
            found = QStringLiteral("macOS");
        else if (found.isEmpty() && (fs == QLatin1String("ext4") || fs == QLatin1String("btrfs")
                                     || fs == QLatin1String("xfs") || fs == QLatin1String("crypto_LUKS")))
            found = QStringLiteral("Linux");
    }
    return found;
}

} // namespace

SystemBridge::SystemBridge(bool forceDemo, QObject *parent)
    : QObject(parent)
    , m_live(!forceDemo && QFileInfo::exists(QString::fromLatin1(kLiveMarker))
             && QFileInfo::exists(QString::fromLatin1(kBackend)))
{
    m_process.setProcessChannelMode(QProcess::MergedChannels);
    connect(&m_process, &QProcess::readyReadStandardOutput, this, &SystemBridge::readOutput);
    connect(&m_process, &QProcess::finished, this, [this](int code, QProcess::ExitStatus status) {
        readOutput();
        if (!m_planPath.isEmpty()) {          // the plan holds the password: don't leave it around
            QFile::remove(m_planPath);
            m_planPath.clear();
        }
        emit finished(status == QProcess::NormalExit ? code : -1, m_tail.join('\n'));
    });
    connect(&m_process, &QProcess::errorOccurred, this, [this](QProcess::ProcessError err) {
        if (err == QProcess::FailedToStart)
            emit finished(-1, tr("Could not start the installer backend (%1).").arg(m_process.errorString()));
    });
    if (m_live)
        refreshDisks();
}

QString SystemBridge::timezone() const
{
    const QString tz = QString::fromUtf8(QTimeZone::systemTimeZoneId());
    return tz.isEmpty() ? QStringLiteral("UTC") : tz;
}

// The disk the live system was started from, so it is never offered as a target.
QString SystemBridge::bootDisk() const
{
    const QString source = run("findmnt", {"-n", "-o", "SOURCE", QString::fromLatin1(kLiveMarker)});
    if (source.isEmpty())
        return {};
    const QString parent = run("lsblk", {"-n", "-d", "-o", "PKNAME", source});
    return parent.isEmpty() ? QFileInfo(source).fileName() : parent;
}

void SystemBridge::refreshDisks()
{
    const QString json = run("lsblk", {"-J", "-b", "-o",
                                       "NAME,PATH,SIZE,MODEL,TYPE,RO,RM,TRAN,FSTYPE,PARTLABEL,LABEL"});
    const QString skip = bootDisk();
    QVariantList list;
    const QJsonArray devices = QJsonDocument::fromJson(json.toUtf8()).object().value("blockdevices").toArray();
    for (const QJsonValue &v : devices) {
        const QJsonObject d = v.toObject();
        const QString name = d.value("name").toString();
        const qint64 size = bytes(d.value("size"));
        if (d.value("type").toString() != QLatin1String("disk") || flag(d.value("ro"))
            || name == skip || name.startsWith(QLatin1String("zram")) || size < kMinimumDiskBytes)
            continue;
        const QJsonArray children = d.value("children").toArray();
        QString model = d.value("model").toString().simplified();
        if (model.isEmpty()) {
            const QString tran = d.value("tran").toString();
            model = tran == QLatin1String("usb")      ? tr("USB drive")
                  : tran == QLatin1String("virtio")   ? tr("Virtual disk")
                                                      : tr("Disk");
        }
        list.append(QVariantMap{
            {"id", d.value("path").toString()},
            {"name", model},
            {"size", tr("%1 · %2").arg(humanSize(size), name)},
            {"bytes", size},
            {"removable", flag(d.value("rm"))},
            {"hasData", !children.isEmpty()},
            {"otherOs", otherSystem(children)},
        });
    }
    m_disks = list;
    emit disksChanged();
}

bool SystemBridge::start(const QVariantMap &plan)
{
    if (!m_live || m_process.state() != QProcess::NotRunning)
        return false;
    // A private file the backend (running as root) reads; removed when it exits.
    m_planPath = QDir::temp().filePath(QStringLiteral("mpire-setup-plan-%1.json").arg(QCoreApplication::applicationPid()));
    QFile f(m_planPath);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate))
        return false;
    f.setPermissions(QFileDevice::ReadOwner | QFileDevice::WriteOwner);
    f.write(QJsonDocument(QJsonObject::fromVariantMap(plan)).toJson(QJsonDocument::Compact));
    f.close();

    m_buffer.clear();
    m_tail.clear();
    // The live user may use sudo without a password (live ISO only).
    m_process.start("sudo", {"-n", QString::fromLatin1(kBackend), "--plan", m_planPath});
    return true;
}

void SystemBridge::readOutput()
{
    m_buffer += m_process.readAllStandardOutput();
    int nl;
    while ((nl = m_buffer.indexOf('\n')) >= 0) {
        const QByteArray line = m_buffer.left(nl).trimmed();
        m_buffer.remove(0, nl + 1);
        if (line.isEmpty())
            continue;
        const QJsonDocument doc = QJsonDocument::fromJson(line);
        if (doc.isObject()) {
            emit event(doc.object().toVariantMap());
        } else {
            m_tail.append(QString::fromUtf8(line));
            if (m_tail.size() > 5)
                m_tail.removeFirst();
        }
    }
}

void SystemBridge::reboot()
{
    if (m_live)
        QProcess::startDetached("systemctl", {"reboot"});
}
