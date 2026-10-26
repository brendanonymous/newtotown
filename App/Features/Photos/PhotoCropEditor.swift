import NewToTownCore
import SwiftUI
import UIKit

struct PhotoCropSelection: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct PhotoCropEditor: View {
    let selection: PhotoCropSelection
    let onChoose: (Data) -> Void
    @State private var controller = PhotoCropController()
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        EditorSheet {
            ScrollView {
                VStack(spacing: 24) {
                    Text("Pinch to zoom. Drag to position your photo.")
                        .foregroundStyle(BrandTheme.secondaryInk)
                    PhotoCropViewport(image: selection.image, controller: controller)
                        .frame(height: ProfilePhotoLayout.height)
                        .brandPhotoStyle()
                    if let errorMessage {
                        Text(errorMessage).font(.callout).foregroundStyle(.red)
                    }
                }
                .padding(28).frame(maxWidth: 520).frame(maxWidth: .infinity)
            }
            .foregroundStyle(BrandTheme.ink).background(BrandTheme.background)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use photo") {
                        do {
                            onChoose(try controller.jpeg())
                            dismiss()
                        } catch {
                            errorMessage = "We couldn’t crop that photo. Adjust it and try again."
                        }
                    }
                    .accessibilityIdentifier("photos.crop.use")
                }
            }
        }
    }
}
