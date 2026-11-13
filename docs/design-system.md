# MpireOS design system

Status: draft, v0.1. This is the visual and verbal language for everything MpireOS draws: Mpire Desktop, Mpire Setup, and MpireOS apps. Components should take their values from the tokens below rather than hard-coding their own.

## The feeling

**Calm, light, and personal.** MpireOS should feel like a tidy desk in soft daylight: airy space, gentle lavender light, rounded shapes, and quiet confidence. Nothing shouts. Color is used sparingly and warmly, mostly to tell things apart (folders, collections, app icons) and to mark the one action that matters on a screen.

Five principles:

1. **Space first.** Generous margins and padding. When a screen feels busy, remove something before shrinking anything.
2. **Soft, not flat.** White surfaces float on a pale lavender backdrop with large radii and diffuse, low-contrast shadows. No hard borders where a shadow or a tint will do.
3. **One accent.** A single violet accent marks selection, focus, and the primary action. Everything else is neutral or a muted pastel.
4. **Big, light numbers; small, quiet labels.** Dates, times, and timers are large and light-weight. Section labels are small capitals with wide tracking.
5. **Warm words.** Copy is short, human, and kind ("A little space for everything.", "One thing at a time."). Never cute at the expense of clarity.

## Color

Light is the default theme. Dark is a full theme, not an inversion (see below).

### Neutrals (light)

| Token | Value | Use |
|---|---|---|
| `backdrop` | `#E6E3EC` | Desktop background behind everything; carries the soft wallpaper swirl |
| `backdropHighlight` | `#F3F1F7` | Light side of the backdrop gradient |
| `chrome` | `#F6F5FA` at 80% with blur | Top bar and dock: frosted glass over the backdrop |
| `surface` | `#FDFDFF` | Windows, cards, widgets |
| `surfaceSunken` | `#F4F4F7` | Sidebars, inset areas, input fields |
| `surfaceHover` | `#F6F4FB` | Hovered rows and items |
| `selection` | `#EFEBFC` | Selected sidebar item, selected row |
| `divider` | `#ECEBF0` | Hairlines between rows and sections |
| `border` | `#E6E5EB` | Card outlines, only where a shadow alone isn't enough |
| `text` | `#24222E` | Primary text |
| `textSecondary` | `#6B6878` | Descriptions, metadata |
| `textTertiary` | `#A19EAE` | Placeholders, disabled text, overlines |

### Accent

| Token | Value | Use |
|---|---|---|
| `accent` | `#7C66D6` | Primary buttons, selection marker, focus ring, today in the calendar |
| `accentHover` | `#8C78DE` | Hover on accent elements |
| `accentPressed` | `#6A55C4` | Pressed |
| `accentSoft` | `#EFEBFC` | Tinted backgrounds for selected and accent-related items |
| `accentText` | `#5E4BB8` | Accent-colored text and links on light surfaces |

### Pastels

Used to tell things apart: folder colors, collections, file-type badges, and app icon backgrounds. Each has a fill and a matching soft tint for backgrounds.

| Name | Fill | Tint |
|---|---|---|
| Lavender | `#A595D4` | `#F0ECFA` |
| Apricot | `#E6B072` | `#FBF1E4` |
| Sky | `#83A9D8` | `#EAF1FA` |
| Sage | `#8EB49B` | `#EBF3EE` |
| Butter | `#F2D58C` | `#FCF6E3` |
| Rose | `#EEAEBF` | `#FCEEF2` |
| Slate | `#AEB7C6` | `#EEF0F4` |

### Status

| Token | Value |
|---|---|
| `success` | `#5FAF8A` |
| `warning` | `#E3A54F` |
| `danger` | `#E06A7A` |
| `info` | `#6F98D6` |

Danger is reserved for actions that destroy data. It is a soft rose-red, never a saturated alarm red.

### Dark theme

Same structure, warm-tinted neutrals rather than pure gray: `backdrop #15141B`, `surface #1E1D26`, `surfaceSunken #191820`, `selection #2C2645`, `divider #2A2934`, `text #F2F1F7`, `textSecondary #A9A6B8`, `accent #9C88EE`. Pastels drop about 10% in lightness. Shadows become darker and tighter; the frosted chrome uses `#1E1D26` at 75%.

## Typography

**Inter** (SIL Open Font License) for all interface text, shipped in `mpire-fonts`. Tabular figures for times, sizes, and timers. **JetBrains Mono** for monospace.

| Style | Size / line height | Weight | Tracking | Example |
|---|---|---|---|---|
| Display | 56 / 60 | Light 300 | -2% | Calendar day "12", timer "25:00" |
| Greeting | 26 / 32 | Regular 400 | -1% | "A little space for everything." |
| Title | 22 / 28 | Semibold 600 | -0.5% | Page title "Home" |
| Heading | 15 / 20 | Semibold 600 | 0 | "Your folders", card titles |
| Body | 14 / 20 | Regular 400 | 0 | Sidebar items, file names |
| Small | 12 / 16 | Regular 400 | 0 | Metadata, "2 items" |
| Overline | 11 / 14 | Semibold 600, all caps | +12% | "YOUR SPACE", "TODAY" |

Interface text is sentence case. Overlines are the only all-caps style.

## Shape

| Token | Value | Use |
|---|---|---|
| `radiusWindow` | 16 px | Windows |
| `radiusCard` | 14 px | Widgets, folder cards, dialogs |
| `radiusControl` | 10 px | Buttons, inputs, sidebar items |
| `radiusSmall` | 6 px | Badges, chips, file-type icons |
| `radiusDock` | 22 px | The dock |
| `radiusIcon` | 28% of size | App icons (squircle) |
| `radiusPill` | 999 px | Workspace switcher, toggles, tags |

## Elevation

Shadows are large, soft, and tinted toward violet, never black.

| Level | Shadow | Use |
|---|---|---|
| 0 | none | Inline content |
| 1 | `0 1px 2px rgba(60,48,110,0.06)` | Cards inside a window |
| 2 | `0 8px 24px rgba(60,48,110,0.08)` | Widgets, unfocused windows |
| 3 | `0 18px 48px rgba(60,48,110,0.12)` | Focused window, dock, popovers |
| 4 | `0 28px 72px rgba(60,48,110,0.18)` | Dialogs, the app launcher |

## Spacing

A 4 px grid. Common steps: 4, 8, 12, 16, 20, 24, 32, 40, 48, 64. Window content uses 28 to 32 px padding; cards use 16 to 20 px; the desktop keeps a 48 px margin around widgets and windows.

## Motion

Quiet and quick. Things ease out, settle, and never bounce.

| Token | Duration | Easing | Use |
|---|---|---|---|
| `fast` | 120 ms | ease-out | Hover, press, toggles |
| `normal` | 220 ms | cubic-bezier(0.2, 0.8, 0.2, 1) | Page changes, popovers |
| `slow` | 360 ms | same | Windows opening, launcher, overview |

Windows open by scaling from 96% with a fade. Respect the system "reduce motion" setting by replacing movement with fades.

## Iconography

- **UI icons:** thin outline, 1.5 px stroke at 20 px, rounded caps and joins, in `textSecondary`. Lucide-style geometry. Shipped as `mpire-icons`.
- **App icons:** soft squircles filled with a pastel gradient (top lighter), with a single white or deep-tinted glyph. The Files icon is sky blue, Notes butter, Photos lavender, Music rose, Settings slate, Calendar white with a red month label.
- **Folders:** filled, slightly rounded folder shapes in the pastel fills, with a lighter tab.

## Desktop layout

What Mpire Desktop looks like on a fresh install.

### Top bar

A 44 px frosted bar across the top.

- **Left:** MpireOS mark and wordmark, a hairline divider, then the focused app's menus (for example Files, Applications, View) in `textSecondary`, with the app name in semibold `text`.
- **Center:** the workspace pill: a small accent dot, the workspace name ("Personal space"), and a chevron to switch.
- **Right:** search, notifications, Wi-Fi, quick settings, battery with percentage, then the time in semibold.

### Dock

A centered row of app icons 24 px above the bottom edge, with **no panel behind it**: the icons float directly on the desktop. 52 px icons with 12 px gaps. The launcher button sits first, separated by a hairline; settings sits last, after another hairline. Running apps get a small accent dot below the icon.

### Desktop greeting and widgets

- **Greeting** at the top left: the date as an overline ("THURSDAY, NOVEMBER 12") above a Greeting-style line ("A little space for everything." with a small accent sparkle).
- **Shortcuts** at the top right: My files and Wallpapers as small icon tiles with labels.
- **Widgets** in a right-hand column, **without card backgrounds**: their content sits directly on the desktop, separated by space rather than boxes: **Today** (large day number, month grid with today in an accent circle, and a one-line note), **A moment of focus** (a 25:00 focus timer with a round accent play button), and **Now playing** (album art, title, source, play).
- A quiet "Make it yours" link under the widgets opens desktop customization.
- **Bottom corners:** the MpireOS mark with "Thoughtfully yours." on the left, and a "Find your flow" search hint with its shortcut on the right.

### Windows

White `surface`, `radiusWindow`, elevation 3 when focused. The title bar is part of the content area: a small icon, the app name in semibold, a secondary description in `textTertiary`, and minimize, maximize, and close as thin icons on the right (no colored traffic lights). Sidebars use `surfaceSunken`, with overline section labels, a `selection`-tinted active item in `accentText`, and colored dots for collections. Status bars are 32 px with small text and a green dot for healthy states.

## Voice

| Instead of | Write |
|---|---|
| Home directory | Home: "Everything you need, right where you left it." |
| Pomodoro timer | A moment of focus: "One thing at a time." |
| Sync complete | Your space is up to date |
| Customize desktop | Make it yours |
| Search (Ctrl+K) | Find your flow |
| Installation complete | You're all set |

Keep it short and calm. Use "you" and "your." Avoid exclamation marks, jargon, and anything that sounds like marketing in a place where someone is trying to work.

## Where the tokens live

- QML: a shared `MpireOS.Style` module (`desktop/style/`) used by the shell, settings, apps, and Mpire Setup. Until it exists, Mpire Setup carries a copy in `installer/qml/MpireSetup/Theme.qml`.
- Qt Widgets and KDE apps: an `mpire` color scheme and Kvantum or QStyle theme generated from the same tokens.
- GTK apps: an `mpire` GTK 3/4 theme generated from the same tokens.
