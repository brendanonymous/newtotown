import AVFoundation
import NewToTownCore
import PhotosUI
import SwiftUI

struct PhotoSubmissionView: View {
    @State private var model: PhotoSubmissionModel
    private let onPhotosSaved: @MainActor ([Data]) async -> Void
    @State private var selection: PhotosPickerItem?
    @State private var isPreparingImage = false
    @State private var showsPhotoPicker = false
    @State private var showsCamera = false
    @State private var cropSelection: PhotoCropSelection?
    @State private var replacementIndex: Int?
    @State private var previewIndex = 0
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    init(service: any PhotoService, onPhotosSaved: @escaping @MainActor ([Data]) async -> Void = { _ in }) {
        _model = State(initialValue: PhotoSubmissionModel(service: service))
        self.onPhotosSaved = onPhotosSaved
    }

    private var isBusy: Bool { model.isBusy || isPreparingImage }
    private var reviewRequired: Bool { model.requirements?.reviewRequired ?? true }

    var body: some View {
        EditorSheet(isBusy: isBusy, hasUnsavedChanges: model.hasUnsavedChanges) {
            ScrollView {
                VStack(spacing: 24) {
                    Text("Show up as yourself.").font(.system(.largeTitle, design: .serif))
                    Text(
                        "Add your photos below. Tap a photo to replace it."
                    ).foregroundStyle(BrandTheme.secondaryInk)

                    if reviewRequired && model.isLoaded {
                        Text(
                            "Add your photos and take a private selfie for photo review. Your selfie never appears on your profile."
                        ).foregroundStyle(BrandTheme.secondaryInk)
                    }

                    if model.isLoaded {
                        profilePhotos
                        if reviewRequired { selfieControls }
                        saveControls
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
                .padding(28).frame(maxWidth: 520).frame(maxWidth: .infinity)
            }
            .foregroundStyle(BrandTheme.ink).background(BrandTheme.background)
            .navigationTitle("").navigationBarTitleDisplayMode(.inline)
            .toolbar { BrandNavigationLogo() }
            .task { await model.load() }
            .photosPicker(isPresented: $showsPhotoPicker, selection: $selection, matching: .images)
            .onChange(of: selection) { _, item in Task { await prepareProfile(item) } }
            .sheet(item: $cropSelection) { selection in
                PhotoCropEditor(selection: selection) { data in
                    if let replacementIndex {
                        model.replaceProfile(at: replacementIndex, with: data)
                    } else {
                        model.addProfile(data)
                    }
                }
            }
            .fullScreenCover(isPresented: $showsCamera) {
                SelfieCamera { image in
                    do { model.captureSelfie(try PhotoImageEncoder.jpeg(from: image)) } catch {
                        model.showImageError(error.localizedDescription)
                    }
                }.ignoresSafeArea()
            }
        }
        .tint(BrandTheme.ink)
    }

    @ViewBuilder private var profilePhotos: some View {
        let photos = model.photos.profilePhotos
        if !photos.isEmpty {
            ProfilePhotoGallery(
                count: photos.count,
                selection: $previewIndex,
                onReplace: { choosePhoto(replacing: $0) },
                onRemove: { index in
                    if photos.count == 1 && model.hasStoredPhotos {
                        Task { await removePhotos() }
                    } else {
                        model.removeProfile(at: index)
                        previewIndex = 0
                    }
                }
            ) { index in
                if let image = UIImage(data: photos[index]) {
                    Image(uiImage: image).resizable().scaledToFill()
                }
            }
            .disabled(isBusy)
        }

        if photos.count < PrivatePhotos.maximumProfilePhotos {
            Button {
                choosePhoto(replacing: nil)
            } label: {
                Label(photos.isEmpty ? "Upload" : "Add a photo", systemImage: "photo.on.rectangle")
            }
            .buttonStyle(BrandActionButtonStyle(tone: .secondary))
            .disabled(isBusy).accessibilityIdentifier("photos.choose")
        }
    }

    private var selfieControls: some View {
        VStack(spacing: 16) {
            if let data = model.photos.selfie, let image = UIImage(data: data) {
                Text("Private selfie").font(.headline)
                Image(uiImage: image).resizable().scaledToFit().brandPhotoStyle().frame(maxHeight: 220)
            }
            Button("Take selfie", systemImage: "camera") { Task { await startCamera() } }
                .buttonStyle(BrandActionButtonStyle(tone: .secondary)).disabled(isBusy)
            Text("Face the camera in good light. Your selfie won’t appear on your profile.")
                .font(.footnote).foregroundStyle(BrandTheme.secondaryInk)
        }
    }

    @ViewBuilder private var saveControls: some View {
        if model.canSave || (model.isBusy && model.photos.profile != nil && !model.isSaved) {
            Button {
                Task {
                    await model.save()
                    if model.isSaved && model.errorMessage == nil {
                        await onPhotosSaved(model.photos.profilePhotos)
                        dismiss()
                    }
                }
            } label: {
                Text("Save photos")
            }
            .buttonStyle(BrandActionButtonStyle())
            .disabled(!model.canSave || isPreparingImage).accessibilityIdentifier("photos.save")
        }
        if model.hasStoredPhotos && model.photos.profilePhotos.isEmpty {
            Button("Remove my photos", role: .destructive) { Task { await removePhotos() } }
                .disabled(isBusy).accessibilityIdentifier("photos.remove")
        }
    }

    @MainActor private func removePhotos() async {
        await model.remove()
        if !model.hasStoredPhotos && model.errorMessage == nil {
            await onPhotosSaved([])
        }
    }

    private func choosePhoto(replacing index: Int?) {
        guard !isBusy else { return }
        replacementIndex = index
        showsPhotoPicker = true
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
            let pixels = try await Task.detached(priority: .userInitiated) {
                try ProfileImageDecoder.decode(data, pixels: 1200)
            }.value
            guard !Task.isCancelled else { return }
            cropSelection = PhotoCropSelection(image: UIImage(cgImage: pixels.cgImage))
        } catch {
            model.showImageError("We couldn’t prepare that photo. Choose a different image and try again.")
        }
    }

    @MainActor private func startCamera() async {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            model.showImageError("A camera is required. Try this step on your iPhone.")
            return
        }
        if await AVCaptureDevice.requestAccess(for: .video) {
            showsCamera = true
        } else {
            model.showImageError("Allow camera access in Settings to take your selfie.")
        }
    }
}
