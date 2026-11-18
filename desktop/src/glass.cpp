#include "glass.h"

#include <QQuickItem>
#include <QQuickWindow>

#include <cmath>

#ifdef MPIRE_HAVE_KWINDOWSYSTEM
#include <KWindowEffects>
#endif

namespace {

// A rounded rectangle as a pixel region.
QRegion roundedRegion(const QRect &rect, int r)
{
    r = std::min({r, rect.width() / 2, rect.height() / 2});
    if (r <= 0)
        return QRegion(rect);
    QRegion region(rect.adjusted(r, 0, -r, 0));
    region += QRegion(rect.adjusted(0, r, 0, -r));
    const int d = 2 * r;
    region += QRegion(QRect(rect.left(), rect.top(), d, d), QRegion::Ellipse);
    region += QRegion(QRect(rect.right() - d + 1, rect.top(), d, d), QRegion::Ellipse);
    region += QRegion(QRect(rect.left(), rect.bottom() - d + 1, d, d), QRegion::Ellipse);
    region += QRegion(QRect(rect.right() - d + 1, rect.bottom() - d + 1, d, d), QRegion::Ellipse);
    return region;
}

// Visible on screen: shown, and not faded out, all the way up.
qreal effectiveOpacity(const QQuickItem *item)
{
    qreal opacity = 1;
    for (; item; item = item->parentItem()) {
        if (!item->isVisible())
            return 0;
        opacity *= item->opacity();
    }
    return opacity;
}

} // namespace

Glass::Glass(QObject *parent)
    : QObject(parent)
{
}

void Glass::add(QQuickItem *card)
{
    if (card && !m_cards.contains(card))
        m_cards << card;
}

void Glass::track(QQuickWindow *window)
{
    connect(window, &QQuickWindow::afterAnimating, this, [this, window] { update(window); });
    connect(window, &QObject::destroyed, this, [this, window] { m_regions.remove(window); });
}

void Glass::update(QQuickWindow *window)
{
    QRegion region;
    for (auto it = m_cards.begin(); it != m_cards.end();) {
        QQuickItem *card = *it;
        if (!card) {
            it = m_cards.erase(it);
            continue;
        }
        ++it;
        if (card->window() != window || !card->property("glass").toBool() || effectiveOpacity(card) < 0.05)
            continue;
        const QRect rect = card->mapRectToScene(card->boundingRect()).toAlignedRect();
        if (rect.isEmpty())
            continue;
        region += roundedRegion(rect, int(std::round(card->property("radius").toReal())));
    }
    if (m_regions.value(window) == region && m_regions.contains(window))
        return;
    m_regions.insert(window, region);
#ifdef MPIRE_HAVE_KWINDOWSYSTEM
    KWindowEffects::enableBlurBehind(window, !region.isEmpty(), region);
#endif
}
