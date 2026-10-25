#if DEBUG
    import SwiftUI
    import UIKit

    /// Exercises native zoom/pan and JPEG export without depending on the system library.
    struct PhotoCropJourneyFixture: View {
        @State private var showsCrop = false
        @State private var result: UIImage?
        private var selection: PhotoCropSelection {
            let image = UIGraphicsImageRenderer(size: CGSize(width: 800, height: 1200)).image { context in
                UIColor.systemGreen.setFill()
                context.fill(CGRect(x: 0, y: 0, width: 800, height: 600))
                UIColor.systemBlue.setFill()
                context.fill(CGRect(x: 0, y: 600, width: 800, height: 600))
            }
            return PhotoCropSelection(image: image)
        }
        var body: some View {
            NavigationStack {
                VStack(spacing: 24) {
                    Button("Crop fixture photo") { showsCrop = true }
                    if let result {
                        Text("Photo ready").accessibilityIdentifier("crop.ready")
                        Text("\(Int(result.size.width)) × \(Int(result.size.height))")
                            .accessibilityIdentifier("crop.dimensions")
                        ProfilePhotoFrame { Image(uiImage: result).resizable().scaledToFill() }
                    }
                }
                .padding(28).frame(maxWidth: 520)
                .sheet(isPresented: $showsCrop) {
                    PhotoCropEditor(selection: selection) { result = UIImage(data: $0) }
                }
            }
        }
    }
#endif
