// Mpire Glass widget style. See mpireglass.h.
#include "mpireglass.h"

#include <QApplication>
#include <QDockWidget>
#include <QFrame>
#include <QEvent>
#include <QFileInfo>
#include <QMainWindow>
#include <QMenu>
#include <QPaintEvent>
#include <QPainter>
#include <QSettings>
#include <QStyleFactory>
#include <QStylePlugin>
#include <QWindow>

#ifdef MPIRE_HAVE_KWINDOWSYSTEM
#include <KWindowEffects>
#endif

#include <algorithm>

namespace Mpire
{

namespace
{

// Apps whose content is a picture or video: they keep solid windows.
const QStringList kDefaultExclude{
    QStringLiteral("vlc"), QStringLiteral("smplayer"), QStringLiteral("krita"), QStringLiteral("kdenlive"),
    QStringLiteral("obs"), QStringLiteral("digikam"), QStringLiteral("showfoto"), QStringLiteral("kstars"),
};

// How strongly Breeze's tool area (menu bar and toolbars, in the color
// scheme's header color) is drawn over the glass: a tint, not a solid band.
constexpr qreal kToolsAreaOpacity = 0.4;

constexpr const char *kPaletteProperty = "_mpire_glass_palette";

QStyle *makeBase()
{
    if (QStyle *breeze = QStyleFactory::create(QStringLiteral("Breeze")))
        return breeze;
    return QStyleFactory::create(QStringLiteral("Fusion"));
}

QStringList appNames()
{
    QStringList names{QCoreApplication::applicationName().toLower()};
    const QString desktop = QGuiApplication::desktopFileName().toLower();
    if (!desktop.isEmpty()) {
        names << desktop;
        names << desktop.section(QLatin1Char('.'), -1); // org.kde.dolphin -> dolphin
    }
    const QStringList args = QCoreApplication::arguments();
    if (!args.isEmpty())
        names << QFileInfo(args.first()).fileName().toLower();
    return names;
}

} // namespace

GlassStyle::GlassStyle()
    : QProxyStyle(makeBase())
{
    // On X11 a see-through window needs a compositor and an ARGB visual, and
    // KWin's X11 blur works differently; MpireOS sessions are Wayland.
    const bool wayland = QGuiApplication::platformName().startsWith(QLatin1String("wayland"));
    // MPIRE_GLASS=0 turns glass off for an app, MPIRE_GLASS=1 forces it on
    // (even off Wayland, for previews and tests).
    const QString env = qEnvironmentVariable("MPIRE_GLASS");
    const bool envOff = env == QLatin1String("0");
    const bool envForce = env == QLatin1String("1");

    QSettings settings(QSettings::IniFormat, QSettings::UserScope, QStringLiteral("MpireOS"), QStringLiteral("glass"));
    settings.beginGroup(QStringLiteral("Windows"));
    const bool enabled = settings.value(QStringLiteral("Enabled"), true).toBool();
    m_opacity = std::clamp(settings.value(QStringLiteral("Opacity"), 0.62).toReal(), 0.0, 1.0);
    m_viewOpacity = std::clamp(settings.value(QStringLiteral("ViewOpacity"), 0.35).toReal(), 0.0, 1.0);
    QStringList exclude = settings.value(QStringLiteral("Exclude"), kDefaultExclude).toStringList();
    for (QString &name : exclude)
        name = name.trimmed().toLower();

    bool excluded = false;
    for (const QString &name : appNames())
        excluded = excluded || (!name.isEmpty() && exclude.contains(name));

    m_enabled = envForce || (wayland && !envOff && enabled && !excluded && m_opacity < 1.0);
    if (qEnvironmentVariableIsSet("MPIRE_GLASS_DEBUG"))
        qInfo("mpire-glass: %s for %s (Wayland %d, excluded %d, opacity %.2f)", m_enabled ? "on" : "off",
              qPrintable(appNames().join(QLatin1Char('/'))), wayland, excluded, m_opacity);
}

bool GlassStyle::wantsGlass(const QWidget *widget) const
{
    if (!m_enabled || !widget || !widget->isWindow())
        return false;
    const Qt::WindowType type = widget->windowType();
    if (type != Qt::Window && type != Qt::Dialog)
        return false;
    // Windows that draw their own frame, shape, or background; menus and
    // tooltips (Breeze's own); floating frames and splash screens.
    if (widget->windowFlags().testFlag(Qt::FramelessWindowHint)
        || widget->windowFlags().testFlag(Qt::X11BypassWindowManagerHint) || widget->testAttribute(Qt::WA_PaintOnScreen)
        || widget->testAttribute(Qt::WA_NoSystemBackground) || widget->autoFillBackground() || qobject_cast<const QMenu *>(widget)
        || qobject_cast<const QFrame *>(widget) || qobject_cast<const QDockWidget *>(widget) || widget->inherits("QSplashScreen") || widget->inherits("KScreenSaver"))
        return false;
    if (widget->property("_mpire_solid").toBool())
        return false;
    if (auto *mainWindow = qobject_cast<const QMainWindow *>(widget)) {
        // A main window inside another one, or one styled by a style sheet.
        if (mainWindow->parentWidget() || mainWindow->styleSheet().contains(QLatin1String("background")))
            return false;
    }
    return true;
}

// The window must be see-through from before it exists (the alpha channel is
// part of how it's created), but Qt polishes most windows only after that.
// Qt asks the style for hints about a widget early, while it's being built, so
// that's where this happens (as Kvantum does).
void GlassStyle::makeTranslucent(const QWidget *widget) const
{
    if (!widget || !widget->isWindow() || m_translucent.contains(widget))
        return;
    // Too late, or the app made it see-through itself (Konsole), so it paints
    // its own background.
    if (widget->testAttribute(Qt::WA_WState_Created) || widget->windowHandle()
        || widget->testAttribute(Qt::WA_TranslucentBackground))
        return;
    if (!wantsGlass(widget))
        return;
    auto *w = const_cast<QWidget *>(widget);
    w->setAttribute(Qt::WA_TranslucentBackground);
    m_translucent.insert(widget);
    if (qEnvironmentVariableIsSet("MPIRE_GLASS_DEBUG"))
        qInfo("mpire-glass: see-through window %s", widget->metaObject()->className());
    auto *self = const_cast<GlassStyle *>(this);
    connect(w, &QObject::destroyed, self, [self, widget] {
        self->m_translucent.remove(widget);
        self->m_windows.remove(widget);
    });
}

int GlassStyle::styleHint(StyleHint hint, const QStyleOption *option, const QWidget *widget, QStyleHintReturn *returnData) const
{
    makeTranslucent(widget);
    return QProxyStyle::styleHint(hint, option, widget, returnData);
}

bool GlassStyle::isGlass(const QWidget *widget) const
{
    return widget && m_windows.contains(widget);
}

void GlassStyle::polish(QWidget *widget)
{
    QProxyStyle::polish(widget);
    if (!widget)
        return;
    if (!widget->isWindow()) {
        // Made see-through while it had no parent yet (a dock, a toolbar
        // piece): as a child it paints like any other widget again.
        if (m_translucent.remove(widget)) {
            widget->setAttribute(Qt::WA_TranslucentBackground, false);
            widget->setAttribute(Qt::WA_NoSystemBackground, false);
        }
        if (m_translucent.contains(widget->window()) && !m_children.contains(widget)) {
            m_children.insert(widget);
            widget->installEventFilter(this);
            connect(widget, &QObject::destroyed, this, [this, widget] {
                m_children.remove(widget);
            });
            tintChild(widget);
        }
        return;
    }
    makeTranslucent(widget);
    if (isGlass(widget) || !m_translucent.contains(widget))
        return;
    // A main window whose content fills itself in solid color keeps solid.
    if (auto *mainWindow = qobject_cast<QMainWindow *>(widget)) {
        if (QWidget *central = mainWindow->centralWidget(); central && central->autoFillBackground()
            && central->palette().color(central->backgroundRole()).alpha() == 255) {
            widget->setAttribute(Qt::WA_NoSystemBackground, false);
            widget->setAutoFillBackground(true);
            return;
        }
    }

    m_windows.insert(widget);
    widget->installEventFilter(this);
    // Keep a palette the app set on its window itself.
    if (!widget->testAttribute(Qt::WA_SetPalette))
        widget->setProperty(kPaletteProperty, true);
    applyPalette(widget);
}

void GlassStyle::unpolish(QWidget *widget)
{
    if (widget && m_children.remove(widget))
        widget->removeEventFilter(this);
    if (isGlass(widget)) {
        widget->removeEventFilter(this);
        m_windows.remove(widget);
        // The window stays see-through (that can't change once it exists), so
        // it gets a solid background back.
        widget->setAutoFillBackground(true);
    }
    QProxyStyle::unpolish(widget);
}

// Lists, tables, and text areas: the view color as a tint over the glass.
bool GlassStyle::tintViews(QPalette &palette) const
{
    bool changed = false;
    for (const auto group : {QPalette::Active, QPalette::Inactive, QPalette::Disabled}) {
        for (const auto role : {QPalette::Base, QPalette::AlternateBase}) {
            QColor color = palette.color(group, role);
            if (color.alpha() != 255)
                continue; // already see-through (tinted, or the app's own choice)
            color.setAlphaF(m_viewOpacity);
            palette.setColor(group, role, color);
            changed = true;
        }
    }
    return changed;
}

void GlassStyle::applyPalette(QWidget *window)
{
    if (!window->property(kPaletteProperty).toBool() || m_applyingPalette)
        return;
    m_applyingPalette = true;
    QPalette palette = QApplication::palette(window);
    tintViews(palette);
    window->setPalette(palette);
    m_applyingPalette = false;
}

// A widget inside a glass window with a palette of its own (copied from the
// app's before the window was glass, as Dolphin's file view does) doesn't
// inherit the window's tint, so it gets it directly, also when it changes.
void GlassStyle::tintChild(QWidget *widget)
{
    if (m_applyingPalette || !widget->testAttribute(Qt::WA_SetPalette))
        return;
    QPalette palette = widget->palette();
    if (!tintViews(palette))
        return;
    m_applyingPalette = true;
    widget->setPalette(palette);
    m_applyingPalette = false;
}

void GlassStyle::updateBlur(QWidget *window)
{
#ifdef MPIRE_HAVE_KWINDOWSYSTEM
    if (QWindow *handle = window->windowHandle())
        KWindowEffects::enableBlurBehind(handle, true, QRegion(window->rect()));
#else
    Q_UNUSED(window)
#endif
}

bool GlassStyle::eventFilter(QObject *object, QEvent *event)
{
    auto *window = qobject_cast<QWidget *>(object);
    if (window && m_children.contains(window)) {
        if (event->type() == QEvent::PaletteChange)
            tintChild(window);
        return QProxyStyle::eventFilter(object, event);
    }
    if (!isGlass(window))
        return QProxyStyle::eventFilter(object, event);

    switch (event->type()) {
    case QEvent::Paint: {
        // The glass itself, before the window's own painting: the window
        // color, see-through. KWin blurs what's behind it.
        const bool active = window->isActiveWindow();
        QColor glass = window->palette().color(active ? QPalette::Active : QPalette::Inactive, QPalette::Window);
        glass.setAlphaF(m_opacity);
        QPainter painter(window);
        painter.setClipRegion(static_cast<QPaintEvent *>(event)->region());
        painter.setCompositionMode(QPainter::CompositionMode_Source);
        painter.fillRect(window->rect(), glass);
        break;
    }
    case QEvent::Show:
    case QEvent::Resize:
        updateBlur(window);
        break;
    case QEvent::ApplicationPaletteChange:
        applyPalette(window);
        break;
    default:
        break;
    }
    return QProxyStyle::eventFilter(object, event);
}

void GlassStyle::drawPrimitive(PrimitiveElement element, const QStyleOption *option, QPainter *painter, const QWidget *widget) const
{
    // Breeze fills a glass window's menu bar and toolbars with the solid
    // header color; draw that as a tint instead.
    if (element == PE_Widget && isGlass(widget)) {
        painter->save();
        painter->setOpacity(painter->opacity() * kToolsAreaOpacity);
        QProxyStyle::drawPrimitive(element, option, painter, widget);
        painter->restore();
        return;
    }
    QProxyStyle::drawPrimitive(element, option, painter, widget);
}

class GlassStylePlugin : public QStylePlugin
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID QStyleFactoryInterface_iid FILE "mpireglass.json")

public:
    QStyle *create(const QString &key) override
    {
        if (key.compare(QLatin1String("mpireglass"), Qt::CaseInsensitive) == 0)
            return new GlassStyle;
        return nullptr;
    }
};

} // namespace Mpire

#include "mpireglass.moc"
