#include "apps.h"

#include <QCollator>
#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QProcess>
#include <QSet>
#include <QStandardPaths>
#include <QTextStream>

#include <algorithm>

namespace {

// The [Desktop Entry] group of a .desktop file, unlocalized keys only.
QHash<QString, QString> readEntry(const QString &path)
{
    QHash<QString, QString> entry;
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text))
        return entry;
    QTextStream in(&f);
    bool inGroup = false;
    while (!in.atEnd()) {
        const QString line = in.readLine().trimmed();
        if (line.isEmpty() || line.startsWith(QLatin1Char('#')))
            continue;
        if (line.startsWith(QLatin1Char('['))) {
            if (inGroup)
                break;
            inGroup = line == QLatin1String("[Desktop Entry]");
            continue;
        }
        if (!inGroup)
            continue;
        const int eq = line.indexOf(QLatin1Char('='));
        if (eq <= 0)
            continue;
        const QString key = line.left(eq).trimmed();
        if (key.contains(QLatin1Char('[')))
            continue;
        entry.insert(key, line.mid(eq + 1).trimmed());
    }
    return entry;
}

bool isTrue(const QString &v) { return v.compare(QLatin1String("true"), Qt::CaseInsensitive) == 0; }

QStringList desktops()
{
    return qEnvironmentVariable("XDG_CURRENT_DESKTOP", QStringLiteral("KDE")).split(QLatin1Char(':'), Qt::SkipEmptyParts);
}

bool shownHere(const QHash<QString, QString> &e)
{
    const QStringList here = desktops();
    const auto any = [&](const QString &list) {
        for (const QString &d : list.split(QLatin1Char(';'), Qt::SkipEmptyParts))
            if (here.contains(d, Qt::CaseInsensitive))
                return true;
        return false;
    };
    if (e.contains(QStringLiteral("OnlyShowIn")) && !any(e.value(QStringLiteral("OnlyShowIn"))))
        return false;
    if (e.contains(QStringLiteral("NotShowIn")) && any(e.value(QStringLiteral("NotShowIn"))))
        return false;
    return true;
}

} // namespace

AppIndex::AppIndex(QObject *parent)
    : QObject(parent)
{
    m_reload.setSingleShot(true);
    m_reload.setInterval(1500);      // package installs touch many files at once
    connect(&m_reload, &QTimer::timeout, this, &AppIndex::reload);
    connect(&m_watcher, &QFileSystemWatcher::directoryChanged, &m_reload, qOverload<>(&QTimer::start));
    reload();
}

QStringList AppIndex::commandFor(const QString &exec)
{
    QStringList out;
    for (QString arg : QProcess::splitCommand(exec)) {
        if (arg.size() == 2 && arg.startsWith(QLatin1Char('%')) && arg != QLatin1String("%%"))
            continue;                       // a field code on its own: no files or URLs to pass
        arg.replace(QLatin1String("%%"), QLatin1String("%"));
        out << arg;
    }
    return out;
}

void AppIndex::reload()
{
    const QStringList dirs = QStandardPaths::standardLocations(QStandardPaths::ApplicationsLocation);
    for (const QString &d : dirs)
        if (QDir(d).exists() && !m_watcher.directories().contains(d))
            m_watcher.addPath(d);

    QSet<QString> seen;
    QList<QVariantMap> list;
    for (const QString &dir : dirs) {            // earlier directories win (user's own first)
        QDirIterator it(dir, {QStringLiteral("*.desktop")}, QDir::Files, QDirIterator::Subdirectories);
        while (it.hasNext()) {
            const QString path = it.next();
            QString id = QDir(dir).relativeFilePath(path);
            id.replace(QLatin1Char('/'), QLatin1Char('-'));
            if (seen.contains(id))
                continue;
            seen.insert(id);
            const auto e = readEntry(path);
            if (e.value(QStringLiteral("Type")) != QLatin1String("Application") || isTrue(e.value(QStringLiteral("NoDisplay")))
                || isTrue(e.value(QStringLiteral("Hidden"))) || e.value(QStringLiteral("Exec")).isEmpty() || !shownHere(e))
                continue;
            list.append(QVariantMap{
                {"id", id},
                {"name", e.value(QStringLiteral("Name"))},
                {"genericName", e.value(QStringLiteral("GenericName"))},
                {"comment", e.value(QStringLiteral("Comment"))},
                {"keywords", e.value(QStringLiteral("Keywords")).split(QLatin1Char(';'), Qt::SkipEmptyParts).join(QLatin1Char(' '))},
                {"icon", e.value(QStringLiteral("Icon"))},
                {"exec", e.value(QStringLiteral("Exec"))},
                {"terminal", isTrue(e.value(QStringLiteral("Terminal")))},
            });
        }
    }
    QCollator collator;
    collator.setCaseSensitivity(Qt::CaseInsensitive);
    std::sort(list.begin(), list.end(), [&](const QVariantMap &a, const QVariantMap &b) {
        return collator.compare(a.value("name").toString(), b.value("name").toString()) < 0;
    });
    m_apps.clear();
    for (const auto &m : list)
        m_apps.append(m);
    emit appsChanged();
}

bool AppIndex::launch(const QString &id)
{
    for (const QVariant &v : std::as_const(m_apps)) {
        const QVariantMap app = v.toMap();
        if (app.value("id").toString() != id)
            continue;
        QStringList args = commandFor(app.value("exec").toString());
        if (args.isEmpty())
            return false;
        if (app.value("terminal").toBool())
            args = QStringList{QStringLiteral("konsole"), QStringLiteral("-e")} + args;
        const QString program = args.takeFirst();
        if (!QProcess::startDetached(program, args, QDir::homePath())) {
            qWarning("mpire-shell: could not start %s", qPrintable(id));
            return false;
        }
        return true;
    }
    return false;
}
