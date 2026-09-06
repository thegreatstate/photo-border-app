import CoreImage
import UIKit

/// Basic tone edits, applied to the source photo before it's cropped/reflowed
/// and framed.
public struct PhotoAdjustments: Codable, Hashable {
    /// -1...1, 0 = unchanged.
    public var brightness: Double
    /// 0...4, 1 = unchanged.
    public var contrast: Double
    /// 0...2, 1 = unchanged, 0 = fully desaturated.
    public var saturation: Double
    public var isMonochrome: Bool

    public init(brightness: Double = 0, contrast: Double = 1, saturation: Double = 1, isMonochrome: Bool = false) {
        self.brightness = brightness
        self.contrast = contrast
        self.saturation = saturation
        self.isMonochrome = isMonochrome
    }

    public static let identity = PhotoAdjustments()
}

public enum PhotoAdjuster {
    private static let context = CIContext()

    public static func apply(_ adjustments: PhotoAdjustments, to image: UIImage) -> UIImage {
        guard adjustments != .identity, let ciImage = CIImage(image: image) else { return image }

        guard let filter = CIFilter(name: "CIColorControls") else { return image }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(adjustments.brightness, forKey: kCIInputBrightnessKey)
        filter.setValue(adjustments.contrast, forKey: kCIInputContrastKey)
        filter.setValue(adjustments.isMonochrome ? 0 : adjustments.saturation, forKey: kCIInputSaturationKey)

        guard let output = filter.outputImage,
              let cgImage = context.createCGImage(output, from: ciImage.extent) else { return image }
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }
}
