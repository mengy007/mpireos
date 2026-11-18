// Frosted glass: asks the compositor to blur what's behind the shell's glass
// panels (MpireOS.Style's Card, in the dark theme), the way Mpire window
// frames blur behind their title bars. Each Card registers itself here;
// every frame, a surface's blur region follows its visible cards (rounded to
// their corners), so panels that open, move, or fade carry their blur along.
#pragma once

#include <QHash>
#include <QList>
#include <QObject>
#include <QPointer>
#include <QRegion>

class QQuickItem;
class QQuickWindow;

class Glass : public QObject
{
    Q_OBJECT
public:
    explicit Glass(QObject *parent = nullptr);

    // Called by Card (QML) when it is created.
    Q_INVOKABLE void add(QQuickItem *card);

    // Keep `window`'s blur region in step with its cards.
    void track(QQuickWindow *window);

private:
    void update(QQuickWindow *window);

    QList<QPointer<QQuickItem>> m_cards;
    QHash<QQuickWindow *, QRegion> m_regions;
};
