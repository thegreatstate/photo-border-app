import Foundation

/// A photo-window shape, independent of orientation. The renderer decides
/// portrait vs. landscape from the source image and applies `longToShort`
/// to whichever side is longer.
public struct AspectRatio: Identifiable, Hashable, Codable {
    public var id: String
    public var name: String
    /// Ratio of the long side to the short side of the photo window (>= 1.0).
    public var longToShort: Double

    public init(id: String, name: String, longToShort: Double) {
        self.id = id
        self.name = name
        self.longToShort = longToShort
    }

    public static let square = AspectRatio(id: "square", name: "Square", longToShort: 1.0)
    public static let sixBySix = AspectRatio(id: "6x6", name: "6\u{00d7}6", longToShort: 1.0)
    public static let thirtyFiveMM = AspectRatio(id: "35mm", name: "35mm", longToShort: 3.0 / 2.0)
    public static let fourBySix = AspectRatio(id: "4x6", name: "4\u{00d7}6", longToShort: 6.0 / 4.0)
    public static let fiveBySix = AspectRatio(id: "5x6", name: "5\u{00d7}6", longToShort: 6.0 / 5.0)
    public static let panoramic = AspectRatio(id: "pano", name: "Panoramic", longToShort: 3.0)

    public static let builtIn: [AspectRatio] = [
        .square, .sixBySix, .thirtyFiveMM, .fourBySix, .fiveBySix, .panoramic,
    ]
}
