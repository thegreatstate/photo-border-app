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

**What didn't work:** tracing all four edges independently by scanning
pixel brightness from each side inward. It's fine on the top and left,
but on your reference photo the dark car and boots sit directly against
the black border with no brightness gap between them, so the same
approach on the bottom/right edges couldn't tell "border" from "dark
photo content" and produced a contaminated, obviously-wrong cutout.

**What worked:** your carrier is a manufactured, straight-edged rectangle
(not a hand-torn one), so I only trust the two sides that are
unambiguous — top and left, where the sky and open ground give a clean
brightness jump — measure the margin and rebate width there, and mirror
those measurements to the bottom and right rather than re-detecting them.
That gives a real cutout from your actual photo (not a synthetic
reproduction) without ever having to threshold the contaminated areas.

This only works because the border is a clean rectangle. A hand-torn or
irregular carrier edge (like the "sloppy black" look from your first
message) can't be mirrored this way — that's what `negativeCarrier6x6` /
`negativeCarrier35mm` still approximate procedurally (with a jittered
stroke) pending a real scan of one of those.

## Adding more real borders

For a **straight-edged** carrier: send the photo and I'll repeat the
top/left-and-mirror extraction above.

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
