#include "filesearch.h"

#include <QDBusConnection>
#include <QDBusMessage>
#include <QDir>
#include <QFileInfo>
#include <QGuiApplication>
#include <QIcon>
#include <QLocale>
#include <QMimeDatabase>
#include <QPointer>
#include <QProcess>
#include <QSet>
#include <QStandardPaths>
#include <QThread>
#include <QTimer>
#include <QUrl>
#include <algorithm>

namespace {

constexpr int kMaxEntries = 200000;
constexpr int kMaxDepth = 10;
constexpr int kStaleSeconds = 45;

// Folders that are never what anyone is looking for, and can be huge.
const QSet<QString> &skipped()
{
    static const QSet<QString> names{
        QStringLiteral("node_modules"), QStringLiteral("__pycache__"), QStringLiteral("venv"),
        QStringLiteral("site-packages"), QStringLiteral("target"), QStringLiteral("build"),
        QStringLiteral("dist"), QStringLiteral("CMakeFiles"), QStringLiteral("snap"),
    };
    return names;
}

// How well a file name matches (both lowercase): 0 for no match.
int nameScore(const QString &name, const QString &q)
{
    if (name == q)
        return 100;
    // Without the extension, too: "report" finds "report.pdf" as an exact hit.
    const int dot = name.lastIndexOf(QLatin1Char('.'));
    if (dot > 0 && name.left(dot) == q)
        return 96;
    if (name.startsWith(q))
        return 88;
    const int at = name.indexOf(q);
    if (at < 0) {
        // Every word of the query somewhere in the name: "tax 2025" finds "2025 Taxes.pdf".
        const QStringList words = q.split(QLatin1Char(' '), Qt::SkipEmptyParts);
        if (words.size() < 2)
            return 0;
        for (const QString &w : words)
            if (!name.contains(w))
                return 0;
        return 50;
    }
    const QChar before = name.at(at - 1);
    if (!before.isLetterOrNumber())
        return 74;          // start of a word
    return 56;
}

QString humanSize(qint64 bytes)
{
    return QLocale().formattedDataSize(bytes, 1, QLocale::DataSizeTraditionalFormat);
}

} // namespace

FileSearch::FileSearch(QObject *parent)
    : QObject(parent)
    , m_root(QDir::homePath())
{
    // A first index shortly after login, once the desktop is up.
    QTimer::singleShot(8000, this, &FileSearch::refresh);
}

FileSearch::~FileSearch()
{
    if (m_thread) {
        m_thread->requestInterruption();
        m_thread->wait();
    }
}

QVector<FileSearch::Entry> FileSearch::scan(const QString &root)
{
    QVector<Entry> out;
    struct Pending { QString path; int depth; };
    QVector<Pending> todo{{root, 0}};
    // Breadth first, so the closest files make it in if the cap is reached.
    for (int i = 0; i < todo.size() && out.size() < kMaxEntries; ++i) {
        if (QThread::currentThread()->isInterruptionRequested())
            break;
        const Pending dir = todo[i];
        const QFileInfoList list = QDir(dir.path).entryInfoList(QDir::AllEntries | QDir::NoDotAndDotDot | QDir::NoSymLinks);
        for (const QFileInfo &fi : list) {
            const QString name = fi.fileName();
            if (name.startsWith(QLatin1Char('.')) || name.endsWith(QLatin1Char('~')))
                continue;
            const bool isDir = fi.isDir();
            if (isDir && skipped().contains(name))
                continue;
            out.append({fi.filePath(), name.toLower(), fi.lastModified().toMSecsSinceEpoch(), dir.depth, isDir});
            if (isDir && dir.depth < kMaxDepth)
                todo.append({fi.filePath(), dir.depth + 1});
        }
    }
    return out;
}

void FileSearch::refresh()
{
    if (m_scanning || (m_scannedAt.isValid() && m_scannedAt.secsTo(QDateTime::currentDateTime()) < kStaleSeconds))
        return;
    m_scanning = true;
    const QString root = m_root;
    QPointer<FileSearch> self(this);
    m_thread = QThread::create([self, root] {
        QVector<Entry> entries = scan(root);
        QMetaObject::invokeMethod(qApp, [self, entries = std::move(entries)]() mutable {
            if (self)
                self->scanFinished(std::move(entries));
        }, Qt::QueuedConnection);
    });
    connect(m_thread, &QThread::finished, m_thread, &QObject::deleteLater);
    connect(m_thread, &QThread::finished, this, [this] { m_thread = nullptr; });
    m_thread->start(QThread::LowPriority);
}

void FileSearch::scanFinished(QVector<Entry> entries)
{
    {
        QMutexLocker lock(&m_lock);
        m_entries = std::move(entries);
    }
    m_scannedAt = QDateTime::currentDateTime();
    m_scanning = false;
    ++m_revision;
    emit revisionChanged();
}

QVariantList FileSearch::search(const QString &query, int limit) const
{
    const QString q = query.trimmed().toLower();
    if (q.size() < 2)
        return {};
    struct Hit { const Entry *e; double rank; };
    QVector<Hit> hits;
    const qint64 now = QDateTime::currentMSecsSinceEpoch();
    QMutexLocker lock(&m_lock);
    for (const Entry &e : m_entries) {
        const int s = nameScore(e.lowerName, q);
        if (s == 0)
            continue;
        // Recently changed files and ones near the top of home rank higher.
        const double days = double(now - e.modified) / 86400000.0;
        const double recent = days < 1 ? 8 : days < 7 ? 5 : days < 30 ? 2 : 0;
        hits.append({&e, s + recent - std::min(e.depth, 6) * 1.5 + (e.dir ? 1 : 0)});
    }
    std::sort(hits.begin(), hits.end(), [](const Hit &a, const Hit &b) {
        return a.rank != b.rank ? a.rank > b.rank : a.e->modified > b.e->modified;
    });
    QVariantList out;
    QMimeDatabase mimes;
    const QString home = QDir::homePath();
    for (int i = 0; i < hits.size() && out.size() < limit; ++i) {
        const Entry &e = *hits[i].e;
        const QFileInfo fi(e.path);
        if (!fi.exists())
            continue;
        const QMimeType mime = e.dir ? mimes.mimeTypeForName(QStringLiteral("inode/directory"))
                                     : mimes.mimeTypeForFile(fi, QMimeDatabase::MatchExtension);
        QString folder = fi.absolutePath();
        if (folder.startsWith(home))
            folder = QStringLiteral("~") + folder.mid(home.size());
        const QString icon = QIcon::hasThemeIcon(mime.iconName()) ? mime.iconName() : mime.genericIconName();
        out << QVariantMap{
            {QStringLiteral("path"), e.path},
            {QStringLiteral("url"), QUrl::fromLocalFile(e.path).toString()},
            {QStringLiteral("name"), fi.fileName()},
            {QStringLiteral("folder"), folder},
            {QStringLiteral("isDir"), e.dir},
            {QStringLiteral("icon"), e.dir ? QStringLiteral("folder") : icon},
            {QStringLiteral("kind"), e.dir ? tr("Folder") : mime.comment()},
            {QStringLiteral("size"), e.dir ? QString() : humanSize(fi.size())},
            {QStringLiteral("modified"), fi.lastModified()},
            {QStringLiteral("image"), mime.name().startsWith(QLatin1String("image/")) && fi.size() < 40 * 1024 * 1024},
            {QStringLiteral("rank"), hits[i].rank},
        };
    }
    return out;
}

void FileSearch::reveal(const QString &path)
{
    // The file manager's standard interface (Dolphin and others), else the folder.
    QDBusMessage call = QDBusMessage::createMethodCall(QStringLiteral("org.freedesktop.FileManager1"),
                                                       QStringLiteral("/org/freedesktop/FileManager1"),
                                                       QStringLiteral("org.freedesktop.FileManager1"),
                                                       QStringLiteral("ShowItems"));
    call << QStringList{QUrl::fromLocalFile(path).toString()} << QString();
    const QDBusMessage reply = QDBusConnection::sessionBus().call(call, QDBus::Block, 3000);
    if (reply.type() == QDBusMessage::ErrorMessage)
        QProcess::startDetached(QStringLiteral("xdg-open"), {QFileInfo(path).absolutePath()});
}
