import Photos
import PhotosUI
import SwiftUI

/// Picks a single photo and hands back its `PHAsset` (not just the image
/// data) so the caller can read `creationDate`/`location` and reuse them
/// when saving the bordered version back to the library.
struct PhotoPicker: UIViewControllerRepresentable {
    var onPick: (PHAsset) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.selectionLimit = 1
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onPick: (PHAsset) -> Void
        init(onPick: @escaping (PHAsset) -> Void) { self.onPick = onPick }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let identifier = results.first?.assetIdentifier else { return }
            let fetch = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
            if let asset = fetch.firstObject {
                onPick(asset)
            }
        }
    }
}
