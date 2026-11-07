#pragma once

#include <QObject>
#include <QThread>
#include <QtQml/qqmlregistration.h>

class RfidWorker;

// QML singleton `Rfid`: card reader events for the UI.
// On Linux it drives an MFRC522 on SPI in a worker thread; everywhere it also
// accepts simulated taps so the login flow can be built without hardware.
class RfidService : public QObject
{
    Q_OBJECT
    QML_NAMED_ELEMENT(Rfid)
    QML_SINGLETON

    Q_PROPERTY(bool hardwareSupport READ hardwareSupport CONSTANT) // built with the MFRC522 driver
    Q_PROPERTY(bool ready READ ready NOTIFY statusChanged)         // a reader is answering
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)
    Q_PROPERTY(QString readerInfo READ readerInfo NOTIFY statusChanged)
    Q_PROPERTY(bool cardPresent READ cardPresent NOTIFY cardChanged)
    Q_PROPERTY(QString lastUid READ lastUid NOTIFY cardChanged)
    Q_PROPERTY(QString lastType READ lastType NOTIFY cardChanged)
    Q_PROPERTY(int readCount READ readCount NOTIFY cardChanged)

public:
    explicit RfidService(QObject *parent = nullptr);
    ~RfidService() override;

    [[nodiscard]] bool hardwareSupport() const;
    [[nodiscard]] bool ready() const { return m_ready; }
    [[nodiscard]] QString status() const { return m_status; }
    [[nodiscard]] QString readerInfo() const { return m_info; }
    [[nodiscard]] bool cardPresent() const { return m_present; }
    [[nodiscard]] QString lastUid() const { return m_uid; }
    [[nodiscard]] QString lastType() const { return m_type; }
    [[nodiscard]] int readCount() const { return m_reads; }

    Q_INVOKABLE void simulateTap(const QString &uid, const QString &type = QStringLiteral("Simulated card"));

signals:
    void tapped(const QString &uid, const QString &type); // a card arrived in the field
    void removed();
    void statusChanged();
    void cardChanged();

private:
    void onStatus(bool ready, const QString &status, const QString &info);
    void onCard(const QString &uid, const QString &type);
    void onGone();

    QThread m_thread;
    RfidWorker *m_worker = nullptr;
    bool m_ready = false;
    QString m_status = QStringLiteral("Starting…");
    QString m_info;
    bool m_present = false;
    QString m_uid;
    QString m_type;
    int m_reads = 0;
};
