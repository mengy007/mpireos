// What the shell's QML can ask of the system: launch things and open the
// shell's panels. Exposed to QML as the context property `shellApi`, and on the
// session bus as org.mpireos.Shell (/org/mpireos/Shell), so keyboard shortcuts
// and `mpire-shell --show <panel>` can open panels.
#pragma once

#include <QObject>
#include <QString>

class ShellApi : public QObject
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.mpireos.Shell")
    // The open panel: "" (none), "launcher", "quick-settings", or "notifications".
    Q_PROPERTY(QString panel READ panel WRITE setPanel NOTIFY panelChanged)

public:
    explicit ShellApi(QObject *parent = nullptr);

    QString panel() const { return m_panel; }
    void setPanel(const QString &panel);

    // Runs a command line such as "kcmshell6 kcm_networkmanagement", detached.
    Q_INVOKABLE void launch(const QString &command);
    Q_INVOKABLE void openUrl(const QString &url);
    Q_INVOKABLE void copy(const QString &text);

    static bool isPanel(const QString &name);

public slots:
    // org.mpireos.Shell
    Q_SCRIPTABLE void ShowPanel(const QString &name);
    Q_SCRIPTABLE void TogglePanel(const QString &name);
    Q_SCRIPTABLE void HidePanel();
    Q_SCRIPTABLE void ToggleLauncher();     // for KWin's Meta key (kwinrc [ModifierOnlyShortcuts])

signals:
    void panelChanged();

private:
    QString m_panel;
};
