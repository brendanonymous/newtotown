import NewToTownCore
import SwiftUI

/// The editor stays in one sheet; its sections use the sheet's navigation stack.
struct ProfileEditorMenuView: View {
    @Bindable var account: OnboardingModel
    let photoService: (any PhotoService)?
    let interestsService: (any InterestsService)?
    let onPhotosSaved: @MainActor ([Data]) async -> Void
    private enum Section: String, Hashable {
        case photos, aboutMe, interests
    }

    var body: some View {
        EditorSheet(isBusy: account.isBusy, closeIdentifier: "profile.editor.close") {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Edit Profile").font(.system(.largeTitle, design: .serif))
                    VStack(spacing: 0) {
                        if photoService != nil {
                            row("Photos", symbol: "photo.on.rectangle", section: .photos)
                            Divider()
                        }
                        row("About Me", symbol: "person.text.rectangle", section: .aboutMe)
                        if interestsService != nil {
                            Divider()
                            row("Interests", symbol: "list.bullet", section: .interests)
                        }
                    }
                }
                .padding(28).frame(maxWidth: 520).frame(maxWidth: .infinity)
            }
            .foregroundStyle(BrandTheme.ink).background(BrandTheme.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { BrandNavigationLogo() }
            .navigationDestination(for: Section.self) { destination($0) }
        }
    }

    @ViewBuilder private func destination(_ section: Section) -> some View {
        switch section {
        case .photos:
            if let photoService {
                PhotoSubmissionView(
                    service: photoService, presentation: .navigation, onPhotosSaved: onPhotosSaved)
            }
        case .aboutMe:
            ProfileEditorView(account: account)
        case .interests:
            if let interestsService {
                InterestEditorView(service: interestsService, kind: .profile, presentation: .navigation) {}
            }
        }
    }

    private func row(_ title: String, symbol: String, section: Section) -> some View {
        NavigationLink(value: section) {
            HStack(spacing: 16) {
                Label(title, systemImage: symbol)
                Spacer()
                Image(systemName: "chevron.right").font(.caption)
                    .foregroundStyle(BrandTheme.secondaryInk)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .padding(.vertical, 12).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityIdentifier("profile.editor.\(section.rawValue)")
    }
}
