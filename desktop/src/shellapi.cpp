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
        || name == QLatin1String("notifications");
}

void ShellApi::setPanel(const QString &panel)
{
    const QString p = isPanel(panel) ? panel : QString();
    if (p == m_panel)
        return;
    m_panel = p;
    emit panelChanged();
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

void ShellApi::ShowPanel(const QString &name) { setPanel(name); }
void ShellApi::TogglePanel(const QString &name) { setPanel(m_panel == name ? QString() : name); }
void ShellApi::HidePanel() { setPanel(QString()); }
void ShellApi::ToggleLauncher() { TogglePanel(QStringLiteral("launcher")); }
