#pragma once

#include <QDBusServiceWatcher>
#include <QObject>
#include <QString>
#include <QTimer>
#include <QtQml/qqml.h>

// fcitx5 input method state for the pill bar, read over the session bus.
//
// fcitx5 emits no D-Bus signal when the input method changes (not to
// Wayland-native clients, at least), so the state has to be polled. This
// polls Controller1.State / CurrentInputMethod over the shell's own bus
// connection with async calls: no subprocess per query, and none of the
// connect/disconnect churn (Hello + NameOwnerChanged broadcasts to every bus
// client) that spawning fcitx5-remote causes. Polling only runs while fcitx5
// owns its bus name and `polling` is true; a service watcher picks it back
// up when fcitx5 (re)starts.
class Fcitx5Monitor final : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(int interval READ interval WRITE setInterval NOTIFY intervalChanged)
    Q_PROPERTY(bool polling READ polling WRITE setPolling NOTIFY pollingChanged)
    Q_PROPERTY(bool available READ available NOTIFY availableChanged)
    // 0 closed, 1 inactive, 2 active (same as `fcitx5-remote`); 0 when unavailable
    Q_PROPERTY(int state READ state NOTIFY stateChanged)
    Q_PROPERTY(QString currentIm READ currentIm NOTIFY currentImChanged)

public:
    explicit Fcitx5Monitor(QObject *parent = nullptr);

    int interval() const;
    void setInterval(int ms);

    bool polling() const;
    void setPolling(bool polling);

    bool available() const;
    int state() const;
    QString currentIm() const;

    // re-read state + input method now (e.g. right after a switch)
    Q_INVOKABLE void refresh();
    // same as `fcitx5-remote -s <name>`
    Q_INVOKABLE void setCurrentIm(const QString &name);

signals:
    void intervalChanged();
    void pollingChanged();
    void availableChanged();
    void stateChanged();
    void currentImChanged();

private:
    void updateTimer();
    void setAvailable(bool available);
    void setState(int state);
    void setCurrentImValue(const QString &im);

    QTimer m_timer;
    QDBusServiceWatcher m_watcher;

    int m_interval = 250;
    bool m_polling = true;
    bool m_available = false;
    int m_state = 0;
    QString m_currentIm;
    int m_pending = 0; // replies still outstanding; skip ticks rather than queue up
};
