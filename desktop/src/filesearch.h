// Files and folders for universal search: an in-memory index of the names
// under the home folder, built in the background and searched as you type.
// Hidden folders and build/cache clutter are skipped.
#pragma once

#include <QDateTime>
#include <QMutex>
#include <QObject>
#include <QString>
#include <QVariantList>
#include <QVector>

class FileSearch : public QObject
{
    Q_OBJECT
    // Bumped when a scan finishes, so QML searches again.
    Q_PROPERTY(int revision READ revision NOTIFY revisionChanged)
    Q_PROPERTY(bool scanning READ scanning NOTIFY revisionChanged)

public:
    explicit FileSearch(QObject *parent = nullptr);
    ~FileSearch() override;

    int revision() const { return m_revision; }
    bool scanning() const { return m_scanning; }

    // Best matches by name: {path, url, name, folder, isDir, icon, kind,
    // size, modified, image}
    Q_INVOKABLE QVariantList search(const QString &query, int limit = 6) const;
    // Rescans when the index is more than a little out of date (universal
    // search calls this each time it opens).
    Q_INVOKABLE void refresh();
    // Shows the file selected in the file manager.
    Q_INVOKABLE void reveal(const QString &path);

    // For tests: index this folder instead of the home folder.
    void setRoot(const QString &root) { m_root = root; }

signals:
    void revisionChanged();

private:
    struct Entry {
        QString path;
        QString lowerName;
        qint64 modified;   // msecs since epoch
        int depth;
        bool dir;
    };
    static QVector<Entry> scan(const QString &root);
    void scanFinished(QVector<Entry> entries);

    QString m_root;
    mutable QMutex m_lock;
    QVector<Entry> m_entries;
    QDateTime m_scannedAt;
    bool m_scanning = false;
    int m_revision = 0;
    class QThread *m_thread = nullptr;
};
