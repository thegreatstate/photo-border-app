import Foundation

/// A rect in 0...1 unit space, relative to an overlay image's full pixel size.
public struct NormalizedRect: Codable, Hashable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

/// A frame style: either a stack of solid-color `bands` rendered procedurally,
/// or a scanned `overlayAssetName` (e.g. one of your Photoshop-extracted
/// negative-carrier borders) composited on top of the photo. When
/// `overlayAssetName` + `overlayPhotoWindow` are set, they take over rendering
/// entirely and `bands` / `extraBottomFraction` are ignored.
public struct BorderTemplate: Identifiable, Codable, Hashable {
    public var id: String
    public var name: String
    public var aspectRatioID: String
    /// Ordered innermost (touching the photo) to outermost.
    public var bands: [BorderBand]
    /// Extra width added to the bottom edge only, as a fraction of the photo
    /// window's short side. Produces the Polaroid-style deep foot.
    public var extraBottomFraction: Double
    /// Name of a PNG in the app's asset catalog with a transparent window
    /// where the photo shows through.
    public var overlayAssetName: String?
    /// Where that transparent window sits, in unit space relative to the
    /// overlay image's own pixel dimensions.
    public var overlayPhotoWindow: NormalizedRect?

    public init(
        id: String,
        name: String,
        aspectRatioID: String,
        bands: [BorderBand] = [],
        extraBottomFraction: Double = 0,
        overlayAssetName: String? = nil,
        overlayPhotoWindow: NormalizedRect? = nil
    ) {
        self.id = id
        self.name = name
        self.aspectRatioID = aspectRatioID
        self.bands = bands
        self.extraBottomFraction = extraBottomFraction
        self.overlayAssetName = overlayAssetName
        self.overlayPhotoWindow = overlayPhotoWindow
    }
}
