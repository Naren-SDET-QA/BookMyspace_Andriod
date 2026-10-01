# Receipt PDF font

`NotoSans-Receipt.ttf` is a **subset of Noto Sans Regular**, used only to embed
text in generated receipt PDFs.

## Why a font has to be bundled at all

The `pdf` package can draw with the PDF base-14 fonts (Helvetica and friends)
without embedding anything, but those fonts use WinAnsi encoding and have no
Unicode support. Asking `pdf` for the rupee sign fails:

```
Helvetica has no Unicode support see https://github.com/DavBfr/dart_pdf/wiki/Fonts-Management
Unable to find a font to draw "₹" (U+20b9) try to provide a TextStyle.fontFallback
```

It does not fail loudly. It draws a **missing-glyph box**, so a receipt for
₹1,770 would print as `□ 1,770.00`, and `Café` would print as `Cafe□`. On a
document whose whole job is to state an amount, that is a correctness bug, not
a cosmetic one. Embedding a font with real glyph coverage is the only fix.

## What is in the subset

| Range | Purpose |
| --- | --- |
| U+0020–007E | Basic Latin — digits, ASCII punctuation |
| U+00A0–00FF | Latin-1 Supplement — `é`, `ü`, `°` |
| U+0100–017F | Latin Extended-A |
| U+0180–024F | Latin Extended-B |
| U+2000–206F | General Punctuation — en dash, curly quotes |
| U+20A0–20BF | Currency Symbols — **includes U+20B9 ₹** |

`U+2212` (true minus) is deliberately absent: Noto Sans itself has no glyph for
it, so the ASCII hyphen is used for negative amounts. Verified against the full
font rather than assumed.

## What it cannot do

`pdf` performs no OpenType shaping, so it cannot render Devanagari, Arabic or
any other complex script correctly even if a font for it were bundled — there is
no conjunct formation or mark reordering. This subset is Latin-only on purpose:
a script that renders as plausible-but-wrong glyphs would be worse than one that
renders as a visible box. Receipt fields containing such text fall back to the
missing-glyph box, which is visible, rather than silently mis-shaping.

## Regenerating

Requires `fonttools` (`pip install fonttools`):

```sh
curl -sL -o NotoSans-Regular.ttf \
  https://github.com/googlefonts/noto-fonts/raw/main/hinted/ttf/NotoSans/NotoSans-Regular.ttf

pyftsubset NotoSans-Regular.ttf \
  --unicodes="U+0020-007E,U+00A0-00FF,U+0100-017F,U+0180-024F,U+2000-206F,U+20A0-20BF" \
  --output-file=NotoSans-Receipt.ttf \
  --layout-features= --no-hinting --desubroutinize --name-IDs=* --drop-tables+=DSIG
```

Expected output: ~49 KB (the full font is ~569 KB).

## Licence

Noto Sans is licensed under the **SIL Open Font License 1.1**; the full text is
in `OFL.txt`. The OFL permits modification and redistribution. Noto declares no
Reserved Font Name, so the subset may keep the name.
