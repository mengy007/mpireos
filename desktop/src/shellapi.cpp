#include "shellapi.h"

#include <QClipboard>
#include <QDesktopServices>
#include <QDir>
#include <QGuiApplication>
#include <QProcess>
#include <QUrl>

ShellApi::ShellApi(QObject *parent)
    : QObject(parent)
{
}

bool ShellApi::isPanel(const QString &name)
{
    return name == QLatin1String("launcher") || name == QLatin1String("quick-settings")
        || name == QLatin1String("notifications") || name == QLatin1String("desktop-menu")
        || name == QLatin1String("wallpaper");
}

void ShellApi::setPanel(const QString &panel)
{
    const QString p = isPanel(panel) ? panel : QString();
    if (p == m_panel)
        return;
    m_panel = p;
    emit panelChanged();
}

void ShellApi::openDesktopMenu(qreal x, qreal y)
{
    m_menuPosition = QPointF(x, y);
    if (m_panel == QLatin1String("desktop-menu"))
        emit panelChanged();             // already open: move it to the new spot
    else
        setPanel(QStringLiteral("desktop-menu"));
}

void ShellApi::launch(const QString &command)
{
    QStringList args = QProcess::splitCommand(command);
    if (args.isEmpty())
        return;
    const QString program = args.takeFirst();
    if (!QProcess::startDetached(program, args, QDir::homePath()))
        qWarning("mpire-shell: could not start %s", qPrintable(command));
}

void ShellApi::openUrl(const QString &url)
{
    if (!QProcess::startDetached(QStringLiteral("xdg-open"), {url}))
        QDesktopServices::openUrl(QUrl(url));
}

void ShellApi::copy(const QString &text)
{
    QGuiApplication::clipboard()->setText(text);
}

void ShellApi::ShowPanel(const QString &name)
{
    if (name == QLatin1String("desktop-menu"))
        m_menuPosition = QPointF(-1, -1);
    setPanel(name);
}
void ShellApi::TogglePanel(const QString &name)
{
    if (m_panel == name) {
        setPanel(QString());
        return;
    }
    ShowPanel(name);
}
void ShellApi::HidePanel() { setPanel(QString()); }
void ShellApi::ToggleLauncher() { TogglePanel(QStringLiteral("launcher")); }
