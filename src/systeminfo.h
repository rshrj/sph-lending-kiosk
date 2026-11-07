#pragma once

#include <QObject>
#include <QStringList>
#include <QTimer>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>

#include <cstdint>
#include <deque>

// Live system facts for the "System" page. Polls once a second.
// Linux (the Pi) gets everything; macOS gets what it can so the UI is testable on the Mac.
class SystemInfo : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(QString hostName READ hostName CONSTANT)
    Q_PROPERTY(QString osName READ osName CONSTANT)
    Q_PROPERTY(QString kernel READ kernel CONSTANT)
    Q_PROPERTY(QString cpuArch READ cpuArch CONSTANT)
    Q_PROPERTY(QString qtVersion READ qtVersion CONSTANT)
    Q_PROPERTY(QString buildInfo READ buildInfo CONSTANT)
    Q_PROPERTY(QString platformName READ platformName CONSTANT)
    Q_PROPERTY(QString deviceModel READ deviceModel CONSTANT)
    Q_PROPERTY(bool isRaspberryPi READ isRaspberryPi CONSTANT)

    Q_PROPERTY(QStringList ipAddresses READ ipAddresses NOTIFY updated)
    Q_PROPERTY(QString uptime READ uptime NOTIFY updated)
    Q_PROPERTY(double cpuLoad READ cpuLoad NOTIFY updated)               // 0..100, -1 = n/a
    Q_PROPERTY(double cpuTemperature READ cpuTemperature NOTIFY updated) // °C,  -1 = n/a
    Q_PROPERTY(double memoryUsedMiB READ memoryUsedMiB NOTIFY updated)   // -1 = n/a
    Q_PROPERTY(double memoryTotalMiB READ memoryTotalMiB NOTIFY updated)
    Q_PROPERTY(QVariantList loadHistory READ loadHistory NOTIFY updated)
    Q_PROPERTY(QVariantList tempHistory READ tempHistory NOTIFY updated)
    Q_PROPERTY(QVariantList inputDevices READ inputDevices NOTIFY inputDevicesChanged)

public:
    explicit SystemInfo(QObject *parent = nullptr);

    [[nodiscard]] QString hostName() const;
    [[nodiscard]] QString osName() const;
    [[nodiscard]] QString kernel() const;
    [[nodiscard]] QString cpuArch() const;
    [[nodiscard]] QString qtVersion() const;
    [[nodiscard]] QString buildInfo() const;
    [[nodiscard]] QString platformName() const;
    [[nodiscard]] QString deviceModel() const { return m_model; }
    [[nodiscard]] bool isRaspberryPi() const { return m_isPi; }

    [[nodiscard]] QStringList ipAddresses() const { return m_ips; }
    [[nodiscard]] QString uptime() const { return m_uptime; }
    [[nodiscard]] double cpuLoad() const { return m_load; }
    [[nodiscard]] double cpuTemperature() const { return m_temp; }
    [[nodiscard]] double memoryUsedMiB() const { return m_memUsed; }
    [[nodiscard]] double memoryTotalMiB() const { return m_memTotal; }
    [[nodiscard]] QVariantList loadHistory() const { return toList(m_loadHist); }
    [[nodiscard]] QVariantList tempHistory() const { return toList(m_tempHist); }
    [[nodiscard]] QVariantList inputDevices() const;

signals:
    void updated();
    void inputDevicesChanged();

private:
    struct CpuTimes {
        std::uint64_t busy = 0;
        std::uint64_t total = 0;
    };

    void poll();
    static QVariantList toList(const std::deque<double> &d);
    static void push(std::deque<double> &d, double v);

    QTimer m_timer;
    QString m_model;
    bool m_isPi = false;
    int m_deviceCount = 0;
    CpuTimes m_prevCpu;
    QStringList m_ips;
    QString m_uptime;
    double m_load = -1;
    double m_temp = -1;
    double m_memUsed = -1;
    double m_memTotal = -1;
    std::deque<double> m_loadHist;
    std::deque<double> m_tempHist;
};
