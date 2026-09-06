import Foundation

/// The full set of frames offered in the app and the extension. Add a new
/// frame by adding an entry here — no UI code needed. See the README for how
/// to point a template at a real scanned border (`overlayAssetName`) instead
/// of the procedural bands below.
public enum BorderTemplateCatalog {
    public static let clean = BorderTemplate(
        id: "clean-white",
        name: "Clean White",
        aspectRatioID: AspectRatio.thirtyFiveMM.id,
        bands: [BorderBand(id: "mat", widthFraction: 0.12, colorHex: "#FFFFFF")]
    )

    public static let keyline = BorderTemplate(
        id: "keyline-mat",
        name: "White / Black Line / White",
        aspectRatioID: AspectRatio.fourBySix.id,
        bands: [
            BorderBand(id: "inner-mat", widthFraction: 0.06, colorHex: "#FFFFFF"),
            BorderBand(id: "line", widthFraction: 0.012, colorHex: "#111111"),
            BorderBand(id: "outer-mat", widthFraction: 0.10, colorHex: "#FFFFFF"),
        ]
    )

    public static let polaroid = BorderTemplate(
        id: "polaroid",
        name: "Polaroid",
        aspectRatioID: AspectRatio.square.id,
        bands: [BorderBand(id: "frame", widthFraction: 0.08, colorHex: "#FAFAF7")],
        extraBottomFraction: 0.35
    )

    /// The black rebate here is a jittered procedural stand-in, but the band
    /// widths (1.8% rebate, 3.5% mat, as a fraction of the short side) are
    /// measured from an actual reference print, not guessed. See
    /// `scannedRebate5x7` below for a real scanned border on the same
    /// aspect-ratio family — swap this one for a real overlay the same way
    /// once you have a 6x6/35mm scan.
    public static let negativeCarrier6x6 = BorderTemplate(
        id: "negative-carrier-6x6",
        name: "6\u{00d7}6 Negative Carrier",
        aspectRatioID: AspectRatio.sixBySix.id,
        bands: [
            BorderBand(id: "rebate", widthFraction: 0.018, colorHex: "#0A0A0A", irregularEdge: true),
            BorderBand(id: "mat", widthFraction: 0.035, colorHex: "#FFFFFF"),
        ]
    )

    /// Same calibration and caveat as `negativeCarrier6x6`.
    public static let negativeCarrier35mm = BorderTemplate(
        id: "negative-carrier-35mm",
        name: "35mm Negative Carrier",
        aspectRatioID: AspectRatio.thirtyFiveMM.id,
        bands: [
            BorderBand(id: "rebate", widthFraction: 0.018, colorHex: "#0A0A0A", irregularEdge: true),
            BorderBand(id: "mat", widthFraction: 0.035, colorHex: "#FFFFFF"),
        ]
    )

    /// A real scanned border: extracted from an actual reference print by
    /// tracing its clean, straight inner edge (this carrier isn't the
    /// hand-torn style the procedural ones approximate — it's a manufactured
    /// rectangle) and cutting out the ring. `overlayPhotoWindow` was measured
    /// directly off that scan.
    public static let scannedRebate5x7 = BorderTemplate(
        id: "scanned-rebate-5x7",
        name: "Scanned Rebate",
        aspectRatioID: AspectRatio.fiveBySeven.id,
        overlayAssetName: "negative-carrier-sample",
        overlayPhotoWindow: NormalizedRect(x: 0.05625, y: 0.0355, width: 0.8875, height: 0.929)
    )

    public static let builtIn: [BorderTemplate] = [
        .polaroid, .scannedRebate5x7, .negativeCarrier6x6, .negativeCarrier35mm, .keyline, .clean,
    ]
}
