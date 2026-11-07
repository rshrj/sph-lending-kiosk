#include "backend.h"

#include <QJSEngine>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QVariantMap>
#include <QtQml/qqml.h>

using namespace Qt::StringLiterals;

namespace {

QUrl g_defaultBase(u"http://127.0.0.1:8000"_s);
constexpr int kHealthEveryMs = 3000;
constexpr int kHealthTimeoutMs = 2500;

QString messageFor(const QVariant &data, int status)
{
    const QVariantMap m = data.toMap();
    if (const QString e = m.value(u"error"_s).toString(); !e.isEmpty())
        return e;
    // FastAPI's own errors: {"detail": "..."} or a validation list
    if (const QVariant d = m.value(u"detail"_s); d.typeId() == QMetaType::QString)
        return d.toString();
    return u"The inventory server answered with an error (%1)"_s.arg(status);
}

} // namespace

Backend::Backend(QObject *parent)
    : QObject(parent)
    , m_base(g_defaultBase)
{
    m_healthTimer.setInterval(kHealthEveryMs);
    connect(&m_healthTimer, &QTimer::timeout, this, &Backend::checkHealth);
    m_healthTimer.start();
    QTimer::singleShot(0, this, &Backend::checkHealth);
}

void Backend::setDefaultBaseUrl(const QUrl &url) { g_defaultBase = url; }

void Backend::setBaseUrl(const QUrl &url)
{
    if (url == m_base) return;
    m_base = url;
    emit baseUrlChanged();
    checkHealth();
}

QUrl Backend::url(const QString &path) const
{
    QString base = m_base.toString();
    if (base.endsWith(u'/')) base.chop(1);
    return QUrl(base + (path.startsWith(u'/') ? path : u'/' + path));
}

void Backend::get(const QString &path, const QJSValue &callback, int timeoutMs)
{
    send(m_nam.get(request(path, timeoutMs)), callback);
}

void Backend::post(const QString &path, const QVariant &body, const QJSValue &callback, int timeoutMs)
{
    QNetworkRequest req = request(path, timeoutMs);
    QByteArray payload;
    if (body.isValid() && !body.isNull()) {
        // QML hands JS objects over as QJSValue; unwrap to plain variants for JSON.
        const QVariant v = body.canConvert<QJSValue>() ? body.value<QJSValue>().toVariant() : body;
        payload = QJsonDocument::fromVariant(v).toJson(QJsonDocument::Compact);
        req.setHeader(QNetworkRequest::ContentTypeHeader, u"application/json"_s);
    }
    send(m_nam.post(req, payload), callback);
}

QNetworkRequest Backend::request(const QString &path, int timeoutMs) const
{
    QNetworkRequest req(url(path));
    req.setTransferTimeout(timeoutMs);
    if (!m_staffPin.isEmpty())
        req.setRawHeader("X-Staff-Pin", m_staffPin.toUtf8());
    return req;
}

void Backend::setStaffPin(const QString &pin)
{
    if (pin == m_staffPin) return;
    m_staffPin = pin;
    emit staffPinChanged();
}

void Backend::send(QNetworkReply *reply, const QJSValue &callback)
{
    ++m_busy;
    emit busyChanged();
    connect(reply, &QNetworkReply::finished, this, [this, reply, callback] {
        reply->deleteLater();
        --m_busy;
        emit busyChanged();

        const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const QByteArray bytes = reply->readAll();
        QJsonParseError perr{};
        const QJsonDocument doc = QJsonDocument::fromJson(bytes, &perr);
        const QVariant data = perr.error == QJsonParseError::NoError ? doc.toVariant() : QVariant();

        QVariantMap result;
        result[u"status"_s] = status;
        result[u"data"_s] = data;
        const bool ok = status >= 200 && status < 300;
        result[u"ok"_s] = ok;
        if (status == 0) {
            const bool timedOut = reply->error() == QNetworkReply::OperationCanceledError
                                  || reply->error() == QNetworkReply::TimeoutError;
            result[u"error"_s] = timedOut ? u"The inventory server is not answering"_s
                                          : u"Can't reach the inventory server"_s;
            qWarning().noquote() << "backend:" << reply->url().path() << "-" << reply->errorString();
            if (m_online) setHealth(false, false, m_cameraDevice);
        } else if (!ok) {
            result[u"error"_s] = messageFor(data, status);
            qInfo().noquote() << "backend:" << (reply->operation() == QNetworkAccessManager::PostOperation ? "POST" : "GET")
                              << reply->url().path() << "->" << status
                              << result[u"error"_s].toString();
            result[u"problems"_s] = data.toMap().value(u"problems"_s);
        }

        if (!callback.isCallable()) return;
        QJSEngine *engine = qjsEngine(this);
        if (!engine) return;
        const QJSValue r = QJSValue(callback).call({engine->toScriptValue(result)});
        if (r.isError())
            qWarning().noquote() << "backend: callback for" << reply->url().path() << "threw:" << r.toString();
    });
}

void Backend::checkHealth()
{
    if (m_healthInFlight) return;
    m_healthInFlight = true;
    QNetworkRequest req(url(u"/health"_s));
    req.setTransferTimeout(kHealthTimeoutMs);
    QNetworkReply *reply = m_nam.get(req);
    connect(reply, &QNetworkReply::finished, this, [this, reply] {
        reply->deleteLater();
        m_healthInFlight = false;
        const QJsonObject o = QJsonDocument::fromJson(reply->readAll()).object();
        if (reply->error() != QNetworkReply::NoError || !o.value(u"ok"_s).toBool()) {
            setHealth(false, false, m_cameraDevice);
            return;
        }
        const QJsonObject cam = o.value(u"camera"_s).toObject();
        setHealth(true, cam.value(u"ready"_s).toBool(), cam.value(u"device"_s).toString());
    });
}

void Backend::setHealth(bool online, bool cameraReady, const QString &device)
{
    if (online == m_online && cameraReady == m_cameraReady && device == m_cameraDevice) return;
    if (online != m_online)
        qInfo().noquote() << "backend:" << (online ? "online" : "offline") << m_base.toString();
    m_online = online;
    m_cameraReady = cameraReady;
    m_cameraDevice = device;
    emit healthChanged();
}
