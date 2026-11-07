#include "rfidservice.h"
#include "rfid/iso14443.h"

#include <QDebug>
#include <QTimer>

#if KIOSK_HAVE_MFRC522
#  include "rfid/mfrc522.h"
#  include <format>
#  include <memory>
#endif

// ---- worker (lives in its own thread) ----------------------------------------

class RfidWorker : public QObject
{
    Q_OBJECT
public:
    void start()
    {
#if KIOSK_HAVE_MFRC522
        rfid::Mfrc522::Config cfg;
        if (qEnvironmentVariableIsSet("KIOSK_RFID_SPI"))
            cfg.spiDevice = qEnvironmentVariable("KIOSK_RFID_SPI").toStdString();
        if (qEnvironmentVariableIsSet("KIOSK_RFID_RST_GPIO"))
            cfg.resetGpio = qEnvironmentVariableIntValue("KIOSK_RFID_RST_GPIO");
        if (qEnvironmentVariableIsSet("KIOSK_RFID_GPIOCHIP"))
            cfg.gpioChip = qEnvironmentVariable("KIOSK_RFID_GPIOCHIP").toStdString();
        m_reader = std::make_unique<rfid::Mfrc522>(cfg);

        m_timer = new QTimer(this);
        connect(m_timer, &QTimer::timeout, this, &RfidWorker::tick);
        m_timer->start(0);
#else
        emit status(false, QStringLiteral("No reader driver on this platform — use the simulator"),
                    QStringLiteral("Simulator"));
#endif
    }

signals:
    void status(bool ready, const QString &text, const QString &info);
    void card(const QString &uid, const QString &type);
    void gone();

private:
#if KIOSK_HAVE_MFRC522
    static constexpr int kPollMs = 80;     // ~12 polls/s: snappy without hogging SPI
    static constexpr int kRetryMs = 3000;  // when the reader is missing
    static constexpr int kMissesToRemove = 3;

    void tick()
    {
        if (!m_reader->isOpen()) {
            auto v = m_reader->open();
            if (!v) {
                reportStatus(false, QString::fromStdString(v.error()), {});
                m_timer->setInterval(kRetryMs);
                return;
            }
            const char *chip = *v == 0x92 ? "MFRC522 v2.0" : *v == 0x91 ? "MFRC522 v1.0" : "MFRC522-compatible";
            reportStatus(true, QStringLiteral("Ready — hold a card to the reader"),
                         QString::fromStdString(std::format("{} (0x{:02X}) · {}", chip, *v, m_reader->notes())));
            m_timer->setInterval(kPollMs);
            m_healthTicks = 0;
        }

        auto r = m_reader->poll();
        if (!r) {
            reportStatus(false, QString::fromStdString(r.error()), {});
            m_reader->close();
            if (m_present) { m_present = false; emit gone(); }
            m_timer->setInterval(kRetryMs);
            return;
        }

        if (const auto &c = *r) {
            m_misses = 0;
            const QString uid = QString::fromStdString(rfid::formatUid(c->uid));
            if (!m_present || uid != m_uid) {
                m_present = true;
                m_uid = uid;
                emit card(uid, QString::fromLatin1(rfid::cardTypeFromSak(c->sak)));
            }
        } else if (m_present && ++m_misses >= kMissesToRemove) {
            m_present = false;
            m_uid.clear();
            emit gone();
        }

        // Clone boards occasionally wedge; re-open if VersionReg stops making sense.
        if (++m_healthTicks % 60 == 0 && !m_reader->alive()) {
            m_reader->close();
            reportStatus(false, QStringLiteral("Reader stopped responding — reconnecting…"), {});
        }
    }

    void reportStatus(bool ready, const QString &text, const QString &info)
    {
        if (ready == m_ready && text == m_lastText) return;
        m_ready = ready;
        m_lastText = text;
        emit status(ready, text, info);
    }

    std::unique_ptr<rfid::Mfrc522> m_reader;
    QTimer *m_timer = nullptr;
    bool m_present = false;
    bool m_ready = false;
    QString m_uid;
    QString m_lastText;
    int m_misses = 0;
    int m_healthTicks = 0;
#endif
};

// ---- service (GUI thread) --------------------------------------------------------

RfidService::RfidService(QObject *parent)
    : QObject(parent)
{
    m_worker = new RfidWorker;
    m_worker->moveToThread(&m_thread);
    connect(&m_thread, &QThread::started, m_worker, &RfidWorker::start);
    connect(&m_thread, &QThread::finished, m_worker, &QObject::deleteLater);
    connect(m_worker, &RfidWorker::status, this, &RfidService::onStatus);
    connect(m_worker, &RfidWorker::card, this, &RfidService::onCard);
    connect(m_worker, &RfidWorker::gone, this, &RfidService::onGone);
    m_thread.setObjectName(QStringLiteral("rfid"));
    m_thread.start();
}

RfidService::~RfidService()
{
    m_thread.quit();
    m_thread.wait();
}

bool RfidService::hardwareSupport() const { return KIOSK_HAVE_MFRC522; }

void RfidService::simulateTap(const QString &uid, const QString &type)
{
    onCard(uid, type);
    QTimer::singleShot(700, this, &RfidService::onGone);
}

void RfidService::onStatus(bool ready, const QString &status, const QString &info)
{
    qInfo().noquote() << "rfid:" << (ready ? "ready" : "not ready") << "-" << status << (info.isEmpty() ? QString() : "- " + info);
    m_ready = ready;
    m_status = status;
    if (!info.isEmpty())
        m_info = info;
    emit statusChanged();
}

void RfidService::onCard(const QString &uid, const QString &type)
{
    qInfo().noquote() << "rfid: card" << uid << "(" + type + ")";
    m_present = true;
    m_uid = uid;
    m_type = type;
    ++m_reads;
    emit cardChanged();
    emit tapped(uid, type);
}

void RfidService::onGone()
{
    if (!m_present) return;
    m_present = false;
    emit cardChanged();
    emit removed();
}

#include "rfidservice.moc"
