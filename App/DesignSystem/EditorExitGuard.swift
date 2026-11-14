import SwiftUI

/// Back pops a pushed editor; Close dismisses a sheet. Both protect pending work.
struct EditorExitGuard: ViewModifier {
    enum Action { case back, close }
    let action: Action
    let isBusy: Bool
    let hasUnsavedChanges: Bool
    let identifier: String
    @Environment(\.dismiss) private var dismiss
    @State private var confirmsDiscard = false

    func body(content: Content) -> some View {
        content
            .navigationBarBackButtonHidden(action == .back)
            .toolbar {
                ToolbarItem(placement: action == .back ? .topBarLeading : .cancellationAction) {
                    Button {
                        if hasUnsavedChanges { confirmsDiscard = true } else { dismiss() }
                    } label: {
                        if action == .back {
                            Label("Back", systemImage: "chevron.left").labelStyle(.titleAndIcon)
                        } else {
                            Text("Close")
                        }
                    }
                    .disabled(isBusy)
                    .accessibilityIdentifier(identifier)
                }
            }
            .interactiveDismissDisabled(isBusy || hasUnsavedChanges)
            .background {
                if isBusy || hasUnsavedChanges {
                    SheetDismissalObserver {
                        if !isBusy { confirmsDiscard = true }
                    }
                    .frame(width: 0, height: 0)
                }
            }
            .alert("Leave without saving?", isPresented: $confirmsDiscard) {
                Button("Keep editing", role: .cancel) {}
                Button("Discard changes", role: .destructive) { dismiss() }
            } message: {
                Text("Your changes won’t be saved.")
            }
            .tint(BrandTheme.ink)
    }
}
