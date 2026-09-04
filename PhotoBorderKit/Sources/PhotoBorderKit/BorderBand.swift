import Foundation

/// One concentric ring of a procedural border, e.g. the black rebate of a
/// negative carrier, or the white mat around it.
public struct BorderBand: Identifiable, Codable, Hashable {
    public var id: String
    /// Width of this band, as a fraction of the photo window's short side.
    public var widthFraction: Double
    /// Hex color, e.g. "#FFFFFF".
    public var colorHex: String
    /// If true, the inner edge of this band is drawn as a jittered, hand-torn
    /// line instead of a clean straight edge.
    public var irregularEdge: Bool

    public init(id: String, widthFraction: Double, colorHex: String, irregularEdge: Bool = false) {
        self.id = id
        self.widthFraction = widthFraction
        self.colorHex = colorHex
        self.irregularEdge = irregularEdge
    }
}
