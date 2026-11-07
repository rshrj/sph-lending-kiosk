# SPH theme for the kiosk

The visual language of the ETH Student Project House site (https://sph.ethz.ch), extracted
from its stylesheet (`app.css?v=2.1.0`) and screenshots on 2026-11-07, then adapted to
the 1024×600 touchscreen. **Nothing in the demo app is changed yet.** This folder is a
self-contained package to apply later.

    design/sph/
      README.md        this spec
      tokens.json      every value, with its CSS source and contrast ratios
      qml/Theme.qml    drop-in replacement for qml/Theme.qml (same property names + SPH extras)
      qml/*.qml        reference components: SkewButton, TextLink, OutlineCard, ColorBand,
                       ListRow, BrushText, Chevron (+ qmldir)
      fonts/           Proxima Nova Regular/Bold, Alternate Gothic No2 Pro: commercial, not in the repo (see fonts/README.md)
      assets/          SPH logo (black + white), brush-stroke highlight in 7 colours, chevron
      reference/       screenshots of sph.ethz.ch (desktop + 1024×600)
      preview/         Preview.qml + renders (home mock-up and specimen, light and dark)

Preview it (Mac, Homebrew Qt):

    qml design/sph/preview/Preview.qml                                  # home mock-up, tap things
    qml design/sph/preview/Preview.qml -- --page specimen --dark
    qml design/sph/preview/Preview.qml -- --page home --out /tmp/x.png  # render to PNG and quit

## The look in eight rules

1. **Flat colour bands.** Full-bleed, edge-to-edge blocks of a single accent (purple header,
   yellow announcement, orange CTA strip, purple intro). No gradients, no photos-as-texture.
2. **Ink on colour.** All text is `#242424`, including on every accent. Never white on an accent:
   it fails contrast (1.5–2.4:1), while ink gets 6.6–10.7:1.
3. **Two typefaces, strict roles.** *Alternate Gothic No2* (condensed, UPPERCASE, slight
   tracking) for headings, buttons, links, nav and labels. *Proxima Nova* for running text.
4. **Square everything.** `border-radius: 0` and no box-shadows. Depth comes from colour and line, not elevation.
5. **Heavy line work.** 3px ink outlines on buttons, thick green outlines on cards, 2px ink
   rules between list rows.
6. **The slanted button.** Buttons are parallelograms (`skew(-20deg)`) with an upright label.
   Activation fills the shape solid ink and inverts the label.
7. **The marker stroke.** A hand-drawn brush mark sits under a key word in a headline or a
   key fact (e.g. the postcode on the opening-hours page). Use at most one per screen.
8. **Underlined caps links** with a chevron `>` on rows and strips. Feedback is a quick
   colour fill or a 1.15× scale, in 150–250 ms, ease-in-out.

## Colour

| Token | Hex | Site role | Kiosk use |
|---|---|---|---|
| `ink` | `#242424` | `--black`, all text | text, outlines, rules; page colour in dark mode |
| `paper` | `#FFFFFF` | body background | page (light mode) |
| `purple` | `#C891FA` | `--primary`, header | header bar, primary accent, intro band |
| `purpleLight` | `#E4C7FD` | breadcrumb strip | sub-header / status strip |
| `yellow` | `#FFD200` | `--secondary`/`--warning` | announcements, highlight brush, warnings |
| `green` | `#0FDF75` | `--success` | card outlines, check-in success |
| `cyan` | `#82DCE1` | `--info` | info / location bands, avatar discs |
| `orange` | `#FF8C46` | CTA strips | "start here" strips, secondary CTA |
| `red` | `#FE0000` | `--danger` | errors only |
| `gray` / `#555` | `#777777` / `#555555` | `--darker` / form text | faint / dim text (4.5:1 / 7.5:1 on white) |

Green, yellow and cyan are **fill / outline / icon colours only**. As text on white they are unreadable.

**Dark mode** is our own extension (the site has none). Ink becomes the page, text goes white,
and the accents are unchanged and keep ink text. Over white text, prefer the purple or orange
brush to the yellow one.

## Typography

| Role | Font | Kiosk px | Site px (≥800 px wide) | Notes |
|---|---|---|---|---|
| Display | Alternate Gothic | 96 | h1 100 | attract screen, big numbers |
| H1 page title | Alternate Gothic | 48 | h2 80 | UPPERCASE, +1.2 px tracking, line-height 1.0 |
| H2 band / section | Alternate Gothic | 32 | h3 49 | |
| H3 card / row title | Alternate Gothic | 26 | h4 32 | |
| Button | Alternate Gothic | 20 | 17 | +0.8 px tracking |
| Link / label / nav | Alternate Gothic | 17 | — | underlined for links |
| Body | Proxima Nova Regular | 18 | 24 (17 mobile) | line-height 1.25 |
| Small | Proxima Nova Regular | 14 | — | timestamps (Bold for dates, as in the news list) |

Alternate Gothic has one weight. Never set `font.bold` on it (Qt would fake-bold it).
Proxima Nova ships here in **Regular and Bold only**. The site's body is actually Medium (500),
served from Adobe Fonts as a subsetted, embedding-restricted file, so it is not included. Regular is
very close. In Qt, `Font.Medium` falls back to Regular and `Font.DemiBold` to Bold.

## Shape, space, motion

- Radius 0 everywhere. Shadows: none. Focus/press tint is the accent at 25 % alpha.
- Strokes: button 3, card 3 (4.5 on the 1440 px site), rule 2.
- Skew: −20°, i.e. `Matrix4x4` shear `xy = tan(−20°) = −0.364` around the vertical centre (see `SkewButton.qml`).
- Space: gap 16, pad 24, header 64, minimum touch target 56.
- Motion: colour 150 ms, transform 250 ms, reveal 300–400 ms, `Easing.InOutQuad`.

## Components (reference implementations in `qml/`)

| Component | SPH source | Notes |
|---|---|---|
| `SkewButton` | `.btn` | outline (default) or `filled` with an accent; press = ink fill |
| `TextLink` | `.link` | caps + underline, 1.15× on press, hit area padded to 56 px |
| `OutlineCard` | `.o-info-boxes__item` | green 3px outline, caps title, body, link bottom-right |
| `ColorBand` | header / announcement / CTA strips | `color`, `title`, `body`, `action` (button) or `chevron` |
| `ListRow` | `.o-collapsible__item`, news list | 2px rules, optional bold date, chevron |
| `BrushText` | `span.drawer` | marker stroke behind text, 7 colours |
| `Chevron` | arrow icon | thin open `>` (QtQuick.Shapes, already on the Pi) |

All of them read only from `Theme` and use Qt 6.8 APIs (QtQuick, Layouts, Shapes).

## Applying it to the demo app (later, not done)

1. Copy `fonts/*.ttf` into `fonts/` and add them to `RESOURCES` in `CMakeLists.txt`. `main.cpp`
   already auto-loads every TTF under `:/qt/qml/Kiosk/fonts`. Change the default app font in
   `main.cpp` from `"Inter"` to `"Proxima Nova"`.
2. Replace `qml/Theme.qml` with `qml/Theme.qml` from here. All 30-odd existing property names are kept.
3. Add the components and assets to the QML module. Adjust the `brush()` path in `Theme.qml` to
   wherever `assets/` lands.
4. Known spots that will look off after the swap:
   - Hard-coded `"white"`: `KSwitch.qml:32`, `Keypad.qml:65`, `ActionTile.qml:49,56`,
     `AttractScreen.qml:44,61,72`, `SuccessMark.qml:45`. Wherever one sits on an accent fill, switch it to `Theme.accentText`.
   - Titles use `Theme.font` + `Font.DemiBold`. Headings should move to `Theme.fontDisplay` + uppercase.
   - Radius is now 0, so check pill shapes (switch track, segmented control) that read `radiusL/M/S`.
     Keep explicit `height / 2` radii for knobs and avatars.
   - `KButton` should become a `SkewButton` (or adopt its outline + ink-fill behaviour).
   - The default mode becomes **light** (`dark: false`), which matches SPH.

## Licensing

Proxima Nova (Mark Simonson) and Alternate Gothic No2 (SoftMaker) are commercial fonts. The
files here are SPH's web-font copies, converted to TTF for Qt. Use them only within what SPH /
ETH has licensed. Desktop/app embedding is often a separate license from web use, so confirm
before shipping in a distributed build. Inter (already in the app, OFL) is the fallback for
body text, and Bebas Neue or Oswald (OFL) are reasonable stand-ins for Alternate Gothic. The
ETH / SPH logo is a trademark of ETH Zürich.
