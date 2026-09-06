import Foundation

/// How a source photo gets reshaped to fit a photo window whose aspect
/// ratio doesn't match the source's own.
public enum PhotoFitMode: Hashable {
    /// The traditional approach: crop away whatever doesn't fit. Nothing in
    /// the kept area is distorted, but content outside the crop is lost.
    case crop

    /// Keeps a `cornerFraction`-sized margin at each edge pixel-for-pixel,
    /// and stretches only the strip between them to absorb the aspect-ratio
    /// change — like a 9-slice/nine-patch image. Nothing is cropped away,
    /// but whatever falls in the stretched middle band gets distorted, so
    /// this suits photos with plain sky/ground/background through the
    /// center more than a portrait with a face dead-center.
    case reflow(cornerFraction: Double)
}
