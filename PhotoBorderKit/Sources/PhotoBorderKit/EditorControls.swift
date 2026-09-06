import SwiftUI

/// Shared SwiftUI controls used by both the standalone app and the Photos
/// Edit Extension, so the two don't drift out of sync with each other.

public struct AdjustmentsControls: View {
    @Binding var adjustments: PhotoAdjustments

    public init(adjustments: Binding<PhotoAdjustments>) {
        self._adjustments = adjustments
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Black & White", isOn: $adjustments.isMonochrome)
            LabeledSlider(label: "Brightness", value: $adjustments.brightness, range: -0.5...0.5)
            LabeledSlider(label: "Contrast", value: $adjustments.contrast, range: 0.5...2.0)
            if !adjustments.isMonochrome {
                LabeledSlider(label: "Saturation", value: $adjustments.saturation, range: 0...2)
            }
        }
    }
}

private struct LabeledSlider: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Slider(value: $value, in: range)
        }
    }
}

public struct TextLayerRow: View {
    @Binding var layer: TextLayer

    public init(layer: Binding<TextLayer>) {
        self._layer = layer
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField(layer.kind.rawValue.capitalized, text: $layer.text)
                .textFieldStyle(.roundedBorder)
            Picker("Font", selection: $layer.fontName) {
                ForEach(FontChoice.all, id: \.postscriptName) { option in
                    Text(option.label).tag(option.postscriptName)
                }
            }
            .pickerStyle(.menu)
            .font(.caption)
        }
    }
}

public struct FitModeToggle: View {
    @Binding var useReflow: Bool

    public init(useReflow: Binding<Bool>) {
        self._useReflow = useReflow
    }

    public var body: some View {
        Toggle(isOn: $useReflow) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Stretch center to fit")
                Text(useReflow
                    ? "Corners stay unscaled; only the middle stretches to hit the new aspect ratio."
                    : "Off: the photo is center-cropped to fit the frame's aspect ratio.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// The 9-slice corner size used whenever `useReflow` is on, as a fraction of
/// the source photo's short side.
public let defaultReflowCornerFraction: Double = 0.3
