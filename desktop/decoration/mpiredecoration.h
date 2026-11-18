// Mpire window frames: MpireOS's own KWin window decoration (KDecoration3).
// Dark, translucent, frosted title bars with a monospace caption and thin
// line glyphs for minimize, maximize and close; rounded corners on the whole
// window; a hairline outline that turns brand cyan, with a soft cyan glow,
// on the focused window. See docs/design-system.md, "Windows".
#pragma once

#include <KDecoration3/Decoration>
#include <KDecoration3/DecorationButton>

#include <QVariantList>

class QVariantAnimation;

namespace KDecoration3
{
class DecorationButtonGroup;
class DecorationShadow;
}

namespace Mpire
{

class Decoration : public KDecoration3::Decoration
{
    Q_OBJECT
public:
    explicit Decoration(QObject *parent = nullptr, const QVariantList &args = QVariantList());
    ~Decoration() override;

    bool init() override;
    void paint(QPainter *painter, const QRectF &repaintArea) override;

    // 0 = inactive, 1 = active; animated between the two.
    qreal activeAmount() const { return m_active; }
    QColor captionColor() const;
    bool isMaximized() const;

private:
    void updateLayout();
    void updateButtons();
    void updateShadow();
    void updateBlur();
    qreal radius() const;

    KDecoration3::DecorationButtonGroup *m_left = nullptr;
    KDecoration3::DecorationButtonGroup *m_right = nullptr;
    QVariantAnimation *m_activeAnimation = nullptr;
    qreal m_active = 0;
};

class Button : public KDecoration3::DecorationButton
{
    Q_OBJECT
public:
    explicit Button(QObject *parent, const QVariantList &args);
    Button(KDecoration3::DecorationButtonType type, Decoration *decoration, QObject *parent = nullptr);

    static KDecoration3::DecorationButton *create(KDecoration3::DecorationButtonType type, KDecoration3::Decoration *decoration, QObject *parent);
    void paint(QPainter *painter, const QRectF &repaintArea) override;

private:
    QVariantAnimation *m_hoverAnimation = nullptr;
    qreal m_hover = 0;
};

} // namespace Mpire
