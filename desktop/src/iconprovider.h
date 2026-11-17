// image://icon/<name or absolute path>: themed app icons for QML.
#pragma once

#include <QIcon>
#include <QPixmap>
#include <QQuickImageProvider>
#include <QUrl>

class IconProvider : public QQuickImageProvider
{
public:
    IconProvider() : QQuickImageProvider(QQuickImageProvider::Pixmap) {}

    QPixmap requestPixmap(const QString &id, QSize *size, const QSize &requested) override
    {
        const QSize want = requested.isValid() ? requested : QSize(64, 64);
        const QString name = QUrl::fromPercentEncoding(id.toUtf8());
        QIcon icon = name.startsWith(QLatin1Char('/')) ? QIcon(name) : QIcon::fromTheme(name);
        if (icon.isNull())
            icon = QIcon::fromTheme(QStringLiteral("application-x-executable"));
        const QPixmap pm = icon.pixmap(want);
        if (size)
            *size = pm.size();
        return pm;
    }
};
