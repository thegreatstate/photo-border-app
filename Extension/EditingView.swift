import PhotoBorderKit
import SwiftUI

/// The SwiftUI UI hosted inside the Photos Edit Extension: a live preview,
/// a horizontal strip of frame choices, and the same fit/adjust/caption
/// controls as the standalone app.
struct EditingView: View {
    let sourceImage: UIImage
    let templates: [BorderTemplate]
    @State var selectedTemplateID: String
    let onChange: (EditingState) -> Void

    @State private var adjustments = PhotoAdjustments.identity
    @State private var useReflow = false
    @State private var textLayers: [TextLayer] = EditingDefaults.textLayers

    @State private var previewImage: UIImage?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let previewImage {
                    Image(uiImage: previewImage)
                        .resizable()
                        .scaledToFit()
                        .padding()
                } else {
                    ProgressView()
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(templates) { template in
                            Button {
                                selectedTemplateID = template.id
                                notifyAndRender()
                            } label: {
                                Text(template.name)
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(selectedTemplateID == template.id ? Color.accentColor : Color.secondary.opacity(0.15))
                                    .foregroundStyle(selectedTemplateID == template.id ? .white : .primary)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                DisclosureGroup("Fit") {
                    FitModeToggle(useReflow: $useReflow)
                        .onChange(of: useReflow) { _ in notifyAndRender() }
                }
                .padding(.horizontal)

                DisclosureGroup("Adjust") {
                    AdjustmentsControls(adjustments: $adjustments)
                        .onChange(of: adjustments) { _ in notifyAndRender() }
                }
                .padding(.horizontal)

                DisclosureGroup("Caption") {
                    VStack(spacing: 12) {
                        ForEach($textLayers) { $layer in
                            TextLayerRow(layer: $layer)
                                .onChange(of: layer.text) { _ in notifyAndRender() }
                                .onChange(of: layer.fontName) { _ in notifyAndRender() }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .onAppear { notifyAndRender() }
    }

    private func notifyAndRender() {
        let fit: PhotoFitMode = useReflow ? .reflow(cornerFraction: defaultReflowCornerFraction) : .crop
        let state = EditingState(templateID: selectedTemplateID, adjustments: adjustments, fit: fit, textLayers: textLayers)
        onChange(state)
        guard let template = templates.first(where: { $0.id == selectedTemplateID }) else { return }
        let adjusted = PhotoAdjuster.apply(adjustments, to: sourceImage)
        previewImage = BorderRenderer.render(image: adjusted, template: template, fit: fit, textLayers: textLayers)
    }
}

/// Everything needed to reproduce the final render, handed back to the
/// hosting `PhotoEditingViewController` on every change so it stays in sync
/// without either side owning a duplicate copy of the state.
struct EditingState {
    var templateID: String
    var adjustments: PhotoAdjustments
    var fit: PhotoFitMode
    var textLayers: [TextLayer]
}

enum EditingDefaults {
    static let textLayers: [TextLayer] = [
        TextLayer(id: "signature", kind: .signature, text: "", fontName: FontChoice.signature,
                  fontSizeFraction: 0.045, colorHex: "#111111",
                  position: NormalizedPoint(x: 0.82, y: 0.95), alignment: .right),
        TextLayer(id: "title", kind: .title, text: "", fontName: FontChoice.typewriter,
                  fontSizeFraction: 0.035, colorHex: "#111111",
                  position: NormalizedPoint(x: 0.5, y: 0.93), alignment: .center),
        TextLayer(id: "numbering", kind: .numbering, text: "", fontName: FontChoice.typewriter,
                  fontSizeFraction: 0.03, colorHex: "#111111",
                  position: NormalizedPoint(x: 0.12, y: 0.95), alignment: .left),
    ]
}
