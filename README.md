# Border

An iOS app plus a Photos Edit Extension that adds film-style borders
(Polaroid, negative-carrier black rebate + white mat, keyline mat, and a
real scanned rebate) to a photo — with dynamic aspect-ratio fitting,
signature/title/numbering captions, and basic tone edits — and saves the
result back to your Photos library, without touching the original.

## Build

Requires a Mac with Xcode 15+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen)
(the `.xcodeproj` isn't committed — it's generated from `project.yml` so the
project file can't drift out of sync with the source tree):

```
brew install xcodegen
cd PhotoBorder
xcodegen generate
open PhotoBorder.xcodeproj
```

Select the `PhotoBorderApp` scheme and run on a device or the simulator,
signed into Photos with a library that has some photos in it. First run
will prompt for photo library access.

To use the Edit Extension: run the app once (so iOS registers the
extension), then open the Photos app, pick any photo, tap Edit, tap the
"⋯" (More) icon among the filter/adjust icons, and enable "Border Frame".

I have not been able to compile or run this myself — this session has no
Xcode or iOS simulator available. Everything above is written against the
documented `Photos`/`PhotosUI`/`PHContentEditingController`/Core
Image/Core Graphics APIs, but you should expect the first build to surface
a compiler error or two. Send them back and I'll fix them.

## How it works

- `PhotoBorderKit/` — the shared engine (Core Graphics + Core Image),
  used by both the app and the extension:
  - `BorderTemplateCatalog.swift` — the frame list. Templates and aspect
    ratios are plain data (`BorderTemplate`, `AspectRatio`) — add a new
    frame by adding an entry, no UI code needed.
  - `BorderRenderer.swift` — crops or reflows the photo to fit, draws the
    border (procedural bands or a scanned overlay), then draws any caption
    text layers on top.
  - `PhotoFitMode.swift` — `.crop` (the traditional approach) or
    `.reflow(cornerFraction:)`, a 9-slice stretch: a fixed-size margin at
    each edge is kept pixel-for-pixel, and only the band between them
    stretches to absorb an aspect-ratio change (e.g. fitting a 4x6-shot
    photo into a 5x7 frame). This is **not** content-aware/seam-carving —
    it doesn't know what's in the photo, so it stretches whatever falls in
    the middle band. That's usually fine for a landscape with sky/ground
    through the center, and a bad fit for a subject dead-center in frame.
    True seam carving (Photoshop's Content-Aware Scale) picks *where* to
    cut based on image content and is a much bigger algorithm — this
    9-slice version is the buildable v1.
  - `TextLayer.swift` / `FontChoice` — signature/title/numbering captions,
    each with its own font, size, color, and position. `FontChoice` sticks
    to built-in iOS fonts (Snell Roundhand for a signature look, Noteworthy
    and Marker Felt for handwriting/pencil, American Typewriter for
    titles) so nothing needs bundling — swap in a custom font file later if
    you want a specific look.
  - `PhotoAdjustments.swift` — brightness/contrast/saturation and a
    black & white toggle, applied before the border.
  - `EditorControls.swift` — the SwiftUI controls (adjustment sliders,
    caption fields, fit toggle) shared by the app and the extension so the
    two UIs can't drift apart.
- `App/` — a standalone app: pick a photo, preview a border, "Save As new
  photo" writes a new asset into Photos with the original's `creationDate`
  copied over, so it sorts into place chronologically next to the source
  photo instead of landing at "today." Also has an auto-numbering toggle
  that increments an edition counter after each save.
- `Extension/` — the same logic exposed as a Photos Edit Extension. This is
  the "select a favorite, save it back, stays in order" flow you described
  from your B&W app — it edits the existing asset in place, and Photos' own
  non-destructive editing model is what keeps the original recoverable, not
  anything this code does. (The auto-numbering counter is app-only for now
  — sharing it with the extension needs an App Group entitlement, which
  isn't set up.)
- `SharedAssets/Assets.xcassets/` — image assets (currently just the one
  scanned border below), included in both targets.

## The one real scanned border (`scanned-rebate-5x7`)

You sent a reference print with a black rebate + white mat; I extracted the
actual border pixels from it into `SharedAssets/Assets.xcassets/negative-carrier-sample.imageset`,
wired up as the `scanned-rebate-5x7` template via `overlayAssetName` +
`overlayPhotoWindow`. Worth knowing how, since you said more reference
photos are coming and I'll repeat this:

This took three attempts to get right, each exposing a real gap in the one
before it:

1. **Tracing all four edges independently**, scanning pixel brightness
   inward from each side. Clean on the top and left, but the dark car and
   boots sit directly against the black border on the bottom/right with no
   brightness gap between them, so the scan couldn't tell "border" from
   "dark photo content" there and produced an obviously-contaminated cutout.
2. **Mirroring the top/left measurements to the bottom/right** instead of
   re-detecting them (reasoning: it's a manufactured, straight-edged
   rectangle, so the far sides should match). This assumed the print's
   margins are perfectly symmetric, which they weren't quite — close enough
   that it mostly worked, but off by a few pixels at the corners, which
   showed up as a strip of the *original photo's actual white margin* still
   visible instead of solid black exactly where you spotted it.
3. **What actually shipped:** detect all four edges directly (not
   mirrored), but per line (each row/column), reject any reading whose
   width falls outside a plausible range *or* strays too far from that
   edge's own robust median position — a straight rectangle has no business
   curving, so a contaminated stretch gets held at the median instead of
   interpolated (interpolating between two "plausible-looking" points on
   either side of a bad patch let a coincidentally-plausible bad reading
   drag a smooth, visibly-wrong bulge through the gap between them). Then,
   within that geometric band, anything lighter than ~75% brightness is
   dropped too, so antialiased/lighter pixels the geometry alone still let
   through don't show up as a washed-out edge.

This only works because the border is a clean rectangle. A hand-torn or
irregular carrier edge (like the "sloppy black" look from your first
message) can't be mirrored this way — that's what `negativeCarrier6x6` /
`negativeCarrier35mm` still approximate procedurally (with a jittered
stroke) pending a real scan of one of those.

## Adding more real borders

Drop reference photos into `Borders/` at the repo root (create it if it's
not there) — commit and push from GitHub Desktop (or `git`) and I'll pull
them from there. That folder is just for raw source material, not app
assets; it's separate from `SharedAssets/Assets.xcassets`, which only holds
what's actually wired into a `BorderTemplate` and shipped in the app.

If what you drop in is already a finished transparent PNG (interior *and*
everything outside the ring already cut to alpha 0 — check with
`im.getchannel('A').getextrema()` in Pillow, or just open it over a colored
background), there's no extraction to do at all: it goes straight into
`SharedAssets/Assets.xcassets` and gets a `BorderTemplate` entry. That's
how `mamiya-border` (below) got added.

For a **straight-edged** carrier that isn't already cut out: send the photo
and I'll repeat the top/left-and-mirror extraction above.

For a **hand-torn/irregular** carrier, or if you'd rather do it yourself in
Photoshop:

1. Isolate just the border art from a scan or print — cut a hole in it
   where the photo sits, and export a PNG with alpha in that hole (fully
   transparent) and opaque everywhere the border itself is.
2. Add the PNG to `SharedAssets/Assets.xcassets` (drag it into Xcode, or
   make a new `.imageset` folder with a PNG + `Contents.json` like
   `negative-carrier-sample.imageset`) — it's already wired into both
   targets via `project.yml`, so nothing else to configure there.
3. Add a `BorderTemplate` with `overlayAssetName` set to that asset's name
   and `overlayPhotoWindow` set to the transparent hole's position, as
   fractions (0...1) of the overlay PNG's own width/height — `x`/`y` for
   the top-left corner, `width`/`height` for its size.

Export each overlay PNG at high resolution (near the long edge of the
photos you'll be framing, e.g. ~4000px) — the renderer doesn't upscale the
photo to make up for a small overlay, so a low-res overlay caps your output
quality.

Repeat per aspect ratio / stock you shoot (6x6, 35mm, 4x6, 5x6, panoramic,
etc.) — each is one more `BorderTemplate` entry in the catalog.

## Stretching a border to a different aspect ratio (`mamiya-border`)

`mamiya-border` is a real pre-made transparent PNG you supplied directly
(no extraction needed — see above), with one edit: the original file had a
soft gray brush texture outside the black ring (partial alpha, not just
0/255). Per your call, that got cleaned out — `Borders/Mamiya Border.png`
is the untouched original; the shipped asset keeps only pixels darker than
~47% gray as opaque almost everywhere, so it reads as a clean black line on
flat white rather than a textured edge.

That threshold alone left a defect worth knowing about, since the same fix
applies to any future asset cleaned this way: each corner has its own
light-gray highlight (part of the art's actual corner rendering, not
outer texture), the same tone as the unwanted texture, physically
touching it in places — so no plain darkness threshold or connected-
components pass can separate "keep" from "drop" by color or topology alone
at the corners specifically. Thresholding by darkness alone bit a chunk out
of the ring at each corner, leaving a gap where white showed through
between the photo and the ring. The fix: keep the darkness threshold
everywhere except a small protected zone at each of the four corners,
where the original pixels are restored untouched — trading a faint,
barely-visible fleck of the outer texture at just the four corners for a
structurally solid ring everywhere, which matters far more. Straight
edges away from the corners were never affected by any of this.

Its native shape is square, but that's just an accident of this particular
source file, not a deliberate format choice — **the standing rule is that
a photo's own aspect ratio never gets touched unless you explicitly ask
for a specific one.** So `BorderRenderer.render(...)`'s `overlayAspect`
parameter defaults to `.matchPhoto`: the border artwork itself gets
reshaped to whatever aspect ratio the photo already has, using the same
corner-preserving 9-slice technique `PhotoFitMode.reflow` already uses on
photos (see `reflowOverlayArt` in `BorderRenderer.swift`) — corners stay
pixel-perfect, only the straight edge segments between them stretch or
compress. A portrait photo gets a portrait border, a landscape photo gets
a landscape border, automatically, with nothing cropped or distorted.

Two other modes exist for when a specific format *is* explicitly wanted:
`.nativeArt` uses the border's own authored aspect as-is and crops the
photo to fit it (this was the old default, before the standing rule);
`.fixed(ratio)` forces a specific width/height ratio (e.g. an 11x14 print)
independent of both the photo's and the art's own shape. Neither is used
by default anywhere in the app — `.matchPhoto` is, everywhere, until told
otherwise.

## Darkroom B&W (`DarkroomBW.swift`)

A B&W mode is not a slider on the color-editing panel — a genuine
darkroom conversion and a color photo have almost nothing in common in
what they need control over, so this is a separate, deliberately minimal
mode (`DarkroomBWSettings` / `DarkroomBWProcessor`), modeled directly on
AgBr's own control set rather than Apple Photos' slider bank:

- **Color Filter** (none/yellow/orange/red/green) — a real channel-mixer
  conversion (each filter is a fixed R/G/B weighting), not a desaturation.
  A desaturated pixel loses all its original hue information; this doesn't
  — a red filter genuinely darkens blue sky and lightens skin, the way
  shooting panchromatic film through a colored lens filter does.
- **Film Size** (35mm/120/4x5) — grain scale. A smaller negative enlarged
  more shows coarser grain at a given output size than a larger one.
- **Density** — the print's own base tone, independent of exposure.
- **Pull/Push** — one control, not two: real push/pull processing couples
  contrast and grain together (push = more of both; pull = less of both),
  so this drives both at once rather than exposing them as separate knobs
  that could be set inconsistently with how film actually behaves.
- **Exposure** — separate from Density on purpose: a real darkroom print
  has both a negative's own density *and* how long you expose the paper
  under the enlarger, and those are genuinely different variables even
  though both end up shifting brightness.

This was prototyped in Python against a real photo before being ported
(same as the border extraction work) — the recipe you're seeing here is
calibrated, not guessed. One thing that prototype does that the Swift port
doesn't yet: grain intensity there is modulated by local luminance (more
visible in shadows/mid-tones, fades in highlights); porting that cleanly
needs a custom `CIKernel` for per-pixel masking, which felt like more to
get wrong blind than to ship — the Swift version applies uniform grain
strength across the tone range instead. Worth revisiting once this is
actually running in Xcode and you can see if flat highlights read as
grainy. I have not been able to compile or run any of this Swift code —
same caveat as the rest of this project.
