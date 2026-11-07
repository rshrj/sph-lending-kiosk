#pragma once

#include <QObject>
#include <QTimer>
#include <QtQml/qqmlregistration.h>

// Watches every input event in the application and flips `idle` after
// `timeout` seconds without one. Drives the attract screen / kiosk reset.
class IdleMonitor : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(bool idle READ idle NOTIFY idleChanged)
    Q_PROPERTY(int timeout READ timeout WRITE setTimeout NOTIFY timeoutChanged) // seconds, 0 = never

public:
    explicit IdleMonitor(QObject *parent = nullptr);

    [[nodiscard]] bool idle() const { return m_idle; }
    [[nodiscard]] int timeout() const { return m_timeoutSec; }
    void setTimeout(int seconds);

    Q_INVOKABLE void goIdle();  // e.g. "preview attract screen"
    Q_INVOKABLE void wake();

signals:
    void idleChanged();
    void timeoutChanged();
    void activity(); // emitted (throttled) on user input

protected:
    bool eventFilter(QObject *watched, QEvent *event) override;

private:
    void setIdle(bool idle);
    void restart();

    QTimer m_timer;
    int m_timeoutSec = 45;
    bool m_idle = false;
};
