
## Things you need to know

### Codepoint

Codepoints (or code point) in Unicode are numerical values that usually
represent a single character but they can also have other meanings, such as
for formatting. Unicode comprises 1,114,112 code points in the range
0x0 to 0x10FFFF. The Unicode code space is divided into seventeen planes
(the basic multilingual plane, and 16 supplementary planes), each with
65,536 code points.

### UTF-8 Encoding

UTF-8 is a variable-width encoding for Unicode where each codepoint is 1 to 4
bytes wide. It is backwards-compatible with ASCII in that codepoints
above 127 only use non-ASCII bytes (bytes that are > 127).

### Unicode text

For the purposes of text layouting, a unit of text is an array of codepoints
representing one or more paragraphs of text in one or more languages.

### Span

In tr, a span is a set of properties for a specific sub-section of the text
to be laid out. Spans must cover the whole text without holes.

### Glyph

A graphic element intended to represent a readable character.
Glyphs is what fonts are all about. They usually come as vector outlines
(closed paths of lines and quad beziers and a fill rule) but they can also
come in raster form (in color or as alpha masks). The mapping between
codepoints and glyphs is what _text shaping_ is all about.

### Cluster

In text shaping, a cluster is a sequence of codepoints that must be treated
as an indivisible unit. Clusters can include code-point sequences that form
a ligature or base-and-mark sequences. Tracking and preserving clusters is
important when shaping operations might separate or reorder codepoints.

HarfBuzz provides three cluster levels that implement different approaches
to the problem of preserving clusters during shaping operations.

### Grapheme

In linguistics, a grapheme is one of the indivisible units that make up a
writing system or script. Often, graphemes are individual symbols (letters,
numbers, punctuation marks, logograms, etc.) but, depending on the writing
system, a particular grapheme might correspond to a sequence of several
Unicode codepoints.

In practice, text-shaping engines are not generally concerned with graphemes.
However, it is important to recognize that there is a difference between
graphemes and shaping clusters. The two concepts may overlap frequently,
but there is no guarantee that they will be identical.

### Ligature

A ligature occurs when two or more graphemes or letters are represented by
a single glyph. Ligatures may be only an aesthetic thing for Latin but they
are essential in Arabic and other cursive scripts. Forming ligatures is part
of shaping.

### Combining Mark

These are codepoints (and glyphs) intended to modify (i.e. positioned on
top of) other (base) codepoints (and glyphs). They include diacritics and
other such symbols.

Unicode contains precomposed characters, so that in many cases it is possible
to use both combining diacritics and precomposed characters, at the user's
choice. This leads to a requirement to perform Unicode normalization
as part of shaping.

### Script & Language

In shaping lingo, a script is a writing system: a set of symbols, rules,
and conventions that is used to represent a language or multiple languages.

Scripts and languages are different things: most scripts are used to write
a variety of different languages, and many languages may be written in more
than one script.

### Shaper

In HarfBuzz, a shaper is a handler for a specific script-shaping model.
HarfBuzz implements separate shapers for Indic, Arabic, Thai and Lao, Khmer,
Myanmar, Tibetan, Hangul, Hebrew, the Universal Shaping Engine (USE),
and a default shaper for non-complex scripts. A shaper is selected and
configured automatically by HarfBuzz based on the script and language
properties.

### Kerning

Kering is about adjusting the spacing between some letter pairs so that the
negative space between letters is normalized. The usual suspects are the
pairs "VA", "To", etc. These adjustment tables are stored in the font and are
applied as part of shaping.

### Advance

How much the current point must advance to position the next glyph. Each
glyph has an x-advance used for horizontal text flow and an y-advance used
for vertical text flow.

### Bidirectional text

Bidirectional text is when a paragraph contains both left-to-right (LTR) text
and right-to-left (RTL) text (Arabic, Hebrew, etc.). Such text must be
processed by the [Unicode Bidirectional Algorithm](https://unicode.org/reports/tr9/)
(UAX#9 for short) whose goal is to change the order in which the LTR and RTL
segments are displayed on each line that contain both LTR and RTL parts.

## Bidirectional embedding level

Bidi text can be seen as a nested tree of alternating LTR and RTL segments.
The embedding level is a per-character number that tells the depth at which
the character is at in this tree. At level 0 the direction is same as the
paragraph's base direction (whether that's LTR or RTL). At level 1 it's the
opposite direction and so on.

### Unicode Bidirectional Algorithm

The bidi algorithm has two parts.

The first part of the algorithm is run before itemization. It is applied on
each paragraph and results in two bits of information: the paragraph's base
direction and the _bidirectional embedding level_ of each character. This
informs the itemizer of direction changes in the text so it can itemize at
those points.

Because a new segment is created at each direction-change boundary, the
embedding level ends up being stored per segment, not for each character as
computed by FriBidi.

The second part of the algorithm happens after line-wrapping and it is applied
on a line-by-line basis. It uses the embedding levels from the first part
to reorder the segments in lines with mixed direction.

In tr, the first part of the algorithm is outsourced to the FriBidi library.
The reordering part is implemented in Terra as part of tr.

### Line breaking

Line breaking is about deciding on how to split the text into lines. The
decision starts with the
[Unicode Line Breaking Algorithm](https://unicode.org/reports/tr14/)
(UAX#14 or LBA for short) which is about finding both mandatory line-breaking
points as well as word-wrapping opportunities in the text. The text is then
itemized at those breaking points.

Mandatory breaking points aka hard line breaks are at CR, LF, LS and PS.

Soft line breaks are informed by spaces and punctuation, but it gets more
complicated for languages that don't use spaces between words (Thai, Lao,
Khmer), languages that wrap syllables (Tibetan), languages that can wrap
either syllabes or words based on user preference (Korean), languages that
wrap characters (Japanese, Chinese) but contain exceptions, and it can get
[even more complicated](http://w3c.github.io/i18n-drafts/articles/typography/linebreak.en).
The LBA doesn't cover complex cases that require hyphenation dictionaries
or advanced knowledge of the language. Needless to say, tr doesn't cover
those either.

In tr, the LBA is outsourced to the libunibreak library.

### Itemization

Given a piece of Unicode text and a list of _spans_ containing semantic and
stylistic information for each arbitrary sub-portion of the text, itemization
is the process of breaking down the text into _segments_ for the purpose of
shaping, line/word-wrapping and rasterization.

The idea is to break down the text into the largest pieces that have enough
relevant properties in common to be shaped as a unit, but are also the
smallest pieces that are allowed to be word-wrapped. To that effect, a new
segment is cut whenever:

  * script and/or language changes from the previous span.
  * there's an opportunity for word-wrapping (a space, tab, etc. is encountered).
  * a hard line break is encountered.
  * the BiDi embedding level changes (more on that later).
  * the font and/or font size changes.
  * the list of specified OpenType features changes.

_Sub-segments_ inside a single segment are also created whenever the text
color or opacity changes, but other properties don't. This is necessary
because cutting segments at color-change boundaries and shaping those
separately would not always lead to correct output (eg. ligatures would not
be formed between segments).

### Shaping

Given a font at a selected size and a piece of Unicode text containing
codepoints in a single script and language, shaping is the process of
selecting the right glyphs from the font and also how these glyphs must be
positioned relative to each other in order to best represent the text on
screen. This process can imply:

  * choosing the right glyph id for each codepoint.
  * chosing ligature glyphs for certain groups of codepoints if available.
  * choosing the correct letter forms based on where the letter is in the
    word for cursive scripts like Arabic.
  * composing glyphs out of combining marks and positioning those marks
    if precomposed forms are not available in the font.
  * applying kerning.

Because of hinting, shaping results differ at different font sizes.

Shaping in tr is completely outsourced to the HarfBuzz shaping library.
Shaping is applied separately on each itemized segment and the shaping
results (glyph indices and their positioning) are cached in so-called
_glyph runs_. Each segment keeps a counted reference to its glyph run.

### Glyph Rasterization

Rasterization is the process of converting vector glyph outlines into 8-bit
alpha bitmaps that can be cached and reused many times. Rasterized bitmaps
are alpha-blended on screen according to color, opacity and operator and
positioned based on information got from shaping.

tr has a second level of rasterization where it rasterizes whole glyph runs
which speeds up painting considerably. The overhead of not doing this is
probably split between the hashmap lookups into the glyph cache, the CPU
cache misses from getting to each glyph image and the overhead of
alpha-blending many small cairo surfaces onto the target surface.

### Hinting

Font hinting is about adjusting the outlines of glyphs so that they line up
with screen pixels to produce more legible text at small sizes.

Hinting can be a feature of a font as in TrueType, or it can be a feature of
the rasterization engine as in FreeType's auto-hinter.

Hinting can be applied on the x-axis, y-axis or both. Because x-axis hinting
tends to produce uneven letter gaps in words and because the text tends to
dance funny when sled horizontally (eg. when resizing a window with justified
or centered text), x-axis hinting is by default disabled. Vertical hinting is
usually required on low-dpi screens so it's by default enabled.

### Subpixel rendering

Subpixel rendering is a rendering technique that tries to effectively triple
the perceived resolution of a RGB LCD display by taking advantage of the fact
that each pixel on a LCD display is actually composed of three individual
subpixels fore red, green and blue respectively. Microsoft calls this
ClearType. In practice this technique often creates visible color fringes
(aka chromatic aliasing) because of many factors that are hard to control or
not known by the rendering engine. FreeType can do subpixel rendering but
in this is disabled by default in tr.

### Subpixel antialiasing

Subpixel antialiasing (aka subpixel positioning) means that one glyph will
have more than one rasterization based on the subpixel fraction of the
coordinates at which it is rasterized at. This is not a feature per-se
because as long as glyph positions are fractional, a glyph will naturally end
up with different rasterizations (this is how antialiasing works). But because
historically text rendering engines didn't support fractional glyph positions
this is mentioned as a feature.

tr enables subpixel positioning only on the x-axis by default because hinting
is enabled on the y-axis.

