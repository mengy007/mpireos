// Mpire Glass: the widget style MpireOS sets for Qt and KDE apps
// (kdeglobals widgetStyle=MpireGlass).
//
// It is Breeze, with one change: app windows are dark frosted glass, like the
// window frames (desktop/decoration) and Mpire Desktop's panels. Each normal
// window and dialog gets a see-through background, painted in the color
// scheme's window color at `Opacity`, and asks the compositor (KWin) to blur
// what's behind it. Lists and text areas get a light tint on top
// (`ViewOpacity`), so text stays easy to read. Everything else (buttons,
// menus, metrics) is Breeze's own.
//
// Settings, in ~/.config/MpireOS/glass.conf (distribution default:
// /etc/xdg/MpireOS/glass.conf):
//
//   [Windows]
//   Enabled=true         ; false: plain Breeze windows
//   Opacity=0.72         ; window background, 0 (clear) to 1 (solid)
//   ViewOpacity=0.35     ; lists, tables, and text areas, on top of that
//   Exclude=vlc,krita    ; apps (by name) that keep solid windows (default:
//                        ; picture and video apps, kDefaultExclude)
//
// MPIRE_GLASS=0 in an app's environment turns it off for that app; =1 forces it
// on (also off Wayland, for previews). MPIRE_GLASS_DEBUG=1 logs what it does.
// Glass needs Wayland (KWin's blur); on X11 windows stay solid.
#pragma once

#include <QPointer>
#include <QProxyStyle>
#include <QSet>

namespace Mpire
{

class GlassStyle : public QProxyStyle
{
    Q_OBJECT

public:
    GlassStyle();

    void polish(QWidget *widget) override;
    void unpolish(QWidget *widget) override;
    using QProxyStyle::polish;
    using QProxyStyle::unpolish;

    void drawPrimitive(PrimitiveElement element, const QStyleOption *option, QPainter *painter, const QWidget *widget) const override;
    int styleHint(StyleHint hint, const QStyleOption *option, const QWidget *widget, QStyleHintReturn *returnData) const override;

protected:
    bool eventFilter(QObject *object, QEvent *event) override;

private:
    bool wantsGlass(const QWidget *widget) const;
    void makeTranslucent(const QWidget *widget) const;
    bool isGlass(const QWidget *widget) const;
    bool tintViews(QPalette &palette) const;
    void applyPalette(QWidget *window);
    void tintChild(QWidget *widget);
    void updateBlur(QWidget *window);

    bool m_enabled = false;
    qreal m_opacity = 0.72;
    qreal m_viewOpacity = 0.35;
    QSet<const QWidget *> m_windows;               // glass windows (polished)
    mutable QSet<const QWidget *> m_translucent;   // made see-through by us
    QSet<const QWidget *> m_children;              // widgets inside glass windows
    bool m_applyingPalette = false;
};

} // namespace Mpire
