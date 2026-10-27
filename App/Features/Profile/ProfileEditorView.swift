import NewToTownCore
import SwiftUI

/// Keep unsaved fields local so closing the sheet leaves the saved profile intact.
struct ProfileEditorView: View {
    @Bindable var account: OnboardingModel
    @State private var draft: ProfileDraft
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    init(account: OnboardingModel) {
        self.account = account
        _draft = State(initialValue: account.draft)
    }

    var body: some View {
        EditorSheet(isBusy: account.isBusy) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Edit profile").font(.system(.largeTitle, design: .serif))
                    ProfileForm(draft: $draft)
                    Button("Save profile") { Task { await save() } }
                        .buttonStyle(BrandActionButtonStyle()).tint(BrandTheme.ink)
                        .foregroundStyle(BrandTheme.background)
                        .accessibilityIdentifier("profile.save")
                    if account.isBusy { ProgressView() }
                    if let errorMessage {
                        Text(errorMessage).font(.callout).foregroundStyle(.red)
                            .accessibilityIdentifier("profile.edit.error")
                    }
                }
                .disabled(account.isBusy)
                .padding(28).frame(maxWidth: 520).frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .foregroundStyle(BrandTheme.ink).background(BrandTheme.background)
            .navigationTitle("").navigationBarTitleDisplayMode(.inline)
            .toolbar { BrandNavigationLogo() }
        }
    }

    @MainActor private func save() async {
        errorMessage = nil
        do {
            try await account.updateProfile(draft)
            dismiss()
        } catch let error as ProfileValidationError {
            errorMessage = error.localizedDescription
        } catch is CancellationError {
            errorMessage = "The save was interrupted. Please try again."
        } catch {
            errorMessage = "Your profile wasn’t saved. Check your connection and try again."
        }
    }
}
