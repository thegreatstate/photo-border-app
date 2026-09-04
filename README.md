# Border

An iOS app plus a Photos Edit Extension that adds film-style borders
(Polaroid, negative-carrier black rebate + white mat, keyline mat) to a
photo and saves the result back to your Photos library, without touching
the original.

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
documented `Photos`/`PhotosUI`/`PHContentEditingController` APIs, but you
should expect the first build to surface a compiler error or two. Send them
back and I'll fix them.

## How it works

- `PhotoBorderKit/` — the border compositor (Core Graphics), shared by the
  app and the extension. Templates and aspect ratios are plain data
  (`BorderTemplate`, `AspectRatio`) in `BorderTemplateCatalog.swift` — add a
  new frame by adding an entry there, no UI code needed.
- `App/` — a standalone app: pick a photo, preview a border, "Save As new
  photo" writes a new asset into Photos with the original's `creationDate`
  copied over, so it sorts into place chronologically next to the source
  photo instead of landing at "today."
- `Extension/` — the same border logic exposed as a Photos Edit Extension.
  This is the "select a favorite, save it back, stays in order" flow you
  described from your B&W app — it edits the existing asset in place, and
  Photos' own non-destructive editing model is what keeps the original
  recoverable, not anything this code does.

## Adding your real 6x6 / 35mm negative-carrier borders

`negative-carrier-6x6` and `negative-carrier-35mm` in
`BorderTemplateCatalog.swift` currently draw the black rebate procedurally —
a jittered stroke, a rough stand-in for the real edge, not a copy of your
actual carrier. To swap in the real thing once you've pulled a border out
in Photoshop:

1. In Photoshop, isolate just the border art from a scan or print — cut a
   hole in it where the photo sits, and export a PNG with alpha in that
   hole (fully transparent) and opaque everywhere the border itself is.
2. Add the PNG to the app's asset catalog (Xcode: File → New → File →
   Asset Catalog if one doesn't exist yet, then drag the PNG in) — do this
   for both the `PhotoBorderApp` and `PhotoBorderExtension` targets, or
   move the images into a shared resource bundle if you end up with
   several.
3. On the template, set `overlayAssetName` to that asset's name and
   `overlayPhotoWindow` to the transparent hole's position, as fractions
   (0...1) of the overlay PNG's own width/height — `x`/`y` for the top-left
   corner, `width`/`height` for its size. The renderer then crops your
   photo to fit that window and draws your border art on top; the
   procedural `bands` on that template stop being used.

Export each overlay PNG at high resolution (near the long edge of the
photos you'll be framing, e.g. ~4000px) — the renderer doesn't upscale the
photo to make up for a small overlay, so a low-res overlay caps your output
quality.

Repeat per aspect ratio / stock you shoot (6x6, 35mm, 4x6, 5x6, panoramic,
etc.) — each is one more `BorderTemplate` entry in the catalog.
