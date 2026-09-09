import Foundation

/// One concentric ring of a procedural border, e.g. the black rebate of a
/// negative carrier, or the white mat around it.
public struct BorderBand: Identifiable, Codable, Hashable {
    public var id: String
    /// Width of this band, as a fraction of the photo window's short side.
    public var widthFraction: Double
    /// Hex color, e.g. "#FFFFFF".
    public var colorHex: String
    /// If true, this band's *outer* edge (away from the photo, toward
    /// whatever's drawn beyond it) is jittered instead of a clean straight
    /// line. The inner edge, facing the photo, is never touched by this —
    /// it's the camera's own film gate opening in real life, a precise
    /// mechanical edge that's always clean regardless of how roughly a
    /// carrier was filed out beyond it.
    public var irregularEdge: Bool

    public init(id: String, widthFraction: Double, colorHex: String, irregularEdge: Bool = false) {
        self.id = id
        self.widthFraction = widthFraction
        self.colorHex = colorHex
        self.irregularEdge = irregularEdge
    }
}
