import Photos
import PhotosUI
import PhotoBorderKit
import SwiftUI
import UIKit

/// Runs inside Photos' own Edit UI (same slot as Markup/Filters). Editing
/// extensions are non-destructive by design: Photos always keeps the
/// original untouched and offers "Revert to Original" for free — we don't
/// need to do anything extra to satisfy that.
class PhotoEditingViewController: UIViewController, PHContentEditingController {

    private var input: PHContentEditingInput?
    private var sourceImage: UIImage?
    private var selectedTemplateID: String = BorderTemplateCatalog.polaroid.id
    private var hostingController: UIHostingController<EditingView>?

    private static let formatIdentifier = "com.thegreatstate.photoborder"
    private static let formatVersion = "1.0"

    func canHandle(_ adjustmentData: PHAdjustmentData) -> Bool {
        adjustmentData.formatIdentifier == Self.formatIdentifier
            && adjustmentData.formatVersion == Self.formatVersion
    }

    func startContentEditing(with contentEditingInput: PHContentEditingInput, placeholderImage: UIImage) {
        input = contentEditingInput
        let image = contentEditingInput.displaySizeImage ?? placeholderImage
        sourceImage = image
        embedEditingUI(initialImage: image)
    }

    func finishContentEditing(completionHandler: @escaping (PHContentEditingOutput?) -> Void) {
        guard let input, let sourceImage else {
            completionHandler(nil)
            return
        }
        let templateID = selectedTemplateID

        DispatchQueue.global(qos: .userInitiated).async {
            // fullSizeImageURL points at the original file (JPEG/HEIC in the
            // common case); UIImage's own decoder applies its EXIF
            // orientation, which is all this needs for a straight photo edit.
            let fullImage: UIImage
            if let url = input.fullSizeImageURL, let loaded = UIImage(contentsOfFile: url.path) {
                fullImage = loaded
            } else {
                fullImage = sourceImage
            }

            guard let template = BorderTemplateCatalog.builtIn.first(where: { $0.id == templateID }),
                  let rendered = BorderRenderer.render(image: fullImage, template: template),
                  let jpegData = rendered.jpegData(compressionQuality: 0.95) else {
                DispatchQueue.main.async { completionHandler(nil) }
                return
            }

            let output = PHContentEditingOutput(contentEditingInput: input)
            output.adjustmentData = PHAdjustmentData(
                formatIdentifier: Self.formatIdentifier,
                formatVersion: Self.formatVersion,
                data: Data(templateID.utf8)
            )

            do {
                try jpegData.write(to: output.renderedContentURL, options: .atomic)
                DispatchQueue.main.async { completionHandler(output) }
            } catch {
                DispatchQueue.main.async { completionHandler(nil) }
            }
        }
    }

    var shouldShowCancelConfirmation: Bool { false }

    func cancelContentEditing() {}

    private func embedEditingUI(initialImage: UIImage) {
        let editingView = EditingView(
            sourceImage: initialImage,
            templates: BorderTemplateCatalog.builtIn,
            selectedTemplateID: selectedTemplateID
        ) { [weak self] newID in
            self?.selectedTemplateID = newID
        }
        let hosting = UIHostingController(rootView: editingView)
        addChild(hosting)
        hosting.view.frame = view.bounds
        hosting.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(hosting.view)
        hosting.didMove(toParent: self)
        hostingController = hosting
    }
}
