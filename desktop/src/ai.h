// The desktop's side of MpireOS's built-in AI: the assistant conversation and
// AI settings. The AI itself (providers, keys, discovery) lives in mpire-ai
// (ai/ in this repository); this runs its command line and reads its JSON, so
// the shell never holds an API key for longer than it takes to hand one over.
// Exposed to QML as the context property `ai`.
#pragma once

#include <QObject>
#include <QPointer>
#include <QProcess>
#include <QVariantList>
#include <QVariantMap>
#include <functional>

class AiAssistant : public QObject
{
    Q_OBJECT
    // AI settings: {default, providers: [{id, name, kind, url, model, where
    // (cloud|local|network), needsKey, hasKey, keyLabel, isDefault}], presets,
    // gateway: {tcp, port}}
    Q_PROPERTY(QVariantList providers READ providers NOTIFY statusChanged)
    Q_PROPERTY(QVariantList presets READ presets NOTIFY statusChanged)
    Q_PROPERTY(QVariantMap current READ current NOTIFY statusChanged)          // the provider that answers
    Q_PROPERTY(bool ready READ ready NOTIFY statusChanged)                     // one is set up and has its key
    Q_PROPERTY(bool available READ available CONSTANT)                         // mpire-ai is installed
    Q_PROPERTY(bool gateway READ gateway NOTIFY statusChanged)
    // The conversation: [{role: "user"|"assistant", text, error, provider}]
    Q_PROPERTY(QVariantList messages READ messages NOTIFY messagesChanged)
    // The reply as it streams in (not in messages until it's finished).
    Q_PROPERTY(QString partial READ partial NOTIFY partialChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    // Discovery: [{server, host, port, url, models, label, where, added}]
    Q_PROPERTY(QVariantList servers READ servers NOTIFY serversChanged)
    Q_PROPERTY(bool discovering READ discovering NOTIFY serversChanged)
    Q_PROPERTY(bool searchedNetwork READ searchedNetwork NOTIFY serversChanged)
    // Models per provider id, filled by loadModels().
    Q_PROPERTY(QVariantMap models READ models NOTIFY modelsChanged)
    // The last settings action's outcome, for a line under the form.
    Q_PROPERTY(QString notice READ notice NOTIFY noticeChanged)
    Q_PROPERTY(bool noticeError READ noticeError NOTIFY noticeChanged)
    Q_PROPERTY(bool working READ working NOTIFY workingChanged)

public:
    explicit AiAssistant(QObject *parent = nullptr);
    ~AiAssistant() override;

    QVariantList providers() const { return m_status.value(QStringLiteral("providers")).toList(); }
    QVariantList presets() const { return m_status.value(QStringLiteral("presets")).toList(); }
    QVariantMap current() const;
    bool ready() const;
    bool available() const { return !m_program.isEmpty(); }
    bool gateway() const;
    QVariantList messages() const { return m_messages; }
    QString partial() const { return m_partial; }
    bool busy() const { return m_chat != nullptr; }
    QVariantList servers() const { return m_servers; }
    bool discovering() const { return m_discovering; }
    bool searchedNetwork() const { return m_searchedNetwork; }
    QVariantMap models() const { return m_models; }
    QString notice() const { return m_notice; }
    bool noticeError() const { return m_noticeError; }
    bool working() const { return m_working > 0; }

    Q_INVOKABLE void refresh();
    Q_INVOKABLE void ask(const QString &text);
    Q_INVOKABLE void stop();
    Q_INVOKABLE void clear();
    Q_INVOKABLE void copyLast();

    Q_INVOKABLE void addPreset(const QString &preset, const QString &key, const QString &url = QString());
    Q_INVOKABLE void saveKey(const QString &id, const QString &key);
    Q_INVOKABLE void addServer(const QVariantMap &server);
    Q_INVOKABLE void addAddress(const QString &address);
    Q_INVOKABLE void remove(const QString &id);
    Q_INVOKABLE void setDefault(const QString &id);
    Q_INVOKABLE void setModel(const QString &id, const QString &model);
    Q_INVOKABLE void loadModels(const QString &id);
    Q_INVOKABLE void discover(bool network);
    Q_INVOKABLE void setGateway(bool on);
    Q_INVOKABLE void setupLocal();
    Q_INVOKABLE void clearNotice() { setNotice(QString(), false); }

signals:
    void statusChanged();
    void messagesChanged();
    void partialChanged();
    void busyChanged();
    void serversChanged();
    void modelsChanged();
    void noticeChanged();
    void workingChanged();

private:
    using Done = std::function<void(int exitCode, const QByteArray &out)>;
    void run(const QStringList &args, const QByteArray &input, Done done);
    void setNotice(const QString &text, bool error);
    void finishReply(const QString &error);
    static QString errorOf(const QByteArray &out);

    QString m_program;
    QVariantMap m_status;
    QVariantList m_messages;
    QString m_partial;
    QString m_replyProvider;
    QPointer<QProcess> m_chat;
    QByteArray m_chatBuffer;
    QString m_chatError;
    QVariantList m_servers;
    bool m_discovering = false;
    bool m_searchedNetwork = false;
    QVariantMap m_models;
    QString m_notice;
    bool m_noticeError = false;
    int m_working = 0;
};
