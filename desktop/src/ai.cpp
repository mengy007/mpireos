#include "ai.h"

#include <QClipboard>
#include <QGuiApplication>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QStandardPaths>
#include <QUrl>

AiAssistant::AiAssistant(QObject *parent)
    : QObject(parent)
    , m_program(QStandardPaths::findExecutable(QStringLiteral("mpire-ai")))
{
    if (!m_program.isEmpty())
        refresh();
}

AiAssistant::~AiAssistant()
{
    if (m_chat)
        m_chat->kill();
}

QVariantMap AiAssistant::current() const
{
    const QString id = m_status.value(QStringLiteral("default")).toString();
    for (const QVariant &p : providers())
        if (p.toMap().value(QStringLiteral("id")).toString() == id)
            return p.toMap();
    return {};
}

bool AiAssistant::ready() const
{
    const QVariantMap p = current();
    return !p.isEmpty() && (!p.value(QStringLiteral("needsKey")).toBool() || p.value(QStringLiteral("hasKey")).toBool());
}

bool AiAssistant::gateway() const
{
    return m_status.value(QStringLiteral("gateway")).toMap().value(QStringLiteral("tcp")).toBool();
}

QString AiAssistant::errorOf(const QByteArray &out)
{
    const QJsonObject o = QJsonDocument::fromJson(out.trimmed().split('\n').last()).object();
    return o.value(QStringLiteral("error")).toString();
}

void AiAssistant::run(const QStringList &args, const QByteArray &input, Done done)
{
    if (m_program.isEmpty()) {
        done(127, QByteArrayLiteral("{\"error\": \"mpire-ai is not installed\"}"));
        return;
    }
    auto *proc = new QProcess(this);
    proc->setProgram(m_program);
    proc->setArguments(QStringList{QStringLiteral("--json")} + args);
    proc->setProcessChannelMode(QProcess::SeparateChannels);
    ++m_working;
    emit workingChanged();
    connect(proc, &QProcess::finished, this, [this, proc, done](int code, QProcess::ExitStatus status) {
        --m_working;
        emit workingChanged();
        done(status == QProcess::NormalExit ? code : 1, proc->readAllStandardOutput());
        proc->deleteLater();
    });
    connect(proc, &QProcess::errorOccurred, this, [proc](QProcess::ProcessError e) {
        if (e == QProcess::FailedToStart)
            emit proc->finished(127, QProcess::CrashExit);
    });
    proc->start();
    if (!input.isEmpty())
        proc->write(input);
    proc->closeWriteChannel();
}

void AiAssistant::setNotice(const QString &text, bool error)
{
    m_notice = text;
    m_noticeError = error;
    emit noticeChanged();
}

void AiAssistant::refresh()
{
    run({QStringLiteral("status")}, {}, [this](int code, const QByteArray &out) {
        if (code != 0)
            return;
        m_status = QJsonDocument::fromJson(out).object().toVariantMap();
        emit statusChanged();
        // Servers found by the last search (here or by `mpire-ai discover`),
        // with "added" up to date.
        if (!m_discovering) {
            m_servers = m_status.value(QStringLiteral("found")).toList();
            for (const QVariant &s : std::as_const(m_servers))
                m_searchedNetwork = m_searchedNetwork || s.toMap().value(QStringLiteral("where")) == QLatin1String("network");
            emit serversChanged();
        }
    });
}

// ---- The conversation ----

void AiAssistant::ask(const QString &text)
{
    const QString q = text.trimmed();
    if (q.isEmpty() || m_program.isEmpty())
        return;
    if (m_chat)
        stop();
    m_messages.append(QVariantMap{{QStringLiteral("role"), QStringLiteral("user")}, {QStringLiteral("text"), q}});
    emit messagesChanged();

    QJsonArray history;
    for (const QVariant &v : std::as_const(m_messages)) {
        const QVariantMap m = v.toMap();
        if (m.value(QStringLiteral("error")).toBool())
            continue;
        history.append(QJsonObject{{QStringLiteral("role"), m.value(QStringLiteral("role")).toString()},
                                   {QStringLiteral("content"), m.value(QStringLiteral("text")).toString()}});
    }
    m_partial.clear();
    m_chatBuffer.clear();
    m_chatError.clear();
    m_replyProvider = current().value(QStringLiteral("name")).toString();
    emit partialChanged();

    auto *proc = new QProcess(this);
    m_chat = proc;
    proc->setProgram(m_program);
    proc->setArguments({QStringLiteral("chat"), QStringLiteral("--json")});
    connect(proc, &QProcess::readyReadStandardOutput, this, [this, proc] {
        if (proc != m_chat)
            return;
        m_chatBuffer += proc->readAllStandardOutput();
        int nl;
        bool grew = false;
        while ((nl = m_chatBuffer.indexOf('\n')) >= 0) {
            const QJsonObject o = QJsonDocument::fromJson(m_chatBuffer.left(nl)).object();
            m_chatBuffer.remove(0, nl + 1);
            if (o.contains(QStringLiteral("delta"))) {
                m_partial += o.value(QStringLiteral("delta")).toString();
                grew = true;
            } else if (o.contains(QStringLiteral("provider"))) {
                const QJsonObject p = o.value(QStringLiteral("provider")).toObject();
                m_replyProvider = p.value(QStringLiteral("name")).toString();
            } else if (o.contains(QStringLiteral("error"))) {
                m_chatError = o.value(QStringLiteral("error")).toString();
            }
        }
        if (grew)
            emit partialChanged();
    });
    connect(proc, &QProcess::finished, this, [this, proc](int code, QProcess::ExitStatus) {
        if (proc == m_chat) {
            if (code != 0 && m_chatError.isEmpty())
                m_chatError = tr("The assistant stopped unexpectedly.");
            finishReply(m_chatError);
        }
        proc->deleteLater();
    });
    proc->start();
    proc->write(QJsonDocument(QJsonObject{{QStringLiteral("messages"), history}}).toJson(QJsonDocument::Compact));
    proc->closeWriteChannel();
    emit busyChanged();
}

void AiAssistant::finishReply(const QString &error)
{
    if (!m_partial.isEmpty())
        m_messages.append(QVariantMap{{QStringLiteral("role"), QStringLiteral("assistant")},
                                      {QStringLiteral("text"), m_partial},
                                      {QStringLiteral("provider"), m_replyProvider}});
    if (!error.isEmpty())
        m_messages.append(QVariantMap{{QStringLiteral("role"), QStringLiteral("assistant")},
                                      {QStringLiteral("text"), error},
                                      {QStringLiteral("error"), true}});
    m_partial.clear();
    m_chat = nullptr;
    emit messagesChanged();
    emit partialChanged();
    emit busyChanged();
}

void AiAssistant::stop()
{
    if (!m_chat)
        return;
    QProcess *proc = m_chat;
    proc->disconnect(this);
    proc->kill();
    connect(proc, &QProcess::finished, proc, &QObject::deleteLater);
    finishReply(QString());
}

void AiAssistant::clear()
{
    stop();
    m_messages.clear();
    emit messagesChanged();
}

void AiAssistant::copyLast()
{
    for (auto it = m_messages.crbegin(); it != m_messages.crend(); ++it) {
        const QVariantMap m = it->toMap();
        if (m.value(QStringLiteral("role")) == QLatin1String("assistant") && !m.value(QStringLiteral("error")).toBool()) {
            QGuiApplication::clipboard()->setText(m.value(QStringLiteral("text")).toString());
            return;
        }
    }
}

// ---- Settings ----

void AiAssistant::addPreset(const QString &preset, const QString &key, const QString &url)
{
    QStringList args{QStringLiteral("add"), preset, QStringLiteral("--default")};
    if (!url.isEmpty())
        args << QStringLiteral("--url") << url;
    run(args, {}, [this, key](int code, const QByteArray &out) {
        if (code != 0) {
            setNotice(errorOf(out), true);
            return;
        }
        const QString id = QJsonDocument::fromJson(out).object().value(QStringLiteral("provider")).toObject()
                               .value(QStringLiteral("id")).toString();
        if (key.trimmed().isEmpty()) {
            refresh();
            return;
        }
        saveKey(id, key);
    });
}

void AiAssistant::saveKey(const QString &id, const QString &key)
{
    // The key travels over stdin, never on a command line other processes can see.
    run({QStringLiteral("key"), QStringLiteral("set"), id}, key.trimmed().toUtf8() + '\n', [this, id](int code, const QByteArray &out) {
        if (code != 0) {
            setNotice(errorOf(out), true);
            refresh();
            return;
        }
        // Check the key works (and pick a model when none is chosen yet).
        run({QStringLiteral("test"), id}, {}, [this](int code, const QByteArray &out) {
            if (code == 0) {
                const QJsonObject o = QJsonDocument::fromJson(out).object();
                setNotice(tr("Connected. Using %1.").arg(o.value(QStringLiteral("model")).toString()), false);
            } else {
                setNotice(errorOf(out), true);
            }
            refresh();
        });
    });
}

void AiAssistant::addServer(const QVariantMap &server)
{
    const QString where = server.value(QStringLiteral("where")).toString();
    const QString kind = server.value(QStringLiteral("server")).toString();
    const QString host = server.value(QStringLiteral("host")).toString();
    QString id = where == QLatin1String("local") ? kind : kind + QLatin1Char('-') + QString(host).replace(QLatin1Char('.'), QLatin1Char('-'));
    const QJsonObject p{{QStringLiteral("id"), id},
                        {QStringLiteral("name"), server.value(QStringLiteral("label")).toString()},
                        {QStringLiteral("kind"), QStringLiteral("openai")},
                        {QStringLiteral("url"), server.value(QStringLiteral("url")).toString()},
                        {QStringLiteral("where"), where},
                        {QStringLiteral("server"), kind}};
    run({QStringLiteral("add"), QStringLiteral("--default"), QStringLiteral("--from-json"),
         QString::fromUtf8(QJsonDocument(p).toJson(QJsonDocument::Compact))}, {},
        [this](int code, const QByteArray &out) {
            if (code != 0) {
                setNotice(errorOf(out), true);
                return;
            }
            const QString id = QJsonDocument::fromJson(out).object().value(QStringLiteral("provider")).toObject()
                                   .value(QStringLiteral("id")).toString();
            run({QStringLiteral("test"), id}, {}, [this](int code, const QByteArray &out) {
                if (code == 0)
                    setNotice(tr("Connected. Using %1.").arg(QJsonDocument::fromJson(out).object().value(QStringLiteral("model")).toString()), false);
                else
                    setNotice(errorOf(out), true);
                refresh();
            });
        });
}

void AiAssistant::addAddress(const QString &address)
{
    // "192.168.1.20", "studio.local:1234", or a full URL.
    QString a = address.trimmed();
    if (a.isEmpty())
        return;
    if (!a.contains(QLatin1String("://")))
        a.prepend(QLatin1String("http://"));
    QUrl url(a);
    if (!url.isValid() || url.host().isEmpty()) {
        setNotice(tr("That doesn't look like an address."), true);
        return;
    }
    if (url.port() < 0)
        url.setPort(11434);
    if (url.path().isEmpty() || url.path() == QLatin1String("/"))
        url.setPath(QStringLiteral("/v1"));
    const bool local = url.host() == QLatin1String("localhost") || url.host() == QLatin1String("127.0.0.1");
    addServer({{QStringLiteral("server"), url.port() == 11434 ? QStringLiteral("ollama") : QStringLiteral("openai")},
               {QStringLiteral("host"), url.host()},
               {QStringLiteral("url"), url.toString()},
               {QStringLiteral("where"), local ? QStringLiteral("local") : QStringLiteral("network")},
               {QStringLiteral("label"), (url.port() == 11434 ? tr("Ollama on %1") : tr("AI server on %1")).arg(url.host())}});
}

void AiAssistant::remove(const QString &id)
{
    run({QStringLiteral("remove"), id}, {}, [this](int, const QByteArray &) { refresh(); });
}

void AiAssistant::setDefault(const QString &id)
{
    run({QStringLiteral("default"), id}, {}, [this](int, const QByteArray &) { refresh(); });
}

void AiAssistant::setModel(const QString &id, const QString &model)
{
    run({QStringLiteral("model"), id, model}, {}, [this](int, const QByteArray &) { refresh(); });
}

void AiAssistant::loadModels(const QString &id)
{
    run({QStringLiteral("models"), id}, {}, [this, id](int code, const QByteArray &out) {
        const QJsonObject o = QJsonDocument::fromJson(out).object();
        m_models[id] = code == 0 ? o.value(QStringLiteral("models")).toArray().toVariantList() : QVariantList();
        emit modelsChanged();
        if (code != 0)
            setNotice(errorOf(out), true);
    });
}

void AiAssistant::discover(bool network)
{
    if (m_discovering)
        return;
    m_discovering = true;
    emit serversChanged();
    QStringList args{QStringLiteral("discover")};
    if (network)
        args << QStringLiteral("--network");
    run(args, {}, [this, network](int, const QByteArray &out) {
        m_servers = QJsonDocument::fromJson(out).object().value(QStringLiteral("servers")).toArray().toVariantList();
        m_discovering = false;
        m_searchedNetwork = m_searchedNetwork || network;
        emit serversChanged();
    });
}

void AiAssistant::setGateway(bool on)
{
    run({QStringLiteral("gateway"), on ? QStringLiteral("on") : QStringLiteral("off")}, {},
        [this](int, const QByteArray &) { refresh(); });
}

void AiAssistant::setupLocal()
{
    // In a terminal, so the person sees the download and can answer the
    // password prompt for installing Ollama.
    if (!QProcess::startDetached(QStringLiteral("konsole"),
                                 {QStringLiteral("--hold"), QStringLiteral("-e"), m_program, QStringLiteral("local"), QStringLiteral("setup")}))
        setNotice(tr("Couldn't open a terminal. Run “mpire-ai local setup” yourself."), true);
}
