#include "desktopsettings.h"

#include <QDBusArgument>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusMetaType>
#include <QDBusObjectPath>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QRandomGenerator>
#include <QRegularExpression>
#include <QSet>
#include <QStandardPaths>
#include <QUrl>

#include <algorithm>
#include <climits>
#include <cstdlib>

namespace {

const QString kDefaultWallpaper = QStringLiteral("mpire:mist");
const QStringList kImageFilters = {QStringLiteral("*.jpg"), QStringLiteral("*.jpeg"), QStringLiteral("*.png"),
                                   QStringLiteral("*.webp"), QStringLiteral("*.avif"), QStringLiteral("*.jxl")};
constexpr int kMaxPictures = 60;

bool isPicture(const QString &path)
{
    const QString suffix = QFileInfo(path).suffix().toLower();
    for (const QString &f : kImageFilters)
        if (f.mid(2) == suffix)
            return true;
    return false;
}

QString prettyName(const QString &base)
{
    QString name = base;
    name.replace(QLatin1Char('_'), QLatin1Char(' ')).replace(QLatin1Char('-'), QLatin1Char(' '));
    if (!name.isEmpty())
        name[0] = name[0].toUpper();
    return name;
}

// A Plasma wallpaper package (wallpapers/<Name>/contents/images/<W>x<H>.png):
// the size closest to 1920x1080, which is plenty for a thumbnail and a screen.
QString bestImageInPackage(const QString &packageDir)
{
    QDir images(packageDir + QStringLiteral("/contents/images"));
    if (!images.exists())
        return {};
    static const QRegularExpression size(QStringLiteral("^(\\d+)x(\\d+)"));
    QString best;
    long bestScore = LONG_MAX;
    for (const QFileInfo &f : images.entryInfoList(kImageFilters, QDir::Files)) {
        const auto m = size.match(f.completeBaseName());
        const long score = m.hasMatch() ? std::labs(m.captured(1).toLong() * m.captured(2).toLong() - 1920L * 1080L) : LONG_MAX - 1;
        if (score < bestScore) {
            bestScore = score;
            best = f.absoluteFilePath();
        }
    }
    return best;
}

QVariantMap picture(const QString &path, const QString &name)
{
    return {{QStringLiteral("url"), QUrl::fromLocalFile(path).toString()}, {QStringLiteral("name"), name}};
}

// xdg-desktop-portal FileChooser filters: a(sa(us)).
struct FilterPattern {
    uint type = 0;          // 0: glob, 1: MIME type
    QString pattern;
};
struct Filter {
    QString name;
    QList<FilterPattern> patterns;
};

} // namespace

Q_DECLARE_METATYPE(FilterPattern)
Q_DECLARE_METATYPE(Filter)
Q_DECLARE_METATYPE(QList<Filter>)

QDBusArgument &operator<<(QDBusArgument &arg, const FilterPattern &p)
{
    arg.beginStructure();
    arg << p.type << p.pattern;
    arg.endStructure();
    return arg;
}
const QDBusArgument &operator>>(const QDBusArgument &arg, FilterPattern &p)
{
    arg.beginStructure();
    arg >> p.type >> p.pattern;
    arg.endStructure();
    return arg;
}
QDBusArgument &operator<<(QDBusArgument &arg, const Filter &f)
{
    arg.beginStructure();
    arg << f.name << f.patterns;
    arg.endStructure();
    return arg;
}
const QDBusArgument &operator>>(const QDBusArgument &arg, Filter &f)
{
    arg.beginStructure();
    arg >> f.name >> f.patterns;
    arg.endStructure();
    return arg;
}

DesktopSettings::DesktopSettings(QObject *parent)
    : QObject(parent)
    , m_settings(QSettings::IniFormat, QSettings::UserScope, QStringLiteral("MpireOS"), QStringLiteral("desktop"))
{
    m_wallpaper = m_settings.value(QStringLiteral("Wallpaper/Source"), kDefaultWallpaper).toString();
    m_fillMode = m_settings.value(QStringLiteral("Wallpaper/FillMode"), QStringLiteral("fill")).toString();
    m_dockAutoHide = m_settings.value(QStringLiteral("Dock/AutoHide"), true).toBool();
    // A picture that has since been deleted: back to ours.
    if (m_wallpaper.startsWith(QLatin1String("file:")) && !QFileInfo::exists(QUrl(m_wallpaper).toLocalFile()))
        m_wallpaper = kDefaultWallpaper;
}

void DesktopSettings::setWallpaper(const QString &wallpaper)
{
    const QString w = wallpaper.isEmpty() ? kDefaultWallpaper : wallpaper;
    if (w == m_wallpaper)
        return;
    m_wallpaper = w;
    m_settings.setValue(QStringLiteral("Wallpaper/Source"), w);
    m_settings.sync();
    emit wallpaperChanged();
}

void DesktopSettings::setFillMode(const QString &mode)
{
    static const QStringList modes = {QStringLiteral("fill"), QStringLiteral("fit"), QStringLiteral("center"), QStringLiteral("tile")};
    if (!modes.contains(mode) || mode == m_fillMode)
        return;
    m_fillMode = mode;
    m_settings.setValue(QStringLiteral("Wallpaper/FillMode"), mode);
    m_settings.sync();
    emit fillModeChanged();
}

void DesktopSettings::setDockAutoHide(bool on)
{
    if (on == m_dockAutoHide)
        return;
    m_dockAutoHide = on;
    m_settings.setValue(QStringLiteral("Dock/AutoHide"), on);
    m_settings.sync();
    emit dockAutoHideChanged();
}

void DesktopSettings::refreshPictures()
{
    QVariantList found;
    QSet<QString> seen;
    const auto add = [&](const QString &path, const QString &name) {
        const QString canonical = QFileInfo(path).canonicalFilePath();
        if (canonical.isEmpty() || seen.contains(canonical) || found.size() >= kMaxPictures)
            return;
        seen.insert(canonical);
        found << picture(canonical, name);
    };

    // The user's own pictures first, newest first: ~/Pictures and ~/Pictures/Wallpapers.
    const QString pics = QStandardPaths::writableLocation(QStandardPaths::PicturesLocation);
    QFileInfoList mine;
    for (const QString &dir : {pics, pics + QStringLiteral("/Wallpapers")})
        mine += QDir(dir).entryInfoList(kImageFilters, QDir::Files | QDir::Readable);
    std::sort(mine.begin(), mine.end(), [](const QFileInfo &a, const QFileInfo &b) { return a.lastModified() > b.lastModified(); });
    for (const QFileInfo &f : mine)
        add(f.absoluteFilePath(), prettyName(f.completeBaseName()));

    // Then wallpapers that came with the system.
    QStringList systemDirs;
    for (const QString &data : QStandardPaths::standardLocations(QStandardPaths::GenericDataLocation))
        systemDirs << data + QStringLiteral("/wallpapers") << data + QStringLiteral("/backgrounds");
    for (const QString &dir : systemDirs) {
        QDir d(dir);
        if (!d.exists())
            continue;
        for (const QFileInfo &entry : d.entryInfoList(QDir::Dirs | QDir::Files | QDir::NoDotAndDotDot, QDir::Name)) {
            if (entry.isDir()) {
                const QString best = bestImageInPackage(entry.absoluteFilePath());
                if (!best.isEmpty()) {
                    add(best, prettyName(entry.fileName()));
                    continue;
                }
                // A plain folder of pictures (e.g. /usr/share/backgrounds/<theme>/).
                QDirIterator it(entry.absoluteFilePath(), kImageFilters, QDir::Files);
                while (it.hasNext()) {
                    const QString path = it.next();
                    add(path, prettyName(QFileInfo(path).completeBaseName()));
                }
            } else if (isPicture(entry.fileName())) {
                add(entry.absoluteFilePath(), prettyName(entry.completeBaseName()));
            }
        }
    }

    if (found != m_pictures) {
        m_pictures = found;
        emit picturesChanged();
    }
}

void DesktopSettings::setBrowsing(bool on)
{
    if (on == m_browsing)
        return;
    m_browsing = on;
    emit browsingChanged();
}

void DesktopSettings::browse()
{
    if (m_browsing)
        return;
    qDBusRegisterMetaType<FilterPattern>();
    qDBusRegisterMetaType<QList<FilterPattern>>();
    qDBusRegisterMetaType<Filter>();
    qDBusRegisterMetaType<QList<Filter>>();

    QDBusConnection bus = QDBusConnection::sessionBus();
    // The portal answers on a Request object whose path we can work out from
    // our bus name and a token we choose; listen there before asking, so the
    // answer can't arrive first.
    const QString token = QStringLiteral("mpire%1").arg(QRandomGenerator::global()->generate());
    QString sender = bus.baseService().mid(1);
    sender.replace(QLatin1Char('.'), QLatin1Char('_'));
    m_request = QStringLiteral("/org/freedesktop/portal/desktop/request/%1/%2").arg(sender, token);
    bus.connect(QStringLiteral("org.freedesktop.portal.Desktop"), m_request, QStringLiteral("org.freedesktop.portal.Request"),
                QStringLiteral("Response"), this, SLOT(portalResponse(uint, QVariantMap)));

    Filter images{tr("Pictures"), {}};
    for (const QString &f : kImageFilters)
        images.patterns << FilterPattern{0, f};
    images.patterns << FilterPattern{1, QStringLiteral("image/*")};

    QVariantMap options;
    options.insert(QStringLiteral("handle_token"), token);
    options.insert(QStringLiteral("modal"), true);
    options.insert(QStringLiteral("filters"), QVariant::fromValue(QList<Filter>{images}));
    options.insert(QStringLiteral("current_filter"), QVariant::fromValue(images));
    const QString pics = QStandardPaths::writableLocation(QStandardPaths::PicturesLocation);
    if (QFileInfo::exists(pics))
        options.insert(QStringLiteral("current_folder"), QByteArray(QFile::encodeName(pics) + '\0'));

    QDBusMessage call = QDBusMessage::createMethodCall(QStringLiteral("org.freedesktop.portal.Desktop"),
                                                       QStringLiteral("/org/freedesktop/portal/desktop"),
                                                       QStringLiteral("org.freedesktop.portal.FileChooser"),
                                                       QStringLiteral("OpenFile"));
    call << QString() << tr("Choose a wallpaper") << options;
    setBrowsing(true);
    auto *watcher = new QDBusPendingCallWatcher(bus.asyncCall(call), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this](QDBusPendingCallWatcher *w) {
        w->deleteLater();
        QDBusPendingReply<QDBusObjectPath> reply = *w;
        if (reply.isError()) {
            qWarning("mpire-shell: could not open the file chooser: %s", qPrintable(reply.error().message()));
            portalResponse(2, {});
        }
    });
}

void DesktopSettings::portalResponse(uint response, const QVariantMap &results)
{
    if (!m_request.isEmpty())
        QDBusConnection::sessionBus().disconnect(QStringLiteral("org.freedesktop.portal.Desktop"), m_request,
                                                 QStringLiteral("org.freedesktop.portal.Request"), QStringLiteral("Response"),
                                                 this, SLOT(portalResponse(uint, QVariantMap)));
    m_request.clear();
    const QStringList uris = results.value(QStringLiteral("uris")).toStringList();
    const bool chosen = response == 0 && !uris.isEmpty() && isPicture(QUrl(uris.first()).toLocalFile());
    if (chosen)
        setWallpaper(QUrl(uris.first()).toString());
    setBrowsing(false);
    emit browseFinished(chosen);
}
