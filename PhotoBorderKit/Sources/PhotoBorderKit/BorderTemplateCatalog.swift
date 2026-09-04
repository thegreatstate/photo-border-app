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

    /// The black rebate here is a jittered procedural stand-in — swap it for
    /// a real scan of your 6x6 negative carrier via `overlayAssetName` once
    /// you've extracted one in Photoshop (see README).
    public static let negativeCarrier6x6 = BorderTemplate(
        id: "negative-carrier-6x6",
        name: "6\u{00d7}6 Negative Carrier",
        aspectRatioID: AspectRatio.sixBySix.id,
        bands: [
            BorderBand(id: "rebate", widthFraction: 0.05, colorHex: "#0A0A0A", irregularEdge: true),
            BorderBand(id: "mat", widthFraction: 0.10, colorHex: "#FFFFFF"),
        ]
    )

    /// Same caveat as `negativeCarrier6x6` — placeholder rebate, swap in a
    /// real scan of your 35mm carrier when you have one.
    public static let negativeCarrier35mm = BorderTemplate(
        id: "negative-carrier-35mm",
        name: "35mm Negative Carrier",
        aspectRatioID: AspectRatio.thirtyFiveMM.id,
        bands: [
            BorderBand(id: "rebate", widthFraction: 0.05, colorHex: "#0A0A0A", irregularEdge: true),
            BorderBand(id: "mat", widthFraction: 0.10, colorHex: "#FFFFFF"),
        ]
    )

    public static let builtIn: [BorderTemplate] = [
        .polaroid, .negativeCarrier6x6, .negativeCarrier35mm, .keyline, .clean,
    ]
}
