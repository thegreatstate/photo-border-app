import UIKit

public enum BorderRenderer {

    /// For overlay-based templates only (ignored for procedural ones, which
    /// already adapt to any aspect ratio): how the border artwork's aspect
    /// ratio relates to the photo's own.
    public enum OverlayAspectMode {
        /// The default and the standing rule: never touch the photo's own
        /// format. The border artwork is reshaped (corner-preserving
        /// 9-slice, see `reflowOverlayArt`) to match the photo's aspect
        /// ratio exactly, so nothing about the photo gets cropped or
        /// distorted to fit the border.
        case matchPhoto
        /// Use the border art's own authored aspect ratio as-is, and crop
        /// the photo to fit it instead. Only for when a specific format is
        /// explicitly wanted — e.g. the border itself was scanned at a
        /// print ratio you're deliberately printing to.
        case nativeArt
        /// Force a specific width/height ratio, reshaping the border art to
        /// it (photo is then cropped/fit into that same ratio) — for an
        /// explicit print size (e.g. 11x14) independent of both the art's
        /// native shape and the photo's own.
        case fixed(Double)
    }

    /// Composites `image` into `template`, producing the final bordered photo
    /// at (approximately) the source photo's own resolution.
    public static func render(
        image: UIImage,
        template: BorderTemplate,
        fit: PhotoFitMode = .crop,
        overlayAspect: OverlayAspectMode = .matchPhoto,
        textLayers: [TextLayer] = [],
        aspectRatios: [AspectRatio] = AspectRatio.builtIn
    ) -> UIImage? {
        // Bake in EXIF orientation before touching raw CGImage pixel
        // dimensions anywhere below — a photo shot in portrait can have a
        // landscape pixel buffer plus a rotation tag (very common straight
        // out of `UIImage(contentsOfFile:)`), and every crop/fit computation
        // here works in raw pixel space.
        let image = normalizedUp(image)

        let result: UIImage?
        if let overlayName = template.overlayAssetName, let window = template.overlayPhotoWindow {
            let targetAspect: CGFloat?
            switch overlayAspect {
            case .matchPhoto:
                guard let cg = image.cgImage else { return nil }
                targetAspect = CGFloat(cg.width) / CGFloat(cg.height)
            case .nativeArt:
                targetAspect = nil
            case .fixed(let ratio):
                targetAspect = CGFloat(ratio)
            }
            result = renderWithOverlay(image: image, overlayAssetName: overlayName, photoWindow: window,
                                        fit: fit, targetAspect: targetAspect)
        } else {
            result = renderProcedural(image: image, template: template, fit: fit, aspectRatios: aspectRatios)
        }
        guard let composited = result, !textLayers.isEmpty else { return result }
        return drawTextLayers(textLayers, onto: composited)
    }

    private static func normalizedUp(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { _ in image.draw(at: .zero) }
    }

    // MARK: - Procedural bands (Polaroid, keyline mat, negative-carrier rebate)

    private static func renderProcedural(image: UIImage, template: BorderTemplate, fit: PhotoFitMode, aspectRatios: [AspectRatio]) -> UIImage? {
        guard let aspect = aspectRatios.first(where: { $0.id == template.aspectRatioID }),
              !template.bands.isEmpty else { return nil }

        // Procedural templates adapt to the source's own orientation: a
        // portrait photo gets a portrait crop, landscape gets landscape,
        // both at the same long/short ratio.
        guard let sourceCG = image.cgImage else { return nil }
        let sourceIsPortrait = sourceCG.height >= sourceCG.width
        let targetAspect: CGFloat = sourceIsPortrait ? 1 / CGFloat(aspect.longToShort) : CGFloat(aspect.longToShort)

        guard let (croppedCG, photoWidth, photoHeight) = preparedPhoto(image: image, targetAspect: targetAspect, fit: fit) else {
            return nil
        }

        let shortSide = min(photoWidth, photoHeight)
        let totalBandWidth = template.bands.reduce(0.0) { $0 + $1.widthFraction }
        let inset = CGFloat(totalBandWidth) * shortSide
        let extraBottom = CGFloat(template.extraBottomFraction) * shortSide

        let canvasSize = CGSize(width: photoWidth + inset * 2,
                                 height: photoHeight + inset * 2 + extraBottom)
        let photoRect = CGRect(x: inset, y: inset, width: photoWidth, height: photoHeight)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let uiRenderer = UIGraphicsImageRenderer(size: canvasSize, format: format)

        return uiRenderer.image { ctx in
            let cg = ctx.cgContext

            // Fill the whole canvas with the outermost band's color first —
            // this also covers the Polaroid-style bottom foot, which sits
            // outside the normal band stack.
            let outermostColor = UIColor(hex: template.bands.last?.colorHex ?? "#FFFFFF") ?? .white
            outermostColor.setFill()
            cg.fill(CGRect(origin: .zero, size: canvasSize))

            var rect = CGRect(x: 0, y: 0, width: canvasSize.width, height: canvasSize.height - extraBottom)
            for band in template.bands.reversed() {
                guard let color = UIColor(hex: band.colorHex) else { continue }
                // The boundary facing outward (toward whatever's already
                // been drawn — the mat, or the canvas edge) is where a
                // filed-out carrier's hand-worked roughness belongs. The
                // boundary facing inward (toward the photo) is the
                // camera's own film gate opening — a precise mechanical
                // edge, always clean — so irregularity is drawn on `rect`
                // (this band's own outer edge) before it gets inset, never
                // on the inner edge below.
                if band.irregularEdge {
                    drawIrregularEdge(in: cg, boundary: rect, color: color, jitter: max(1, shortSide * 0.008))
                }
                cg.fill(rect)
                let w = CGFloat(band.widthFraction) * shortSide
                let innerEdge = rect.insetBy(dx: w, dy: w)
                rect = innerEdge
            }

            UIImage(cgImage: croppedCG).draw(in: photoRect)
        }
    }

    /// Draws a hand-torn-looking jittered outline centered on `boundary`, in
    /// `color`, so the band bites raggedly into whatever was already drawn
    /// outside it (a coarser band, or the canvas edge). Only ever called on
    /// a band's *outer* boundary (`rect`, before it's inset) — the inner
    /// boundary, facing the photo, is the camera's own film gate opening in
    /// real life and stays a clean rectangle no matter what. This is a rough
    /// procedural stand-in for a real negative-carrier's filed edge — swap
    /// in a scanned overlay (`overlayAssetName`) for the real thing.
    private static func drawIrregularEdge(in cg: CGContext, boundary: CGRect, color: UIColor, jitter: CGFloat) {
        let stepsPerSide = 24
        func jittered(_ p: CGPoint) -> CGPoint {
            CGPoint(x: p.x + CGFloat.random(in: -jitter...jitter), y: p.y + CGFloat.random(in: -jitter...jitter))
        }
        var points: [CGPoint] = []
        for i in 0...stepsPerSide {
            let t = CGFloat(i) / CGFloat(stepsPerSide)
            points.append(jittered(CGPoint(x: boundary.minX + t * boundary.width, y: boundary.minY)))
        }
        for i in 0...stepsPerSide {
            let t = CGFloat(i) / CGFloat(stepsPerSide)
            points.append(jittered(CGPoint(x: boundary.maxX, y: boundary.minY + t * boundary.height)))
        }
        for i in 0...stepsPerSide {
            let t = CGFloat(i) / CGFloat(stepsPerSide)
            points.append(jittered(CGPoint(x: boundary.maxX - t * boundary.width, y: boundary.maxY)))
        }
        for i in 0...stepsPerSide {
            let t = CGFloat(i) / CGFloat(stepsPerSide)
            points.append(jittered(CGPoint(x: boundary.minX, y: boundary.maxY - t * boundary.height)))
        }
        guard let first = points.first else { return }
        let path = UIBezierPath()
        path.move(to: first)
        for p in points.dropFirst() { path.addLine(to: p) }
        path.close()
        color.setStroke()
        path.lineWidth = jitter * 2.2
        path.stroke()
    }

    // MARK: - Overlay-driven bands (your Photoshop-extracted carrier borders)

    private static func renderWithOverlay(image: UIImage, overlayAssetName: String, photoWindow: NormalizedRect, fit: PhotoFitMode, targetAspect: CGFloat?) -> UIImage? {
        guard let overlay = UIImage(named: overlayAssetName),
              let nativeOverlayCG = overlay.cgImage else { return nil }

        let nativeCanvasSize = CGSize(width: nativeOverlayCG.width, height: nativeOverlayCG.height)
        let nativeWindow = CGRect(x: photoWindow.x * nativeCanvasSize.width,
                                   y: photoWindow.y * nativeCanvasSize.height,
                                   width: photoWindow.width * nativeCanvasSize.width,
                                   height: photoWindow.height * nativeCanvasSize.height)

        // If a different overall aspect was requested (e.g. taking a square
        // border to 4x6), reshape the border artwork itself first, corners
        // preserved, same as the photo's own 9-slice reflow. Otherwise use
        // the art exactly as authored — the existing, unchanged behavior.
        let overlayCG: CGImage
        let canvasSize: CGSize
        let photoRect: CGRect
        if let targetAspect,
           let reflowed = reflowOverlayArt(overlayCG: nativeOverlayCG, nativeWindow: nativeWindow, targetAspect: targetAspect) {
            overlayCG = reflowed.image
            canvasSize = CGSize(width: reflowed.image.width, height: reflowed.image.height)
            photoRect = reflowed.window
        } else {
            overlayCG = nativeOverlayCG
            canvasSize = nativeCanvasSize
            photoRect = nativeWindow
        }

        // Overlay templates have a fixed window shape baked into the art —
        // crop to exactly that shape, regardless of the source photo's own
        // orientation (unlike the procedural path, which adapts to it).
        let windowAspect = photoRect.width / photoRect.height

        guard let (croppedCG, _, _) = preparedPhoto(image: image, targetAspect: windowAspect, fit: fit) else {
            return nil
        }

        // Draw the photo slightly larger than the measured window, bleeding
        // a touch under the ring on every side, rather than meeting it
        // edge-to-edge — any small imprecision in exactly where a window
        // was measured (or a future asset's window) then falls safely
        // under the opaque ring instead of showing as a gap. Both
        // dimensions scale by the same factor, so this doesn't distort the
        // photo's aspect ratio.
        let overscan: CGFloat = 0.008
        let drawRect = photoRect.insetBy(dx: -photoRect.width * overscan, dy: -photoRect.height * overscan)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)
        return renderer.image { ctx in
            UIColor.white.setFill()
            ctx.cgContext.fill(CGRect(origin: .zero, size: canvasSize))
            UIImage(cgImage: croppedCG).draw(in: drawRect)
            UIImage(cgImage: overlayCG).draw(in: CGRect(origin: .zero, size: canvasSize))
        }
    }

    /// Reshapes overlay border artwork to `targetAspect` (width / height)
    /// using the same corner-preserving 9-slice technique as the photo's own
    /// `PhotoFitMode.reflow`: a corner-sized margin at each edge (sized to
    /// safely contain the ring's own corner treatment) is copied
    /// pixel-for-pixel, and only the straight edge segments between them
    /// stretch or compress. Height is kept at the art's native height;
    /// width is solved from `targetAspect`. Returns the reshaped artwork
    /// (alpha preserved) and where the photo window landed in it — the
    /// window's corner-anchored edges keep the same pixel inset from their
    /// nearest canvas edge, since they sit inside the untouched corner
    /// bands.
    private static func reflowOverlayArt(overlayCG: CGImage, nativeWindow: CGRect, targetAspect: CGFloat) -> (image: CGImage, window: CGRect)? {
        let W = CGFloat(overlayCG.width), H = CGFloat(overlayCG.height)
        let insetLeft = nativeWindow.minX
        let insetTop = nativeWindow.minY
        let insetRight = W - nativeWindow.maxX
        let insetBottom = H - nativeWindow.maxY

        // A little beyond the window's own inset, to fully protect whatever
        // corner flourish the art has (rounded corners, brush texture) —
        // matched against a prototype that held up well at +10px on a
        // ~2800px-wide source; scale that margin with resolution.
        let cornerMargin = max(insetLeft, insetTop, insetRight, insetBottom) + (W * 0.0035)

        let targetH = H
        let targetW = targetH * targetAspect
        let safeCorner = min(cornerMargin, W / 2 - 1, H / 2 - 1, targetW / 2 - 1, targetH / 2 - 1)
        guard safeCorner > 1 else { return nil }

        let srcXs: [CGFloat] = [0, safeCorner, W - safeCorner, W]
        let srcYs: [CGFloat] = [0, safeCorner, H - safeCorner, H]
        let dstXs: [CGFloat] = [0, safeCorner, targetW - safeCorner, targetW]
        let dstYs: [CGFloat] = [0, safeCorner, targetH - safeCorner, targetH]

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false // preserve alpha -- this is border art, not a final flattened composite
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: targetW, height: targetH), format: format)
        let outImage = renderer.image { _ in
            for row in 0..<3 {
                for col in 0..<3 {
                    let srcRect = CGRect(x: srcXs[col], y: srcYs[row],
                                          width: srcXs[col + 1] - srcXs[col], height: srcYs[row + 1] - srcYs[row]).integral
                    let dstRect = CGRect(x: dstXs[col], y: dstYs[row],
                                          width: dstXs[col + 1] - dstXs[col], height: dstYs[row + 1] - dstYs[row])
                    guard srcRect.width > 0, srcRect.height > 0, dstRect.width > 0, dstRect.height > 0,
                          let patch = overlayCG.cropping(to: srcRect) else { continue }
                    UIImage(cgImage: patch).draw(in: dstRect)
                }
            }
        }
        guard let outCG = outImage.cgImage else { return nil }

        // The window's corner-anchored edges sit inside the untouched
        // corner bands, so they keep the same pixel inset from their
        // nearest canvas edge in the reshaped art.
        let newWindow = CGRect(x: insetLeft, y: insetTop,
                                width: targetW - insetLeft - insetRight, height: targetH - insetTop - insetBottom)
        return (outCG, newWindow)
    }

    // MARK: - Shared photo preparation (crop or 9-slice reflow to a target ratio)

    /// Produces a photo-window-ready `CGImage` at exactly `targetAspect`
    /// (width / height), plus its pixel width/height, using whichever `fit`
    /// strategy was asked for. `targetAspect` is signed and exact — callers
    /// decide orientation themselves (adaptive for procedural templates,
    /// fixed for overlay ones), it is never re-derived from the source here.
    private static func preparedPhoto(image: UIImage, targetAspect: CGFloat, fit: PhotoFitMode) -> (CGImage, CGFloat, CGFloat)? {
        guard let cgImage = image.cgImage else { return nil }
        let sourceSize = CGSize(width: cgImage.width, height: cgImage.height)

        switch fit {
        case .crop:
            let photoWidth = min(sourceSize.width, sourceSize.height * targetAspect)
            let photoHeight = photoWidth / targetAspect
            let cropRect = centeredCropRect(sourceSize: sourceSize, targetSize: CGSize(width: photoWidth, height: photoHeight))
            guard let cropped = cgImage.cropping(to: cropRect) else { return nil }
            return (cropped, photoWidth, photoHeight)

        case .reflow(let cornerFraction):
            guard let reflowed = reflowToAspect(cgImage: cgImage, sourceSize: sourceSize,
                                                 targetAspect: targetAspect, cornerFraction: CGFloat(cornerFraction)) else {
                // Fall back to a plain crop rather than failing the whole render.
                return preparedPhoto(image: image, targetAspect: targetAspect, fit: .crop)
            }
            return (reflowed, CGFloat(reflowed.width), CGFloat(reflowed.height))
        }
    }

    /// Reshapes `cgImage` to exactly `targetAspect` (width / height) without
    /// cropping: a `cornerFraction`-sized margin at each edge is copied
    /// pixel-for-pixel, and only the band between them stretches or
    /// compresses to make up the difference — a 9-slice reflow instead of a
    /// crop. The source's own short side sets the output's shorter
    /// dimension; `targetAspect` (not the source's own orientation) decides
    /// which output dimension that short side becomes.
    private static func reflowToAspect(cgImage: CGImage, sourceSize: CGSize, targetAspect: CGFloat, cornerFraction: CGFloat) -> CGImage? {
        let W = sourceSize.width, H = sourceSize.height
        let shortSide = min(W, H)
        let targetW: CGFloat
        let targetH: CGFloat
        if targetAspect >= 1 {
            targetH = shortSide
            targetW = shortSide * targetAspect
        } else {
            targetW = shortSide
            targetH = shortSide / targetAspect
        }

        let corner = shortSide * cornerFraction
        let safeCorner = min(corner, W / 2 - 1, H / 2 - 1, targetW / 2 - 1, targetH / 2 - 1)
        guard safeCorner > 1 else { return nil }

        let srcXs: [CGFloat] = [0, safeCorner, W - safeCorner, W]
        let srcYs: [CGFloat] = [0, safeCorner, H - safeCorner, H]
        let dstXs: [CGFloat] = [0, safeCorner, targetW - safeCorner, targetW]
        let dstYs: [CGFloat] = [0, safeCorner, targetH - safeCorner, targetH]

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: targetW, height: targetH), format: format)
        let image = renderer.image { _ in
            for row in 0..<3 {
                for col in 0..<3 {
                    let srcRect = CGRect(x: srcXs[col], y: srcYs[row],
                                          width: srcXs[col + 1] - srcXs[col], height: srcYs[row + 1] - srcYs[row]).integral
                    let dstRect = CGRect(x: dstXs[col], y: dstYs[row],
                                          width: dstXs[col + 1] - dstXs[col], height: dstYs[row + 1] - dstYs[row])
                    guard srcRect.width > 0, srcRect.height > 0, dstRect.width > 0, dstRect.height > 0,
                          let patch = cgImage.cropping(to: srcRect) else { continue }
                    UIImage(cgImage: patch).draw(in: dstRect)
                }
            }
        }
        return image.cgImage
    }

    private static func centeredCropRect(sourceSize: CGSize, targetSize: CGSize) -> CGRect {
        let x = ((sourceSize.width - targetSize.width) / 2).rounded(.down)
        let y = ((sourceSize.height - targetSize.height) / 2).rounded(.down)
        return CGRect(
            x: max(0, x), y: max(0, y),
            width: min(targetSize.width.rounded(.down), sourceSize.width),
            height: min(targetSize.height.rounded(.down), sourceSize.height)
        )
    }

    // MARK: - Text layers (signature / title / numbering)

    private static func drawTextLayers(_ layers: [TextLayer], onto image: UIImage) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { _ in
            image.draw(at: .zero)
            let shortSide = min(image.size.width, image.size.height)
            for layer in layers {
                guard !layer.text.isEmpty, let color = UIColor(hex: layer.colorHex) else { continue }
                let fontSize = CGFloat(layer.fontSizeFraction) * shortSide
                let font = layer.fontName == FontChoice.system
                    ? UIFont.systemFont(ofSize: fontSize)
                    : (UIFont(name: layer.fontName, size: fontSize) ?? UIFont.systemFont(ofSize: fontSize))

                let paragraph = NSMutableParagraphStyle()
                switch layer.alignment {
                case .left: paragraph.alignment = .left
                case .center: paragraph.alignment = .center
                case .right: paragraph.alignment = .right
                }

                let attributed = NSAttributedString(string: layer.text, attributes: [
                    .font: font, .foregroundColor: color, .paragraphStyle: paragraph,
                ])
                let textSize = attributed.size()
                let anchorX = CGFloat(layer.position.x) * image.size.width
                let anchorY = CGFloat(layer.position.y) * image.size.height
                let rect = CGRect(x: anchorX - textSize.width / 2, y: anchorY - textSize.height / 2,
                                   width: textSize.width, height: textSize.height)
                attributed.draw(in: rect)
            }
        }
    }
}

private extension UIColor {
    convenience init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        let r = CGFloat((v >> 16) & 0xFF) / 255
        let g = CGFloat((v >> 8) & 0xFF) / 255
        let b = CGFloat(v & 0xFF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}
