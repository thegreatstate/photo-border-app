import PhotoBorderKit
import SwiftUI

/// The SwiftUI UI hosted inside the Photos Edit Extension: a live preview
/// and a horizontal strip of frame choices.
struct EditingView: View {
    let sourceImage: UIImage
    let templates: [BorderTemplate]
    @State var selectedTemplateID: String
    let onSelect: (String) -> Void

    @State private var previewImage: UIImage?

    var body: some View {
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
                            onSelect(template.id)
                            render()
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
        }
        .onAppear { render() }
    }

    private func render() {
        guard let template = templates.first(where: { $0.id == selectedTemplateID }) else { return }
        previewImage = BorderRenderer.render(image: sourceImage, template: template)
    }
}
