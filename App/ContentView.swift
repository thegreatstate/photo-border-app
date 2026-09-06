import Photos
import PhotoBorderKit
import SwiftUI

struct ContentView: View {
    @State private var selectedAsset: PHAsset?
    @State private var sourceImage: UIImage?
    @State private var previewImage: UIImage?
    @State private var selectedTemplateID: String = BorderTemplateCatalog.polaroid.id
    @State private var showPicker = false
    @State private var isSaving = false
    @State private var saveMessage: String?

    @State private var adjustments = PhotoAdjustments.identity
    @State private var useReflow = false
    @State private var autoNumber = false
    @AppStorage("photoBorderEditionNumber") private var editionNumber: Int = 1

    @State private var textLayers: [TextLayer] = ContentView.defaultTextLayers

    private let templates = BorderTemplateCatalog.builtIn

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Group {
                        if let previewImage {
                            Image(uiImage: previewImage)
                                .resizable()
                                .scaledToFit()
                        } else {
                            VStack(spacing: 8) {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.system(size: 40))
                                Text("Pick a photo")
                            }
                            .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxHeight: 420)

                    Button(selectedAsset == nil ? "Choose Photo" : "Choose Different Photo") {
                        requestAccessIfNeeded { showPicker = true }
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(templates) { template in
                                templateChip(template)
                            }
                        }
                        .padding(.horizontal)
                    }

                    DisclosureGroup("Fit") {
                        FitModeToggle(useReflow: $useReflow)
                            .onChange(of: useReflow) { _ in renderPreview() }
                    }
                    .padding(.horizontal)

                    DisclosureGroup("Adjust") {
                        AdjustmentsControls(adjustments: $adjustments)
                            .onChange(of: adjustments) { _ in renderPreview() }
                    }
                    .padding(.horizontal)

                    DisclosureGroup("Caption") {
                        VStack(spacing: 12) {
                            ForEach($textLayers) { $layer in
                                TextLayerRow(layer: $layer)
                                    .onChange(of: layer.text) { _ in renderPreview() }
                                    .onChange(of: layer.fontName) { _ in renderPreview() }
                            }
                            Toggle("Auto-number (increments after each save)", isOn: $autoNumber)
                                .font(.caption)
                                .onChange(of: autoNumber) { _ in applyAutoNumberIfNeeded(); renderPreview() }
                        }
                    }
                    .padding(.horizontal)

                    if let saveMessage {
                        Text(saveMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        saveAsNewAsset()
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Label("Save As New Photo", systemImage: "square.and.arrow.down")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(previewImage == nil || isSaving)
                }
                .padding()
            }
            .navigationTitle("Border")
            .sheet(isPresented: $showPicker) {
                PhotoPicker { asset in
                    selectedAsset = asset
                    saveMessage = nil
                    loadFullImage(for: asset)
                }
            }
        }
    }

    private static let defaultTextLayers: [TextLayer] = [
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

    private func templateChip(_ template: BorderTemplate) -> some View {
        Button {
            selectedTemplateID = template.id
            renderPreview()
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

    private func requestAccessIfNeeded(_ completion: @escaping () -> Void) {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .authorized || status == .limited {
            completion()
            return
        }
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
            DispatchQueue.main.async {
                if newStatus == .authorized || newStatus == .limited {
                    completion()
                }
            }
        }
    }

    private func loadFullImage(for asset: PHAsset) {
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        manager.requestImage(
            for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .aspectFit, options: options
        ) { image, _ in
            DispatchQueue.main.async {
                self.sourceImage = image
                self.applyAutoNumberIfNeeded()
                self.renderPreview()
            }
        }
    }

    private func applyAutoNumberIfNeeded() {
        guard autoNumber, let index = textLayers.firstIndex(where: { $0.kind == .numbering }) else { return }
        textLayers[index].text = "No. \(editionNumber)"
    }

    private func renderPreview() {
        guard let sourceImage,
              let template = templates.first(where: { $0.id == selectedTemplateID }) else { return }
        let adjusted = PhotoAdjuster.apply(adjustments, to: sourceImage)
        let fit: PhotoFitMode = useReflow ? .reflow(cornerFraction: defaultReflowCornerFraction) : .crop
        previewImage = BorderRenderer.render(image: adjusted, template: template, fit: fit, textLayers: textLayers)
    }

    private func saveAsNewAsset() {
        guard let previewImage, let asset = selectedAsset,
              let jpegData = previewImage.jpegData(compressionQuality: 0.95) else { return }
        isSaving = true
        saveMessage = nil
        let originalCreationDate = asset.creationDate
        let originalLocation = asset.location

        PHPhotoLibrary.shared().performChanges({
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .photo, data: jpegData, options: nil)
            request.creationDate = originalCreationDate
            request.location = originalLocation
        }) { success, error in
            DispatchQueue.main.async {
                isSaving = false
                saveMessage = success
                    ? "Saved next to the original, same date."
                    : "Save failed: \(error?.localizedDescription ?? "unknown error")"
                if success, autoNumber {
                    editionNumber += 1
                    applyAutoNumberIfNeeded()
                }
            }
        }
    }
}
