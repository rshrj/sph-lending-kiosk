#pragma once

#include <QJSValue>
#include <QNetworkAccessManager>
#include <QNetworkRequest>
#include <QObject>
#include <QTimer>
#include <QUrl>
#include <QtQml/qqmlregistration.h>

class QNetworkReply;

// QML singleton `Backend`: JSON client for the inventory server (backend/, FastAPI on :8000).
//
//   Backend.get("/items", r => { if (r.ok) use(r.data) else Notify.error(r.error) })
//   Backend.post("/loans", { user_id: 1, item_ids: [3, 4] }, r => …)
//
// Every callback gets { ok, status, data, error, problems }. `error` is the server's
// UI-ready message (or a connection message when status is 0). /health is polled so the
// UI can show whether the server and its camera are up.
class Backend : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(QUrl baseUrl READ baseUrl WRITE setBaseUrl NOTIFY baseUrlChanged)
    Q_PROPERTY(bool online READ online NOTIFY healthChanged)
    Q_PROPERTY(bool cameraReady READ cameraReady NOTIFY healthChanged)
    Q_PROPERTY(QString cameraDevice READ cameraDevice NOTIFY healthChanged)
    Q_PROPERTY(int busy READ busy NOTIFY busyChanged) // requests in flight
    // Set while the staff panel is unlocked; sent as X-Staff-Pin on every request. Cleared on lock.
    Q_PROPERTY(QString staffPin READ staffPin WRITE setStaffPin NOTIFY staffPinChanged)

public:
    explicit Backend(QObject *parent = nullptr);

    // Set from main() before QML loads (--backend / KIOSK_BACKEND_URL).
    static void setDefaultBaseUrl(const QUrl &url);

    [[nodiscard]] QUrl baseUrl() const { return m_base; }
    void setBaseUrl(const QUrl &url);
    [[nodiscard]] bool online() const { return m_online; }
    [[nodiscard]] bool cameraReady() const { return m_cameraReady; }
    [[nodiscard]] QString cameraDevice() const { return m_cameraDevice; }
    [[nodiscard]] int busy() const { return m_busy; }
    [[nodiscard]] QString staffPin() const { return m_staffPin; }
    void setStaffPin(const QString &pin);

    Q_INVOKABLE void get(const QString &path, const QJSValue &callback = {}, int timeoutMs = 6000);
    Q_INVOKABLE void post(const QString &path, const QVariant &body = {}, const QJSValue &callback = {},
                          int timeoutMs = 8000);
    Q_INVOKABLE QUrl url(const QString &path) const;
    Q_INVOKABLE void checkHealth();

signals:
    void baseUrlChanged();
    void healthChanged();
    void busyChanged();
    void staffPinChanged();

private:
    void send(QNetworkReply *reply, const QJSValue &callback);
    [[nodiscard]] QNetworkRequest request(const QString &path, int timeoutMs) const;
    void setHealth(bool online, bool cameraReady, const QString &device);

    QNetworkAccessManager m_nam;
    QUrl m_base;
    QTimer m_healthTimer;
    bool m_healthInFlight = false;
    bool m_online = false;
    bool m_cameraReady = false;
    QString m_cameraDevice;
    int m_busy = 0;
    QString m_staffPin;
};
