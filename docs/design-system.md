# MpireOS design system

Status: draft, v0.1. This is the visual and verbal language for everything MpireOS draws: Mpire Desktop, Mpire Setup, and MpireOS apps. Components should take their values from the tokens below rather than hard-coding their own.

## The feeling

**Calm, light, and personal.** MpireOS should feel like a tidy desk in soft daylight: airy space, gentle cool daylight, rounded shapes, and quiet confidence. Nothing shouts. Color is used sparingly and warmly, mostly to tell things apart (folders, collections, app icons) and to mark the one action that matters on a screen.

Five principles:

1. **Space first.** Generous margins and padding. When a screen feels busy, remove something before shrinking anything.
2. **Soft, not flat.** White surfaces float on a pale teal-gray backdrop with large radii and diffuse, low-contrast shadows. No hard borders where a shadow or a tint will do.
3. **One accent.** A single teal accent marks selection, focus, and the primary action. Everything else is neutral or a muted pastel.
4. **Big, light numbers; small, quiet labels.** Dates, times, and timers are large and light-weight. Section labels are small capitals with wide tracking.
5. **Warm words.** Copy is short, human, and kind ("A little space for everything.", "One thing at a time."). Never cute at the expense of clarity.

## Color

Light is the default theme. Dark is a full theme, not an inversion (see below).

### Neutrals (light)

| Token | Value | Use |
|---|---|---|
| `backdrop` | `#E4EDEF` | Desktop background behind everything; carries the soft wallpaper swirl |
| `backdropHighlight` | `#F4F8F9` | Light side of the backdrop gradient |
| `chrome` | `#F7F9FB` at 80% with blur | Top bar and dock: frosted glass over the backdrop |
| `surface` | `#FFFFFF` | Windows, cards, widgets |
| `surfaceSunken` | `#F7F9FB` | Sidebars, inset areas, input fields |
| `surfaceHover` | `#F1F7F8` | Hovered rows and items |
| `selection` | `#EBF6F7` | Selected sidebar item, selected row |
| `divider` | `#EDF0F3` | Hairlines between rows and sections |
| `border` | `#E6EAEF` | Card outlines, only where a shadow alone isn't enough |
| `text` | `#0B1F25` | Primary text |
| `textSecondary` | `#4F5D6B` | Descriptions, metadata |
| `textTertiary` | `#8B95A3` | Placeholders, disabled text, overlines |

### Accent

Taken from mpire-tech.com (November 2026): Mpire teal `#269CA1` fading to deep teal `#094551` on primary buttons, ink `#0B1F25` for text.

| Token | Value | Use |
|---|---|---|
| `accent` | `#269CA1` | Primary buttons, selection marker, focus ring, today in the calendar |
| `accentHover` | `#2FAAAF` | Hover on accent elements |
| `accentPressed` | `#1A7F86` | Pressed |
| `accentSoft` | `#EBF6F7` | Tinted backgrounds for selected and accent-related items |
| `accentText` | `#094551` | Accent-colored text and links on light surfaces |

### Logo colors

The official logo (see [Logo](#logo)) has its own two colors. They belong to the logo and the wordmark, not to controls.

| Token | Value | Use |
|---|---|---|
| `brand` | `#00CBD7` | The mark, and "OS" in the wordmark |
| `brandNavy` | `#062331` | The logo's dark background, and the dark icon tile |

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

Shadows are large, soft, and tinted toward deep teal, never black.

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

## Logo

The MpireOS logo is a skyline "M": two towers with lit windows, a stepped bar chart falling between them, and small windows below, beside the "MpireOS" wordmark ("Mpire" in white or ink, "OS" in logo cyan). The vector files, their variants, and when to use each are in [branding/logo](../branding/logo/README.md). In the interface:

- The top bar, the login screen and Mpire Setup show the mark beside "Mpire**OS**" (`Mark` in `MpireOS.Style`; "OS" in `brand`).
- At 24 px and below the mark is the simplified skyline without windows (`mpireos-mark-small.svg`); `Mark` picks it by size.
- Boot screens (Plymouth, GRUB, the BIOS menu) show the full logo on the light backdrop.

## Desktop layout

What Mpire Desktop looks like on a fresh install.

### Top bar

A 44 px frosted bar across the top.

- **Left:** MpireOS mark and wordmark, a hairline divider, then the focused app's menus (for example Files, Applications, View) in `textSecondary`, with the app name in semibold `text`.
- **Center:** the workspace pill: a small accent dot, the workspace name ("Personal space"), and a chevron to switch.
- **Right:** search, notifications, Wi-Fi, quick settings, battery with percentage, then the time in semibold.

### Dock

A centered row of app icons 24 px above the bottom edge, with **no panel behind it**: the icons float directly on the desktop. 52 px icons with 12 px gaps. The launcher button sits first, separated by a hairline; settings sits last, after another hairline. Running apps get a small accent dot below the icon.

### The desktop

The desktop is **just the wallpaper**: no icons, widgets, or greeting, so nothing competes with what you are doing. Everything else is one right-click away.

- **Desktop menu** (right-click, or press and hold on a touch screen): a small white card at the pointer, `radius` 16, elevation 3, 36 px rows with an outline icon and 13 px text; the hovered row gets a `selection` tint. Rows: **Change wallpaper…** (semibold, it is the main thing people come for), Display settings, **Auto-hide the dock** (with a switch), then Open Files and Open Terminal, then All settings, with hairlines between the groups. It flips left or up near the screen's edges.
- **Wallpaper picker**: a large card (`radius` 24, elevation 4) sitting low on the screen so the wallpaper shows above it. Choices apply **right away** and fade in, so trying things is free; Done just closes it. Sections, under overline labels: **MpireOS** (our own wallpapers, 16:9 thumbnails with names, the chosen one outlined in `accent` with a check badge), **Colors** (round swatches from the palette), and **Your pictures** (an "Add a picture" tile that opens the system file chooser, then pictures from `~/Pictures` and the system's wallpaper folders). The footer has the placement chips for pictures (Fill screen, Fit, Center, Tile) and an accent Done button.
- **Our wallpapers** are drawn, not image files: a diagonal wash between two palette colors, a soft glow, and the same broad light rings as the backdrop. Morning mist (the backdrop itself, the default), Lagoon, Lavender, Daybreak, Meadow, Open sky, Sandstone, and Midnight.

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
