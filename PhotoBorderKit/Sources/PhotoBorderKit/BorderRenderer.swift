import UIKit

public enum BorderRenderer {

    /// Composites `image` into `template`, producing the final bordered photo
    /// at (approximately) the source photo's own resolution.
    public static func render(image: UIImage, template: BorderTemplate, aspectRatios: [AspectRatio] = AspectRatio.builtIn) -> UIImage? {
        if let overlayName = template.overlayAssetName, let window = template.overlayPhotoWindow {
            return renderWithOverlay(image: image, overlayAssetName: overlayName, photoWindow: window)
        }
        return renderProcedural(image: image, template: template, aspectRatios: aspectRatios)
    }

    // MARK: - Procedural bands (Polaroid, keyline mat, negative-carrier rebate)

    private static func renderProcedural(image: UIImage, template: BorderTemplate, aspectRatios: [AspectRatio]) -> UIImage? {
        guard let cgImage = image.cgImage,
              let aspect = aspectRatios.first(where: { $0.id == template.aspectRatioID }),
              !template.bands.isEmpty else { return nil }

        let sourceSize = CGSize(width: cgImage.width, height: cgImage.height)
        let sourceIsPortrait = sourceSize.height >= sourceSize.width
        let ratio = CGFloat(aspect.longToShort)

        let photoWidth: CGFloat
        let photoHeight: CGFloat
        if sourceIsPortrait {
            photoWidth = min(sourceSize.width, sourceSize.height / ratio)
            photoHeight = photoWidth * ratio
        } else {
            photoHeight = min(sourceSize.height, sourceSize.width / ratio)
            photoWidth = photoHeight * ratio
        }

        let cropRect = centeredCropRect(sourceSize: sourceSize, targetSize: CGSize(width: photoWidth, height: photoHeight))
        guard let croppedCG = cgImage.cropping(to: cropRect) else { return nil }

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
                color.setFill()
                cg.fill(rect)
                let w = CGFloat(band.widthFraction) * shortSide
                let innerEdge = rect.insetBy(dx: w, dy: w)
                if band.irregularEdge {
                    drawIrregularEdge(in: cg, boundary: innerEdge, color: color, jitter: max(1, shortSide * 0.008))
                }
                rect = innerEdge
            }

            UIImage(cgImage: croppedCG).draw(in: photoRect)
        }
    }

    /// Draws a hand-torn-looking jittered outline centered on `boundary`, in
    /// `color`, so the band it belongs to bites raggedly into whatever gets
    /// drawn next inside it. This is a rough procedural stand-in for a real
    /// negative-carrier's rebate edge — swap in a scanned overlay
    /// (`overlayAssetName`) for the real thing.
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

    private static func renderWithOverlay(image: UIImage, overlayAssetName: String, photoWindow: NormalizedRect) -> UIImage? {
        guard let overlay = UIImage(named: overlayAssetName),
              let overlayCG = overlay.cgImage,
              let cgImage = image.cgImage else { return nil }

        let canvasSize = CGSize(width: overlayCG.width, height: overlayCG.height)
        let photoRect = CGRect(x: photoWindow.x * canvasSize.width,
                                y: photoWindow.y * canvasSize.height,
                                width: photoWindow.width * canvasSize.width,
                                height: photoWindow.height * canvasSize.height)

        let sourceSize = CGSize(width: cgImage.width, height: cgImage.height)
        let targetRatio = photoRect.width / photoRect.height
        let sourceRatio = sourceSize.width / sourceSize.height
        var cropSize = sourceSize
        if sourceRatio > targetRatio {
            cropSize.width = sourceSize.height * targetRatio
        } else {
            cropSize.height = sourceSize.width / targetRatio
        }
        let cropRect = centeredCropRect(sourceSize: sourceSize, targetSize: cropSize)
        guard let croppedCG = cgImage.cropping(to: cropRect) else { return nil }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)
        return renderer.image { ctx in
            UIColor.white.setFill()
            ctx.cgContext.fill(CGRect(origin: .zero, size: canvasSize))
            UIImage(cgImage: croppedCG).draw(in: photoRect)
            UIImage(cgImage: overlayCG).draw(in: CGRect(origin: .zero, size: canvasSize))
        }
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
