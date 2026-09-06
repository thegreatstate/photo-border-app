import Foundation

/// A point in 0...1 unit space, relative to the full rendered canvas
/// (including the border, not just the photo). (0,0) is top-left.
public struct NormalizedPoint: Codable, Hashable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

/// A caption drawn on top of the finished, bordered photo — a signature,
/// title, or edition number. `kind` is informational (used for default
/// placement/labeling in the UI); the renderer treats every layer the same.
public struct TextLayer: Identifiable, Codable, Hashable {
    public enum Kind: String, Codable {
        case signature, title, numbering, custom
    }

    public enum Alignment: String, Codable {
        case left, center, right
    }

    public var id: String
    public var kind: Kind
    public var text: String
    /// A PostScript font name from `FontChoice`, or "System" for the
    /// default UI font.
    public var fontName: String
    /// Font size as a fraction of the canvas's short side, so text scales
    /// with photo resolution instead of being a fixed point size.
    public var fontSizeFraction: Double
    public var colorHex: String
    /// Anchor position, in unit space relative to the full canvas.
    public var position: NormalizedPoint
    public var alignment: Alignment

    public init(
        id: String,
        kind: Kind,
        text: String,
        fontName: String,
        fontSizeFraction: Double,
        colorHex: String,
        position: NormalizedPoint,
        alignment: Alignment = .center
    ) {
        self.id = id
        self.kind = kind
        self.text = text
        self.fontName = fontName
        self.fontSizeFraction = fontSizeFraction
        self.colorHex = colorHex
        self.position = position
        self.alignment = alignment
    }
}

/// Known-good built-in iOS font choices for the caption styles people
/// actually ask for. `UIFont(name:)` returning nil (a name not present on a
/// given iOS version) falls back to the system font in the renderer rather
/// than crashing — treat these as "usually available," not guaranteed.
public enum FontChoice {
    public static let system = "System"
    public static let signature = "SnellRoundhand-Black"
    public static let handwritten = "Noteworthy-Bold"
    public static let pencil = "MarkerFelt-Wide"
    public static let typewriter = "AmericanTypewriter"

    public static let all: [(label: String, postscriptName: String)] = [
        ("System", system),
        ("Signature", signature),
        ("Handwritten", handwritten),
        ("Pencil", pencil),
        ("Typewriter", typewriter),
    ]
}
