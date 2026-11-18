// Mpire window frames. See mpiredecoration.h.
#include "mpiredecoration.h"

#include <KDecoration3/DecoratedWindow>
#include <KDecoration3/DecorationButtonGroup>
#include <KDecoration3/DecorationSettings>
#include <KDecoration3/DecorationShadow>
#include <KPluginFactory>

#include <QFontMetricsF>
#include <QPainter>
#include <QPainterPath>
#include <QVariantAnimation>

#include <algorithm>
#include <cmath>

K_PLUGIN_FACTORY_WITH_JSON(MpireDecorationFactory, "mpiredecoration.json", registerPlugin<Mpire::Decoration>(); registerPlugin<Mpire::Button>();)

namespace Mpire
{

using KDecoration3::ColorGroup;
using KDecoration3::ColorRole;
using KDecoration3::DecorationButtonType;

namespace
{

// Sizes, in logical pixels (docs/design-system.md, "Windows").
constexpr qreal kTitleHeight = 34;
constexpr qreal kRadius = 12;            // window corners
constexpr qreal kSidePadding = 10;       // title bar edge to first button / caption
constexpr qreal kCaptionPadding = 8;     // between buttons and the caption
constexpr qreal kButtonWidth = 28;
constexpr qreal kButtonHeight = 24;
constexpr qreal kButtonSpacing = 2;
constexpr qreal kResizeMargin = 6;       // invisible grab area around the window
constexpr qreal kTitleOpacity = 0.8;     // frosted: the blur behind shows through (as the app's glass, qtstyle)
constexpr int kAnimationMs = 150;

// Brand cyan, from branding/logo (Theme.brand).
const QColor kBrand(0x00, 0xCB, 0xD7);
const QColor kDanger(0xE0, 0x6A, 0x7A);

QColor withAlpha(QColor c, qreal a)
{
    c.setAlphaF(std::clamp(a, 0.0, 1.0));
    return c;
}

QColor mix(const QColor &a, const QColor &b, qreal t)
{
    return QColor::fromRgbF(a.redF() + (b.redF() - a.redF()) * t, a.greenF() + (b.greenF() - a.greenF()) * t,
                            a.blueF() + (b.blueF() - a.blueF()) * t, a.alphaF() + (b.alphaF() - a.alphaF()) * t);
}

// Three box-blur passes approximate a Gaussian blur of an 8-bit mask.
void boxBlur(QImage &mask, int radius)
{
    if (radius < 1)
        return;
    const int w = mask.width();
    const int h = mask.height();
    std::vector<int> line(std::max(w, h));
    const int span = 2 * radius + 1;
    for (int pass = 0; pass < 3; ++pass) {
        for (int y = 0; y < h; ++y) {                       // rows
            uchar *row = mask.scanLine(y);
            for (int x = 0; x < w; ++x)
                line[x] = row[x];
            int sum = 0;
            for (int i = -radius; i <= radius; ++i)
                sum += line[std::clamp(i, 0, w - 1)];
            for (int x = 0; x < w; ++x) {
                row[x] = uchar(sum / span);
                sum += line[std::min(x + radius + 1, w - 1)] - line[std::max(x - radius, 0)];
            }
        }
        for (int x = 0; x < w; ++x) {                       // columns
            for (int y = 0; y < h; ++y)
                line[y] = mask.scanLine(y)[x];
            int sum = 0;
            for (int i = -radius; i <= radius; ++i)
                sum += line[std::clamp(i, 0, h - 1)];
            for (int y = 0; y < h; ++y) {
                mask.scanLine(y)[x] = uchar(sum / span);
                sum += line[std::min(y + radius + 1, h - 1)] - line[std::max(y - radius, 0)];
            }
        }
    }
}

// A soft colored halo around a rounded box: `blur` is how far it spreads.
void paintHalo(QPainter &p, const QSize &size, const QRectF &box, qreal radius, int blur, const QColor &color)
{
    QImage mask(size, QImage::Format_Alpha8);
    mask.fill(0);
    {
        QPainter mp(&mask);
        mp.setRenderHint(QPainter::Antialiasing);
        mp.setPen(Qt::NoPen);
        mp.setBrush(Qt::black);
        mp.drawRoundedRect(box, radius, radius);
    }
    boxBlur(mask, std::max(1, blur / 3));
    QImage colored(size, QImage::Format_ARGB32_Premultiplied);
    colored.fill(color);
    {
        QPainter cp(&colored);
        cp.setCompositionMode(QPainter::CompositionMode_DestinationIn);
        cp.drawImage(0, 0, mask);
    }
    p.drawImage(0, 0, colored);
}

// The drop shadow, plus a cyan glow on the focused window. One texture per
// state, shared by every window.
std::shared_ptr<KDecoration3::DecorationShadow> makeShadow(bool active)
{
    const int spread = active ? 44 : 36;                 // how far the shadow reaches
    const int offsetY = active ? 12 : 8;
    const QSize boxSize(int(2 * kRadius + 8), int(2 * kRadius + 8));
    const QSize size(boxSize.width() + 2 * spread, boxSize.height() + 2 * spread);
    const QRectF box(QPointF(spread, spread), boxSize);

    QImage texture(size, QImage::Format_ARGB32_Premultiplied);
    texture.fill(Qt::transparent);
    QPainter p(&texture);
    p.setRenderHint(QPainter::Antialiasing);
    paintHalo(p, size, box.translated(0, offsetY), kRadius, spread - offsetY - 2, QColor(0, 0, 0, active ? 150 : 100));
    if (active)
        paintHalo(p, size, box.adjusted(-1, -1, 1, 1), kRadius, 22, withAlpha(kBrand, 0.32));
    // Nothing under the window itself: its title bar is see-through.
    p.setCompositionMode(QPainter::CompositionMode_DestinationOut);
    p.setPen(Qt::NoPen);
    p.setBrush(Qt::black);
    p.drawRoundedRect(box.adjusted(1, 1, -1, -1), kRadius, kRadius);
    p.end();

    auto shadow = std::make_shared<KDecoration3::DecorationShadow>();
    shadow->setShadow(texture);
    shadow->setPadding(QMarginsF(spread, spread, spread, spread));
    shadow->setInnerShadowRect(QRectF(box.center(), QSizeF(1, 1)));
    return shadow;
}

std::shared_ptr<KDecoration3::DecorationShadow> &cachedShadow(bool active)
{
    static std::shared_ptr<KDecoration3::DecorationShadow> shadows[2];
    return shadows[active ? 1 : 0];
}

// A rectangle with its top corners (and, with `bottom`, its bottom corners)
// rounded, as a pixel region for the blur behind the title bar.
QRegion roundedRegion(const QRect &rect, int r, bool bottom)
{
    if (r <= 0)
        return QRegion(rect);
    QRegion region(rect.adjusted(r, 0, -r, 0));
    region += QRegion(rect.adjusted(0, r, 0, bottom ? -r : 0));
    const int d = 2 * r;
    region += QRegion(QRect(rect.left(), rect.top(), d, d), QRegion::Ellipse);
    region += QRegion(QRect(rect.right() - d + 1, rect.top(), d, d), QRegion::Ellipse);
    if (bottom) {
        region += QRegion(QRect(rect.left(), rect.bottom() - d + 1, d, d), QRegion::Ellipse);
        region += QRegion(QRect(rect.right() - d + 1, rect.bottom() - d + 1, d, d), QRegion::Ellipse);
    }
    return region;
}

} // namespace

// ---------------------------------------------------------------------------

Decoration::Decoration(QObject *parent, const QVariantList &args)
    : KDecoration3::Decoration(parent, args)
{
}

Decoration::~Decoration() = default;

bool Decoration::init()
{
    auto w = window();
    m_active = w->isActive() ? 1 : 0;
    m_activeAnimation = new QVariantAnimation(this);
    m_activeAnimation->setDuration(kAnimationMs);
    m_activeAnimation->setEasingCurve(QEasingCurve::OutCubic);
    connect(m_activeAnimation, &QVariantAnimation::valueChanged, this, [this](const QVariant &v) {
        m_active = v.toReal();
        update();
    });
    connect(w, &KDecoration3::DecoratedWindow::activeChanged, this, [this](bool active) {
        m_activeAnimation->stop();
        m_activeAnimation->setStartValue(m_active);
        m_activeAnimation->setEndValue(active ? 1.0 : 0.0);
        m_activeAnimation->start();
        updateShadow();
        updateLayout();          // the outline's color
    });

    m_left = new KDecoration3::DecorationButtonGroup(KDecoration3::DecorationButtonGroup::Position::Left, this, &Button::create);
    m_right = new KDecoration3::DecorationButtonGroup(KDecoration3::DecorationButtonGroup::Position::Right, this, &Button::create);

    const auto relayout = [this] { updateLayout(); };
    connect(w, &KDecoration3::DecoratedWindow::widthChanged, this, relayout);
    connect(w, &KDecoration3::DecoratedWindow::heightChanged, this, relayout);
    connect(w, &KDecoration3::DecoratedWindow::maximizedChanged, this, relayout);
    connect(w, &KDecoration3::DecoratedWindow::maximizedHorizontallyChanged, this, relayout);
    connect(w, &KDecoration3::DecoratedWindow::maximizedVerticallyChanged, this, relayout);
    connect(w, &KDecoration3::DecoratedWindow::adjacentScreenEdgesChanged, this, relayout);
    connect(w, &KDecoration3::DecoratedWindow::shadedChanged, this, relayout);
    connect(w, &KDecoration3::DecoratedWindow::nextScaleChanged, this, relayout);
    connect(w, &KDecoration3::DecoratedWindow::captionChanged, this, [this] { update(); });
    connect(w, &KDecoration3::DecoratedWindow::paletteChanged, this, [this] { update(); });
    const auto s = settings();
    connect(s.get(), &KDecoration3::DecorationSettings::fontChanged, this, relayout);
    connect(s.get(), &KDecoration3::DecorationSettings::reconfigured, this, relayout);
    connect(s.get(), &KDecoration3::DecorationSettings::decorationButtonsLeftChanged, this, relayout);
    connect(s.get(), &KDecoration3::DecorationSettings::decorationButtonsRightChanged, this, relayout);

    setOpaque(false);
    updateLayout();
    updateShadow();
    return true;
}

bool Decoration::isMaximized() const
{
    return window()->isMaximized();
}

qreal Decoration::radius() const
{
    return isMaximized() ? 0 : kRadius;
}

QColor Decoration::captionColor() const
{
    const QColor active = window()->color(ColorGroup::Active, ColorRole::Foreground);
    const QColor inactive = withAlpha(window()->color(ColorGroup::Inactive, ColorRole::Foreground), 0.62);
    return mix(inactive, withAlpha(active, 0.94), m_active);
}

void Decoration::updateLayout()
{
    auto w = window();
    const bool maximized = isMaximized();
    // Title bar only: the app fills the rest, its corners rounded by KWin.
    setBorders(QMarginsF(0, kTitleHeight, 0, 0));
    const qreal grab = maximized ? 0 : kResizeMargin;
    setResizeOnlyBorders(QMarginsF(grab, 0, grab, grab));
    setTitleBar(QRectF(0, 0, w->width(), kTitleHeight));

    const qreal r = radius();
    setBorderRadius(KDecoration3::BorderRadius(r, r, r, r));
    if (maximized) {
        setBorderOutline(KDecoration3::BorderOutline());
    } else {
        const QColor outline = w->isActive() ? withAlpha(kBrand, 0.78)
                                             : withAlpha(window()->color(ColorGroup::Inactive, ColorRole::Foreground), 0.14);
        setBorderOutline(KDecoration3::BorderOutline(1, outline, KDecoration3::BorderRadius(r, r, r, r)));
    }
    updateButtons();
    updateBlur();
    update();
}

void Decoration::updateButtons()
{
    for (auto *group : {m_left, m_right}) {
        group->setSpacing(kButtonSpacing);
        for (auto *button : group->buttons())
            button->setGeometry(QRectF(0, 0, kButtonWidth, kButtonHeight));
    }
    const qreal y = std::round((kTitleHeight - kButtonHeight) / 2);
    m_left->setPos(QPointF(kSidePadding, y));
    m_right->setPos(QPointF(size().width() - m_right->geometry().width() - kSidePadding, y));
}

void Decoration::updateShadow()
{
    const bool active = window()->isActive();
    auto &shadow = cachedShadow(active);
    if (!shadow)
        shadow = makeShadow(active);
    setShadow(shadow);
}

void Decoration::updateBlur()
{
    const QRect title = QRectF(0, 0, size().width(), kTitleHeight).toAlignedRect();
    setBlurRegion(roundedRegion(title, int(radius()), false));
}

void Decoration::paint(QPainter *painter, const QRectF &repaintArea)
{
    auto w = window();
    const auto s = settings();
    const QRectF title(0, 0, size().width(), kTitleHeight);
    if (!title.intersects(repaintArea))
        return;

    painter->save();
    painter->setRenderHint(QPainter::Antialiasing);
    painter->setPen(Qt::NoPen);

    // Frosted dark glass, in the color scheme's title bar color.
    QColor glass = mix(w->color(ColorGroup::Inactive, ColorRole::TitleBar), w->color(ColorGroup::Active, ColorRole::TitleBar), m_active);
    if (s->isAlphaChannelSupported())
        glass = withAlpha(glass, kTitleOpacity);
    QPainterPath path;
    const qreal r = radius();
    path.moveTo(title.left(), title.bottom());
    path.lineTo(title.left(), title.top() + r);
    path.arcTo(QRectF(title.left(), title.top(), 2 * r, 2 * r), 180, -90);
    path.lineTo(title.right() - r, title.top());
    path.arcTo(QRectF(title.right() - 2 * r, title.top(), 2 * r, 2 * r), 90, -90);
    path.lineTo(title.right(), title.bottom());
    path.closeSubpath();
    painter->setBrush(glass);
    painter->drawPath(path);

    // A faint light edge along the top, like the panels' glass.
    if (!isMaximized()) {
        QLinearGradient sheen(title.topLeft(), title.bottomLeft());
        sheen.setColorAt(0, QColor(255, 255, 255, 14));
        sheen.setColorAt(1, QColor(255, 255, 255, 0));
        painter->setBrush(sheen);
        painter->drawPath(path);
    }

    // Caption: monospace (the title bar font, kdeglobals [WM]), left aligned.
    const qreal left = m_left->buttons().isEmpty() ? kSidePadding + 6 : m_left->geometry().right() + kCaptionPadding;
    const qreal right = m_right->buttons().isEmpty() ? title.right() - kSidePadding : m_right->geometry().left() - kCaptionPadding;
    if (right > left) {
        const QRectF captionRect(left, 0, right - left, kTitleHeight);
        painter->setFont(s->font());
        painter->setPen(captionColor());
        const QString caption = QFontMetricsF(s->font()).elidedText(w->caption(), Qt::ElideMiddle, captionRect.width());
        painter->drawText(captionRect, Qt::AlignVCenter | Qt::AlignLeft | Qt::TextSingleLine, caption);
    }
    painter->restore();

    m_left->paint(painter, repaintArea);
    m_right->paint(painter, repaintArea);
}

// ---------------------------------------------------------------------------

Button::Button(DecorationButtonType type, Decoration *decoration, QObject *parent)
    : KDecoration3::DecorationButton(type, decoration, parent)
{
    m_hoverAnimation = new QVariantAnimation(this);
    m_hoverAnimation->setDuration(kAnimationMs);
    m_hoverAnimation->setEasingCurve(QEasingCurve::OutCubic);
    connect(m_hoverAnimation, &QVariantAnimation::valueChanged, this, [this](const QVariant &v) {
        m_hover = v.toReal();
        update();
    });
    connect(this, &KDecoration3::DecorationButton::hoveredChanged, this, [this](bool hovered) {
        m_hoverAnimation->stop();
        m_hoverAnimation->setStartValue(m_hover);
        m_hoverAnimation->setEndValue(hovered ? 1.0 : 0.0);
        m_hoverAnimation->start();
    });
    setGeometry(QRectF(0, 0, kButtonWidth, kButtonHeight));
}

Button::Button(QObject *parent, const QVariantList &args)
    : Button(args.at(0).value<DecorationButtonType>(), args.at(1).value<Decoration *>(), parent)
{
}

KDecoration3::DecorationButton *Button::create(DecorationButtonType type, KDecoration3::Decoration *decoration, QObject *parent)
{
    auto *d = qobject_cast<Decoration *>(decoration);
    if (!d)
        return nullptr;
    auto *b = new Button(type, d, parent);
    auto *w = d->window();
    switch (type) {
    case DecorationButtonType::Close:
        b->setVisible(w->isCloseable());
        connect(w, &KDecoration3::DecoratedWindow::closeableChanged, b, &KDecoration3::DecorationButton::setVisible);
        break;
    case DecorationButtonType::Maximize:
        b->setVisible(w->isMaximizeable());
        connect(w, &KDecoration3::DecoratedWindow::maximizeableChanged, b, &KDecoration3::DecorationButton::setVisible);
        break;
    case DecorationButtonType::Minimize:
        b->setVisible(w->isMinimizeable());
        connect(w, &KDecoration3::DecoratedWindow::minimizeableChanged, b, &KDecoration3::DecorationButton::setVisible);
        break;
    case DecorationButtonType::ContextHelp:
        b->setVisible(w->providesContextHelp());
        connect(w, &KDecoration3::DecoratedWindow::providesContextHelpChanged, b, &KDecoration3::DecorationButton::setVisible);
        break;
    case DecorationButtonType::Shade:
        b->setVisible(w->isShadeable());
        connect(w, &KDecoration3::DecoratedWindow::shadeableChanged, b, &KDecoration3::DecorationButton::setVisible);
        break;
    case DecorationButtonType::Menu:
        connect(w, &KDecoration3::DecoratedWindow::iconChanged, b, [b] { b->update(); });
        break;
    default:
        break;
    }
    return b;
}

void Button::paint(QPainter *painter, const QRectF &repaintArea)
{
    Q_UNUSED(repaintArea)
    auto *d = qobject_cast<Decoration *>(decoration());
    if (!d || !isVisible())
        return;
    const QRectF g = geometry();
    const QPointF c = g.center();
    const bool close = type() == DecorationButtonType::Close;
    const qreal hover = isPressed() ? 1.0 : m_hover;

    painter->save();
    painter->setRenderHint(QPainter::Antialiasing);

    // Hover: a soft light pill (red under close).
    if (hover > 0.001) {
        const QColor fill = close ? withAlpha(kDanger, 0.9 * hover) : QColor::fromRgbF(1, 1, 1, (isPressed() ? 0.16 : 0.10) * hover);
        painter->setPen(Qt::NoPen);
        painter->setBrush(fill);
        painter->drawRoundedRect(QRectF(c.x() - 13, c.y() - 11, 26, 22), 7, 7);
    }

    if (type() == DecorationButtonType::Menu) {
        const QRectF icon(c.x() - 8, c.y() - 8, 16, 16);
        d->window()->icon().paint(painter, icon.toRect());
        painter->restore();
        return;
    }

    QColor glyph = d->captionColor();
    glyph = withAlpha(glyph, glyph.alphaF() * (0.72 + 0.28 * hover));
    if (close && hover > 0.5)
        glyph = Qt::white;
    QPen pen(glyph, 1.25);
    pen.setCapStyle(Qt::RoundCap);
    pen.setJoinStyle(Qt::RoundJoin);
    painter->setPen(pen);
    painter->setBrush(Qt::NoBrush);
    // Thin glyphs on a 10 px grid, centered and snapped to half pixels.
    const QPointF o(std::round(c.x()) + 0.5, std::round(c.y()) + 0.5);
    const qreal h = 5;

    switch (type()) {
    case DecorationButtonType::Minimize:
        painter->drawLine(QPointF(o.x() - h, o.y()), QPointF(o.x() + h, o.y()));
        break;
    case DecorationButtonType::Maximize:
        if (isChecked()) {          // maximized: two overlapping squares (restore)
            painter->drawRect(QRectF(o.x() - h, o.y() - h + 2, 2 * h - 2, 2 * h - 2));
            painter->drawPolyline(QList<QPointF>{QPointF(o.x() - h + 2, o.y() - h), QPointF(o.x() + h, o.y() - h), QPointF(o.x() + h, o.y() + h - 2)});
        } else {
            painter->drawRect(QRectF(o.x() - h + 0.5, o.y() - h + 0.5, 2 * h - 1, 2 * h - 1));
        }
        break;
    case DecorationButtonType::Close:
        painter->drawLine(QPointF(o.x() - h + 0.5, o.y() - h + 0.5), QPointF(o.x() + h - 0.5, o.y() + h - 0.5));
        painter->drawLine(QPointF(o.x() + h - 0.5, o.y() - h + 0.5), QPointF(o.x() - h + 0.5, o.y() + h - 0.5));
        break;
    case DecorationButtonType::OnAllDesktops:
        if (isChecked()) {
            painter->setBrush(glyph);
        }
        painter->drawEllipse(o, 3.5, 3.5);
        break;
    case DecorationButtonType::KeepAbove:
        painter->drawPolyline(QList<QPointF>{QPointF(o.x() - 4, o.y() + 2), QPointF(o.x(), o.y() - 2), QPointF(o.x() + 4, o.y() + 2)});
        if (isChecked())
            painter->drawLine(QPointF(o.x() - 4, o.y() - 4), QPointF(o.x() + 4, o.y() - 4));
        break;
    case DecorationButtonType::KeepBelow:
        painter->drawPolyline(QList<QPointF>{QPointF(o.x() - 4, o.y() - 2), QPointF(o.x(), o.y() + 2), QPointF(o.x() + 4, o.y() - 2)});
        if (isChecked())
            painter->drawLine(QPointF(o.x() - 4, o.y() + 4), QPointF(o.x() + 4, o.y() + 4));
        break;
    case DecorationButtonType::Shade:
        painter->drawLine(QPointF(o.x() - h, o.y() - 3), QPointF(o.x() + h, o.y() - 3));
        painter->drawPolyline(QList<QPointF>{QPointF(o.x() - 3, o.y() + (isChecked() ? 3 : 0)), QPointF(o.x(), o.y() + (isChecked() ? 0 : 3)),
                                             QPointF(o.x() + 3, o.y() + (isChecked() ? 3 : 0))});
        break;
    case DecorationButtonType::ApplicationMenu:
        for (int i = -1; i <= 1; ++i)
            painter->drawLine(QPointF(o.x() - h, o.y() + 3.5 * i), QPointF(o.x() + h, o.y() + 3.5 * i));
        break;
    case DecorationButtonType::ContextHelp: {
        QFont f = d->settings()->font();
        f.setPixelSize(12);
        painter->setFont(f);
        painter->drawText(g, Qt::AlignCenter, QStringLiteral("?"));
        break;
    }
    default:
        break;
    }
    painter->restore();
}

} // namespace Mpire

#include "mpiredecoration.moc"
