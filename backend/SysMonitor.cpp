#include "SysMonitor.h"

#include <QFile>
#include <QTextStream>

namespace {

constexpr qint64 kKiB = 1024;

// First line of /proc/stat: "cpu  user nice system idle iowait irq softirq steal guest guest_nice"
struct CpuTimes {
    quint64 busy = 0;   // user+nice+system+irq+softirq+steal
    quint64 total = 0;  // every field
};

CpuTimes parseCpuTimes(const QString &line) {
    CpuTimes t;
    const QStringList fields = line.split(QRegularExpression(QStringLiteral("\\s+")));
    // fields[0] == "cpu"; skip it. Anything missing is treated as 0.
    const auto val = [&fields](int idx) -> quint64 {
        return idx < fields.size() ? fields.at(idx).toULongLong() : 0;
    };
    const quint64 user = val(1);
    const quint64 nice = val(2);
    const quint64 system = val(3);
    const quint64 idle = val(4);
    const quint64 iowait = val(5);
    const quint64 irq = val(6);
    const quint64 softirq = val(7);
    const quint64 steal = val(8);
    const quint64 guest = val(9);
    const quint64 guestNice = val(10);

    t.busy = user + nice + system + irq + softirq + steal;
    t.total = user + nice + system + idle + iowait + irq + softirq + steal + guest + guestNice;
    return t;
}

} // namespace

SysMonitor::SysMonitor(QObject *parent)
    : QObject(parent) {
    m_elapsed.start();

    m_timer.setInterval(m_interval);
    connect(&m_timer, &QTimer::timeout, this, &SysMonitor::sample);

    // First tick reports 0 for cpu/net (no delta baseline yet); RAM is valid
    // immediately, so read it once up front.
    readMemory();
    if (m_running)
        m_timer.start();
}

int SysMonitor::interval() const {
    return m_interval;
}

void SysMonitor::setInterval(int ms) {
    if (ms == m_interval)
        return;
    m_interval = ms > 0 ? ms : 2000;
    m_timer.setInterval(m_interval);
    emit intervalChanged();
    if (m_running)
        m_timer.start();
}

bool SysMonitor::running() const {
    return m_running;
}

void SysMonitor::setRunning(bool running) {
    if (running == m_running)
        return;
    m_running = running;
    if (m_running) {
        // Re-establish deltas so the next tick isn't a huge jump.
        m_firstCpuTick = true;
        m_firstNetTick = true;
        m_elapsed.restart();
        sample();
        m_timer.start();
    } else {
        m_timer.stop();
    }
    emit runningChanged();
}

QString SysMonitor::netExcludeInterfaces() const {
    return m_netExcludeRegex.pattern();
}

void SysMonitor::setNetExcludeInterfaces(const QString &pattern) {
    const QString trimmed = pattern.trimmed();
    if (trimmed.isEmpty() || trimmed == m_netExcludeRegex.pattern())
        return;
    m_netExcludeRegex.setPattern(trimmed);
    m_firstNetTick = true;
    emit netExcludeInterfacesChanged();
}

qreal SysMonitor::cpuPercent() const {
    return m_cpuPercent;
}

qreal SysMonitor::ramPercent() const {
    return m_ramPercent;
}

qreal SysMonitor::ramUsedBytes() const {
    return m_ramUsedBytes;
}

qreal SysMonitor::ramTotalBytes() const {
    return m_ramTotalBytes;
}

qreal SysMonitor::rxBytesPerSec() const {
    return m_rxBytesPerSec;
}

qreal SysMonitor::txBytesPerSec() const {
    return m_txBytesPerSec;
}

void SysMonitor::sample() {
    readCpu();
    readMemory();
    readNet();
}

void SysMonitor::readCpu() {
    QFile file(QStringLiteral("/proc/stat"));
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
        return;

    const QString firstLine = QString::fromLatin1(file.readLine());
    file.close();

    if (!firstLine.startsWith(QStringLiteral("cpu")))
        return;

    const CpuTimes t = parseCpuTimes(firstLine);

    if (m_firstCpuTick) {
        m_prevIdle = t.total - t.busy;
        m_prevTotal = t.total;
        m_firstCpuTick = false;
        m_cpuPercent = 0.0;
        emit cpuPercentChanged();
        return;
    }

    const quint64 totalDelta = t.total - m_prevTotal;
    const quint64 idleDelta = (t.total - t.busy) - m_prevIdle;

    m_prevTotal = t.total;
    m_prevIdle = t.total - t.busy;

    if (totalDelta == 0)
        return;

    const quint64 busyDelta = totalDelta - idleDelta;
    m_cpuPercent = qBound<qreal>(0.0, (qreal(busyDelta) / qreal(totalDelta)) * 100.0, 100.0);
    emit cpuPercentChanged();
}

void SysMonitor::readMemory() {
    QFile file(QStringLiteral("/proc/meminfo"));
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
        return;

    quint64 memTotalKb = 0;
    quint64 memAvailableKb = 0;

    QTextStream stream(&file);
    QString line;
    while (stream.readLineInto(&line)) {
        const QStringList fields = line.split(QRegularExpression(QStringLiteral("\\s+")),
                                               Qt::SkipEmptyParts);
        if (fields.size() < 2)
            continue;
        if (fields.at(0) == QStringLiteral("MemTotal:")) {
            memTotalKb = fields.at(1).toULongLong();
        } else if (fields.at(0) == QStringLiteral("MemAvailable:")) {
            memAvailableKb = fields.at(1).toULongLong();
            break;
        }
    }
    file.close();

    if (memTotalKb == 0)
        return;

    const qreal used = qreal(memTotalKb - memAvailableKb) * kKiB;
    const qreal total = qreal(memTotalKb) * kKiB;

    const qreal pct = qBound<qreal>(0.0, (used / total) * 100.0, 100.0);
    if (qFuzzyCompare(pct, m_ramPercent) && qFuzzyCompare(used, m_ramUsedBytes)
            && qFuzzyCompare(total, m_ramTotalBytes))
        return;

    m_ramPercent = pct;
    m_ramUsedBytes = used;
    m_ramTotalBytes = total;
    emit ramPercentChanged();
    emit ramUsedBytesChanged();
    emit ramTotalBytesChanged();
}

void SysMonitor::readNet() {
    QFile file(QStringLiteral("/proc/net/dev"));
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
        return;

    quint64 rxBytes = 0;
    quint64 txBytes = 0;

    QTextStream stream(&file);
    QString line;
    bool isHeader = true;
    while (stream.readLineInto(&line)) {
        if (isHeader) { // two header lines
            isHeader = false;
            continue;
        }
        const int colon = line.indexOf(QLatin1Char(':'));
        if (colon <= 0)
            continue;

        const QString iface = line.left(colon).trimmed();
        if (iface == QLatin1String("lo") || m_netExcludeRegex.match(iface).hasMatch())
            continue;

        const QStringList numbers = line.mid(colon + 1).split(QRegularExpression(QStringLiteral("\\s+")),
                                                               Qt::SkipEmptyParts);
        if (numbers.size() < 9)
            continue;

        rxBytes += numbers.at(0).toULongLong();
        txBytes += numbers.at(8).toULongLong();
    }
    file.close();

    if (m_firstNetTick) {
        m_prevRx = rxBytes;
        m_prevTx = txBytes;
        m_firstNetTick = false;
        m_rxBytesPerSec = 0.0;
        m_txBytesPerSec = 0.0;
        emit rxBytesPerSecChanged();
        emit txBytesPerSecChanged();
        return;
    }

    const qint64 elapsedMs = qMax<qint64>(1, m_elapsed.restart());

    // 32-bit counter wrap: clamp negative deltas to 0.
    const qint64 rxDelta = qint64(rxBytes) - qint64(m_prevRx);
    const qint64 txDelta = qint64(txBytes) - qint64(m_prevTx);

    m_prevRx = rxBytes;
    m_prevTx = txBytes;

    m_rxBytesPerSec = qMax<qint64>(0, rxDelta) * 1000.0 / elapsedMs;
    m_txBytesPerSec = qMax<qint64>(0, txDelta) * 1000.0 / elapsedMs;
    emit rxBytesPerSecChanged();
    emit txBytesPerSecChanged();
}
