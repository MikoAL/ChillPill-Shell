#pragma once

#include <QElapsedTimer>
#include <QObject>
#include <QRegularExpression>
#include <QTimer>
#include <QtQml/qqml.h>

// Live system metrics for the pill bar: aggregate CPU %, RAM usage and
// per-second network throughput, sampled from /proc without spawning any
// subprocess. One QTimer drives everything; the QML side only formats.
//
// - CPU % is the delta of busy jiffies over delta of total jiffies between
//   two consecutive ticks (first tick reports 0).
// - RAM % uses MemTotal/MemAvailable (not MemFree).
// - Net rates are byte deltas divided by the real elapsed time, excluding
//   loopback and (configurable) virtual interfaces; 32-bit counter wraps
//   are clamped to 0.
class SysMonitor final : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    QML_UNCREATABLE("Singleton")

    Q_PROPERTY(int interval READ interval WRITE setInterval NOTIFY intervalChanged)
    Q_PROPERTY(bool running READ running WRITE setRunning NOTIFY runningChanged)
    Q_PROPERTY(QString netExcludeInterfaces READ netExcludeInterfaces WRITE setNetExcludeInterfaces NOTIFY netExcludeInterfacesChanged)
    Q_PROPERTY(qreal cpuPercent READ cpuPercent NOTIFY cpuPercentChanged)
    Q_PROPERTY(qreal ramPercent READ ramPercent NOTIFY ramPercentChanged)
    Q_PROPERTY(qreal ramUsedBytes READ ramUsedBytes NOTIFY ramUsedBytesChanged)
    Q_PROPERTY(qreal ramTotalBytes READ ramTotalBytes NOTIFY ramTotalBytesChanged)
    Q_PROPERTY(qreal rxBytesPerSec READ rxBytesPerSec NOTIFY rxBytesPerSecChanged)
    Q_PROPERTY(qreal txBytesPerSec READ txBytesPerSec NOTIFY txBytesPerSecChanged)

public:
    explicit SysMonitor(QObject *parent = nullptr);

    int interval() const;
    void setInterval(int ms);

    bool running() const;
    void setRunning(bool running);

    QString netExcludeInterfaces() const;
    void setNetExcludeInterfaces(const QString &pattern);

    qreal cpuPercent() const;
    qreal ramPercent() const;
    qreal ramUsedBytes() const;
    qreal ramTotalBytes() const;
    qreal rxBytesPerSec() const;
    qreal txBytesPerSec() const;

signals:
    void intervalChanged();
    void runningChanged();
    void netExcludeInterfacesChanged();
    void cpuPercentChanged();
    void ramPercentChanged();
    void ramUsedBytesChanged();
    void ramTotalBytesChanged();
    void rxBytesPerSecChanged();
    void txBytesPerSecChanged();

private:
    void sample();
    void readCpu();
    void readMemory();
    void readNet();

    QTimer m_timer;
    QElapsedTimer m_elapsed;

    // cpu
    quint64 m_prevIdle = 0;
    quint64 m_prevTotal = 0;
    bool m_firstCpuTick = true;

    // net
    quint64 m_prevRx = 0;
    quint64 m_prevTx = 0;
    bool m_firstNetTick = true;

    int m_interval = 2000;
    bool m_running = true;
    qreal m_cpuPercent = 0.0;
    qreal m_ramPercent = 0.0;
    qreal m_ramUsedBytes = 0.0;
    qreal m_ramTotalBytes = 0.0;
    qreal m_rxBytesPerSec = 0.0;
    qreal m_txBytesPerSec = 0.0;
    QRegularExpression m_netExcludeRegex{
        QStringLiteral("^(lo|docker|veth|br-|virbr|tun|wg)")};
};
