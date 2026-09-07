import CoreImage
import UIKit

/// A minimal, AgBr-inspired B&W film mode: five simple controls instead of
/// a slider bank, because a color photo and a darkroom B&W print don't need
/// (or want) the same editing surface. Color Filter, Film Size, Density,
/// and Pull/Push mirror AgBr's own control set; Exposure is a separate
/// print-exposure control layered on top, matching how a real darkroom
/// separates the negative's own density from how long you expose the paper.
public struct DarkroomBWSettings: Codable, Hashable {
    /// The classic panchromatic-film color filters: each is a fixed
    /// R/G/B weighting used to flatten color to gray, standing in for how
    /// a colored lens filter changes which wavelengths expose the film
    /// (red filter darkens blue sky and lightens skin; green does the
    /// opposite). This is a real conversion, not a desaturation — every
    /// hue does not collapse to the same gray value.
    public enum ColorFilter: String, Codable, CaseIterable, Identifiable {
        case none, yellow, orange, red, green
        public var id: String { rawValue }

        var weights: (r: Double, g: Double, b: Double) {
            switch self {
            case .none: return (0.30, 0.59, 0.11)
            case .yellow: return (0.40, 0.40, 0.20)
            case .orange: return (0.55, 0.30, 0.15)
            case .red: return (0.75, 0.20, 0.05)
            case .green: return (0.15, 0.75, 0.10)
            }
        }
    }

    /// Controls grain scale: a smaller negative enlarged more (35mm) shows
    /// coarser grain at a given output size than a larger one (4x5).
    public enum FilmSize: String, Codable, CaseIterable, Identifiable {
        case mm35, mm120, in4x5
        public var id: String { rawValue }

        var grainClumpFactor: Double {
            switch self {
            case .mm35: return 1.8
            case .mm120: return 1.2
            case .in4x5: return 0.7
            }
        }
    }

    public var colorFilter: ColorFilter
    public var filmSize: FilmSize
    /// -1...1. The print's own base density (independent of exposure) —
    /// shifts the overall tone darker or lighter.
    public var density: Double
    /// -2...2 (stops). Pull (negative) to push (positive) processing.
    /// Couples contrast and grain intensity together, same as it does on
    /// real film — this is deliberately one control, not two.
    public var pullPush: Double
    /// -2...2 (stops). Separate from density: how long the paper was
    /// exposed under the enlarger, applied last as a straightforward
    /// brightness shift.
    public var exposure: Double

    public init(
        colorFilter: ColorFilter = .none,
        filmSize: FilmSize = .mm35,
        density: Double = 0,
        pullPush: Double = 0,
        exposure: Double = 0
    ) {
        self.colorFilter = colorFilter
        self.filmSize = filmSize
        self.density = density
        self.pullPush = pullPush
        self.exposure = exposure
    }

    public static let identity = DarkroomBWSettings()
}

public enum DarkroomBWProcessor {
    private static let context = CIContext()

    public static func apply(_ settings: DarkroomBWSettings, to image: UIImage) -> UIImage {
        guard let cgImage = image.cgImage else { return image }
        let ciImage = CIImage(cgImage: cgImage)
        let extent = ciImage.extent

        // Channel-mixer conversion to gray using the filter's weights —
        // every output channel gets the same weighted sum, which is what
        // makes the result neutral gray rather than tinted.
        let w = settings.colorFilter.weights
        guard let mixer = CIFilter(name: "CIColorMatrix") else { return image }
        mixer.setValue(ciImage, forKey: kCIInputImageKey)
        let rowVector = CIVector(x: w.r, y: w.g, z: w.b, w: 0)
        mixer.setValue(rowVector, forKey: "inputRVector")
        mixer.setValue(rowVector, forKey: "inputGVector")
        mixer.setValue(rowVector, forKey: "inputBVector")
        mixer.setValue(CIVector(x: 0, y: 0, z: 0, w: 1), forKey: "inputAVector")
        guard var working = mixer.outputImage else { return image }

        // Density (base tone) and exposure (print exposure) are both EV-style
        // multiplicative shifts, kept as separate stages since they're
        // conceptually different controls even though the math is similar.
        let evShift = settings.density + settings.exposure
        if evShift != 0, let exposureFilter = CIFilter(name: "CIExposureAdjust") {
            exposureFilter.setValue(working, forKey: kCIInputImageKey)
            exposureFilter.setValue(Float(evShift), forKey: kCIInputEVKey)
            working = exposureFilter.outputImage ?? working
        }

        // Push/pull's contrast half of the coupling.
        let contrastAmount = 1.0 + settings.pullPush * 0.28
        if let contrastFilter = CIFilter(name: "CIColorControls") {
            contrastFilter.setValue(working, forKey: kCIInputImageKey)
            contrastFilter.setValue(Float(contrastAmount), forKey: kCIInputContrastKey)
            working = contrastFilter.outputImage ?? working
        }

        // Push/pull's grain half of the coupling, scaled by film size.
        if let grained = applyGrain(to: working, extent: extent, settings: settings) {
            working = grained
        }

        guard let outputCG = context.createCGImage(working, from: extent) else { return image }
        return UIImage(cgImage: outputCG, scale: image.scale, orientation: .up)
    }

    /// Generates per-pixel grain, shapes its clump size with a blur scaled to
    /// `filmSize`, then renormalizes variance back up before applying it —
    /// blurring for shape also crushes amplitude, so renormalizing after is
    /// what keeps grain visible instead of blurring it away to nothing.
    private static func applyGrain(to image: CIImage, extent: CGRect, settings: DarkroomBWSettings) -> CIImage? {
        guard let noiseGenerator = CIFilter(name: "CIRandomGenerator"),
              var noise = noiseGenerator.outputImage else { return nil }
        noise = noise.cropped(to: extent)

        // Take one channel of the random generator's RGB noise as our
        // monochrome grain source.
        guard let toGray = CIFilter(name: "CIColorMatrix") else { return nil }
        toGray.setValue(noise, forKey: kCIInputImageKey)
        let grayRow = CIVector(x: 1, y: 0, z: 0, w: 0)
        toGray.setValue(grayRow, forKey: "inputRVector")
        toGray.setValue(grayRow, forKey: "inputGVector")
        toGray.setValue(grayRow, forKey: "inputBVector")
        toGray.setValue(CIVector(x: 0, y: 0, z: 0, w: 1), forKey: "inputAVector")
        guard var grain = toGray.outputImage else { return nil }

        let shortSide = min(extent.width, extent.height)
        let blurRadius = max(0.5, settings.filmSize.grainClumpFactor * (shortSide / 1500))
        if let blur = CIFilter(name: "CIGaussianBlur") {
            blur.setValue(grain, forKey: kCIInputImageKey)
            blur.setValue(blurRadius, forKey: kCIInputRadiusKey)
            grain = (blur.outputImage ?? grain).cropped(to: extent)
        }

        // Blurring lowered the noise's contrast a lot; boost it back up so
        // clump *shape* came from the blur but visible *strength* comes
        // from grainStrength below, not whatever the blur left behind.
        if let renormalize = CIFilter(name: "CIColorControls") {
            renormalize.setValue(grain, forKey: kCIInputImageKey)
            renormalize.setValue(Float(4.0), forKey: kCIInputContrastKey)
            grain = renormalize.outputImage ?? grain
        }

        let pushBoost = 1.0 + max(settings.pullPush, 0) * 0.9
        let pullReduction = 1.0 - max(-settings.pullPush, 0) * 0.4
        let grainStrength = 0.05 * pushBoost * pullReduction

        // Recenter grain to a signed -strength/2...+strength/2 offset and
        // add it directly to the image — this is the same additive
        // technique validated in the Python prototype this was ported from
        // (gray + noise * strength), just without that prototype's
        // per-pixel luminance masking (more grain in shadows/mids, less in
        // highlights). That modulation needs per-pixel masking a custom
        // CIKernel would do cleanly; left as a follow-up rather than
        // approximated blind here with stock filters. Until then, grain
        // strength is uniform across the tone range, which will look wrong
        // in strong highlights (blown sky, etc.) even though it matched
        // the tested photo fine.
        guard let recenter = CIFilter(name: "CIColorMatrix") else { return image }
        recenter.setValue(grain, forKey: kCIInputImageKey)
        let scaledRow = CIVector(x: CGFloat(grainStrength), y: 0, z: 0, w: 0)
        recenter.setValue(scaledRow, forKey: "inputRVector")
        recenter.setValue(scaledRow, forKey: "inputGVector")
        recenter.setValue(scaledRow, forKey: "inputBVector")
        recenter.setValue(CIVector(x: 0, y: 0, z: 0, w: 1), forKey: "inputAVector")
        let halfStrength = CGFloat(grainStrength) * 0.5
        recenter.setValue(CIVector(x: -halfStrength, y: -halfStrength, z: -halfStrength, w: 0), forKey: "inputBiasVector")
        guard let signedGrain = recenter.outputImage else { return image }

        guard let add = CIFilter(name: "CIAdditionCompositing") else { return image }
        add.setValue(signedGrain, forKey: kCIInputImageKey)
        add.setValue(image, forKey: kCIInputBackgroundImageKey)
        return (add.outputImage ?? image).cropped(to: extent)
    }
}
