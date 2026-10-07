import AVFoundation
import NewToTownCore
import PhotosUI
import SwiftUI

struct PhotoSubmissionView: View {
    @State private var model: PhotoSubmissionModel
    @State private var selection: PhotosPickerItem?
    @State private var isPreparingImage = false
    @State private var showsCamera = false
    @State private var confirmsRemoval = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    init(service: any PhotoService) {
        _model = State(initialValue: PhotoSubmissionModel(service: service))
    }

    private var isBusy: Bool { model.isBusy || isPreparingImage }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Show up as yourself.").font(.system(.largeTitle, design: .serif))
                    Text("Choose a profile photo and take a selfie. Both stay private in this build; manual review is coming next.")
                        .foregroundStyle(BrandTheme.secondaryInk)
                    if model.isLoaded {
                        photoPreview("Profile photo", data: model.photos.profile)
                        PhotosPicker(selection: $selection, matching: .images) {
                            Label("Choose profile photo", systemImage: "photo")
                        }
                        .disabled(isBusy)
                        photoPreview("Private selfie", data: model.photos.selfie)
                        Button("Take selfie", systemImage: "camera") { Task { await startCamera() } }
                            .disabled(isBusy)
                        Text("Face the camera in good light. Your selfie won’t appear on your profile.")
                            .font(.footnote).foregroundStyle(BrandTheme.secondaryInk)
                        Toggle("I agree to private storage of these photos to prepare for manual photo review. I can remove them or delete my account at any time.", isOn: $model.hasConsent)
                            .disabled(isBusy)
                        Button("Save photos") { Task { await model.save() } }
                            .buttonStyle(.borderedProminent)
                            .disabled(isBusy)
                        if model.isSaved {
                            Label("Both photos are saved privately.", systemImage: "checkmark.circle")
                        }
                        Button("Remove my photos", role: .destructive) { confirmsRemoval = true }
                            .disabled(isBusy)
                    } else if !model.isBusy {
                        Button("Try loading again") { Task { await model.load() } }
                    }
                    if isBusy { ProgressView("Please wait…") }
                    if let error = model.errorMessage { Text(error).foregroundStyle(.red).font(.callout) }
                    if AVCaptureDevice.authorizationStatus(for: .video) == .denied {
                        Button("Open camera settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                        }
                    }
                }
                .padding(28)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
            .foregroundStyle(BrandTheme.ink)
            .background(BrandTheme.background)
            .navigationTitle("Your photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() }.disabled(isBusy) } }
            .interactiveDismissDisabled(isBusy)
            .task { await model.load() }
            .onChange(of: selection) { _, item in
                Task { await prepareProfile(item) }
            }
            .fullScreenCover(isPresented: $showsCamera) {
                SelfieCamera { image in
                    do { model.captureSelfie(try PhotoImageEncoder.jpeg(from: image)) }
                    catch { model.showImageError(error.localizedDescription) }
                }.ignoresSafeArea()
            }
            .alert("Remove both photos?", isPresented: $confirmsRemoval) {
                Button("Cancel", role: .cancel) {}
                Button("Remove photos", role: .destructive) { Task { await model.remove() } }
            } message: { Text("This removes the uploaded profile photo and selfie. You can add new ones later.") }
        }
        .tint(BrandTheme.ink)
    }

    private func photoPreview(_ title: String, data: Data?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            if let data, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
            } else {
                Label("No photo yet", systemImage: "person.crop.rectangle")
                    .foregroundStyle(BrandTheme.secondaryInk)
            }
        }
    }

    @MainActor private func prepareProfile(_ item: PhotosPickerItem?) async {
        guard let item, !isPreparingImage else { return }
        isPreparingImage = true
        defer { isPreparingImage = false; selection = nil }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { throw PhotoValidationError.invalidImage }
            model.selectProfile(try PhotoImageEncoder.jpeg(from: data))
        } catch { model.showImageError("We couldn’t prepare that photo. Choose a different image and try again.") }
    }

    @MainActor private func startCamera() async {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            model.showImageError("A camera is required. Try this step on your iPhone.")
            return
        }
        let allowed = await AVCaptureDevice.requestAccess(for: .video)
        if allowed { showsCamera = true }
        else { model.showImageError("Allow camera access in Settings to take your selfie.") }
    }
}
