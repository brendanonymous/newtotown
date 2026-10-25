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

    private var reviewRequired: Bool { model.requirements?.reviewRequired ?? true }

    var body: some View {
        EditorSheet(isBusy: isBusy) {
            ScrollView {
                VStack(alignment: .center, spacing: 24) {
                    Text("Show up as yourself.").font(.system(.largeTitle, design: .serif))
                    if model.requirements?.reviewRequired == true {
                        Text(
                            "Choose a profile photo and take a private selfie for photo review. Only your profile photo is shared when you join discovery."
                        )
                        .foregroundStyle(BrandTheme.secondaryInk)
                    }
                    if model.isLoaded {
                        if let data = model.photos.profile {
                            photoPreview(nil, data: data)
                        }
                        PhotosPicker(selection: $selection, matching: .images) {
                            Label("Choose your photo", systemImage: "photo.on.rectangle")
                        }
                        .frame(maxWidth: .infinity)
                        .disabled(isBusy)
                        .accessibilityIdentifier("photos.choose")

                        if reviewRequired {
                            photoPreview("Private selfie", data: model.photos.selfie)
                            Button("Take selfie", systemImage: "camera") { Task { await startCamera() } }
                                .frame(maxWidth: .infinity)
                                .disabled(isBusy)
                            Text("Face the camera in good light. Your selfie won’t appear on your profile.")
                                .font(.footnote).foregroundStyle(BrandTheme.secondaryInk)
                        }

                        if model.canSave || (model.isBusy && model.photos.profile != nil && !model.isSaved) {
                            Button("Save photo") {
                                Task {
                                    await model.save()
                                    if model.isSaved && model.errorMessage == nil { dismiss() }
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .foregroundStyle(BrandTheme.background)
                            .frame(maxWidth: .infinity)
                            .disabled(!model.canSave || isPreparingImage)
                            .accessibilityIdentifier("photos.save")
                        }
                        if model.hasStoredPhotos {
                            Button("Remove my photos", role: .destructive) { confirmsRemoval = true }
                                .frame(maxWidth: .infinity)
                                .disabled(isBusy)
                                .accessibilityIdentifier("photos.remove")
                        }
                    } else if !model.isBusy {
                        Button("Try loading again") { Task { await model.load() } }
                    }

                    if isBusy { ProgressView() }
                    if let error = model.errorMessage { Text(error).foregroundStyle(.red).font(.callout) }
                    if reviewRequired && AVCaptureDevice.authorizationStatus(for: .video) == .denied {
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
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                BrandNavigationLogo()
            }
            .task { await model.load() }
            .onChange(of: selection) { _, item in
                Task { await prepareProfile(item) }
            }
            .fullScreenCover(isPresented: $showsCamera) {
                SelfieCamera { image in
                    do { model.captureSelfie(try PhotoImageEncoder.jpeg(from: image)) } catch {
                        model.showImageError(error.localizedDescription)
                    }
                }.ignoresSafeArea()
            }
            .alert("Remove your photos?", isPresented: $confirmsRemoval) {
                Button("Cancel", role: .cancel) {}
                Button("Remove photos", role: .destructive) { Task { await model.remove() } }
            } message: {
                Text(
                    "This removes your profile photo and any previously uploaded selfie. You can add photos again later."
                )
            }
        }
        .tint(BrandTheme.ink)
    }

    private func photoPreview(_ title: String?, data: Data?) -> some View {
        VStack(spacing: 8) {
            if let title { Text(title).font(.headline) }
            if let data, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .brandPhotoStyle()
                    .frame(maxHeight: 220)
            } else {
                Label("No photo yet", systemImage: "person.crop.rectangle")
                    .foregroundStyle(BrandTheme.secondaryInk)
            }
        }
        .frame(maxWidth: .infinity)
    }

    @MainActor private func prepareProfile(_ item: PhotosPickerItem?) async {
        guard let item, !isPreparingImage else { return }
        isPreparingImage = true
        defer {
            isPreparingImage = false
            selection = nil
        }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw PhotoValidationError.invalidImage
            }
            model.selectProfile(try PhotoImageEncoder.jpeg(from: data))
        } catch {
            model.showImageError("We couldn’t prepare that photo. Choose a different image and try again.")
        }
    }

    @MainActor private func startCamera() async {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            model.showImageError("A camera is required. Try this step on your iPhone.")
            return
        }
        let allowed = await AVCaptureDevice.requestAccess(for: .video)
        if allowed {
            showsCamera = true
        } else {
            model.showImageError("Allow camera access in Settings to take your selfie.")
        }
    }
}
