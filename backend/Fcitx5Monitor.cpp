#include "Fcitx5Monitor.h"

#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>

namespace {

const QString kService = QStringLiteral("org.fcitx.Fcitx5");
const QString kPath = QStringLiteral("/controller");
const QString kInterface = QStringLiteral("org.fcitx.Fcitx.Controller1");

QDBusMessage controllerCall(const QString &method) {
    return QDBusMessage::createMethodCall(kService, kPath, kInterface, method);
}

} // namespace

Fcitx5Monitor::Fcitx5Monitor(QObject *parent)
    : QObject(parent)
    , m_watcher(kService, QDBusConnection::sessionBus(), QDBusServiceWatcher::WatchForOwnerChange) {
    m_timer.setInterval(m_interval);
    connect(&m_timer, &QTimer::timeout, this, &Fcitx5Monitor::refresh);

    connect(&m_watcher, &QDBusServiceWatcher::serviceOwnerChanged, this,
            [this](const QString &, const QString &, const QString &newOwner) {
                if (newOwner.isEmpty()) {
                    setAvailable(false);
                } else {
                    refresh();
                }
            });

    // a successful State reply is what marks fcitx5 as available
    refresh();
}

int Fcitx5Monitor::interval() const {
    return m_interval;
}

void Fcitx5Monitor::setInterval(int ms) {
    if (ms == m_interval)
        return;
    m_interval = ms > 0 ? ms : 250;
    m_timer.setInterval(m_interval);
    emit intervalChanged();
}

bool Fcitx5Monitor::polling() const {
    return m_polling;
}

void Fcitx5Monitor::setPolling(bool polling) {
    if (polling == m_polling)
        return;
    m_polling = polling;
    if (m_polling && m_available)
        refresh();
    updateTimer();
    emit pollingChanged();
}

bool Fcitx5Monitor::available() const {
    return m_available;
}

int Fcitx5Monitor::state() const {
    return m_state;
}

QString Fcitx5Monitor::currentIm() const {
    return m_currentIm;
}

void Fcitx5Monitor::refresh() {
    if (m_pending > 0)
        return;

    QDBusConnection bus = QDBusConnection::sessionBus();
    m_pending = 2;

    auto *stateWatcher = new QDBusPendingCallWatcher(bus.asyncCall(controllerCall(QStringLiteral("State"))), this);
    connect(stateWatcher, &QDBusPendingCallWatcher::finished, this, [this](QDBusPendingCallWatcher *w) {
        const QDBusPendingReply<int> reply = *w;
        w->deleteLater();
        m_pending--;
        if (reply.isError()) {
            setAvailable(false);
            return;
        }
        setAvailable(true);
        setState(reply.value());
    });

    auto *imWatcher = new QDBusPendingCallWatcher(bus.asyncCall(controllerCall(QStringLiteral("CurrentInputMethod"))), this);
    connect(imWatcher, &QDBusPendingCallWatcher::finished, this, [this](QDBusPendingCallWatcher *w) {
        const QDBusPendingReply<QString> reply = *w;
        w->deleteLater();
        m_pending--;
        if (!reply.isError())
            setCurrentImValue(reply.value());
    });
}

void Fcitx5Monitor::setCurrentIm(const QString &name) {
    QDBusMessage call = controllerCall(QStringLiteral("SetCurrentIM"));
    call << name;
    auto *watcher = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(call), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this](QDBusPendingCallWatcher *w) {
        w->deleteLater();
        refresh();
    });
}

void Fcitx5Monitor::updateTimer() {
    if (m_polling && m_available)
        m_timer.start();
    else
        m_timer.stop();
}

void Fcitx5Monitor::setAvailable(bool available) {
    if (available == m_available)
        return;
    m_available = available;
    if (!m_available) {
        setState(0);
        setCurrentImValue(QString());
    }
    updateTimer();
    emit availableChanged();
}

void Fcitx5Monitor::setState(int state) {
    if (state == m_state)
        return;
    m_state = state;
    emit stateChanged();
}

void Fcitx5Monitor::setCurrentImValue(const QString &im) {
    if (im == m_currentIm)
        return;
    m_currentIm = im;
    emit currentImChanged();
}
