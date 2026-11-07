#include "idlemonitor.h"

#include <QCoreApplication>
#include <QEvent>

#include <algorithm>
#include <chrono>

using namespace std::chrono_literals;

IdleMonitor::IdleMonitor(QObject *parent)
    : QObject(parent)
{
    m_timer.setSingleShot(true);
    connect(&m_timer, &QTimer::timeout, this, [this] { setIdle(true); });
    QCoreApplication::instance()->installEventFilter(this);
    restart();
}

void IdleMonitor::setTimeout(int seconds)
{
    seconds = std::max(0, seconds);
    if (seconds == m_timeoutSec)
        return;
    m_timeoutSec = seconds;
    emit timeoutChanged();
    restart();
}

void IdleMonitor::goIdle()
{
    m_timer.stop();
    setIdle(true);
}

void IdleMonitor::wake()
{
    setIdle(false);
    restart();
}

bool IdleMonitor::eventFilter(QObject *watched, QEvent *event)
{
    switch (event->type()) {
    case QEvent::TouchBegin:
    case QEvent::TouchUpdate:
    case QEvent::MouseButtonPress:
    case QEvent::MouseMove:
    case QEvent::Wheel:
    case QEvent::KeyPress:
    case QEvent::TabletPress:
    case QEvent::NativeGesture:
        // The same physical event reaches several objects (window, items…);
        // only act when the timer actually needs to move.
        if (m_idle)
            wake();
        else if (m_timer.remainingTime() < m_timeoutSec * 1000 - 250)
            restart();
        break;
    default:
        break;
    }
    return QObject::eventFilter(watched, event);
}

void IdleMonitor::setIdle(bool idle)
{
    if (idle == m_idle)
        return;
    m_idle = idle;
    emit idleChanged();
}

void IdleMonitor::restart()
{
    if (m_timeoutSec <= 0) {
        m_timer.stop();
        return;
    }
    m_timer.start(std::chrono::seconds(m_timeoutSec));
    emit activity();
}
