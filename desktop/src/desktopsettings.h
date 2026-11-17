// The desktop's own settings: the wallpaper and how it is placed, and whether
// the dock hides itself. Exposed to QML as the context property
// `desktopSettings`. Saved in ~/.config/MpireOS/desktop.conf; a distribution
// default can go in /etc/xdg/MpireOS/desktop.conf.
#pragma once

#include <QObject>
#include <QSettings>
#include <QString>
#include <QVariantList>

class DesktopSettings : public QObject
{
    Q_OBJECT
    // "mpire:<name>" (one of ours, drawn by Wallpaper.qml), "color:#rrggbb",
    // or a picture as a file:// URL.
    Q_PROPERTY(QString wallpaper READ wallpaper WRITE setWallpaper NOTIFY wallpaperChanged)
    // How a picture covers the screen: "fill", "fit", "center", or "tile".
    Q_PROPERTY(QString fillMode READ fillMode WRITE setFillMode NOTIFY fillModeChanged)
    Q_PROPERTY(bool dockAutoHide READ dockAutoHide WRITE setDockAutoHide NOTIFY dockAutoHideChanged)
    // Pictures found in ~/Pictures and the system's wallpaper folders:
    // [{ url, name }], newest of the user's own first.
    Q_PROPERTY(QVariantList pictures READ pictures NOTIFY picturesChanged)
    // True while the system file chooser (opened by browse()) is up.
    Q_PROPERTY(bool browsing READ browsing NOTIFY browsingChanged)

public:
    explicit DesktopSettings(QObject *parent = nullptr);

    QString wallpaper() const { return m_wallpaper; }
    void setWallpaper(const QString &wallpaper);
    QString fillMode() const { return m_fillMode; }
    void setFillMode(const QString &mode);
    bool dockAutoHide() const { return m_dockAutoHide; }
    void setDockAutoHide(bool on);
    QVariantList pictures() const { return m_pictures; }
    bool browsing() const { return m_browsing; }

    // Looks for pictures again (the wallpaper picker calls this when it opens).
    Q_INVOKABLE void refreshPictures();
    // Opens the system's file chooser (xdg-desktop-portal) to pick a picture.
    // When one is chosen it becomes the wallpaper and browseFinished(true) is
    // emitted; browseFinished(false) if the chooser was closed.
    Q_INVOKABLE void browse();

signals:
    void wallpaperChanged();
    void fillModeChanged();
    void dockAutoHideChanged();
    void picturesChanged();
    void browsingChanged();
    void browseFinished(bool chosen);

private slots:
    void portalResponse(uint response, const QVariantMap &results);

private:
    void setBrowsing(bool on);

    QSettings m_settings;
    QString m_wallpaper;
    QString m_fillMode;
    bool m_dockAutoHide = true;
    QVariantList m_pictures;
    bool m_browsing = false;
    QString m_request;      // the portal request being waited on
};
