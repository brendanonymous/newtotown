import SwiftUI

/// Shared modal navigation for the profile's photo, interest, and detail editors.
struct EditorSheet<Content: View>: View {
    var isBusy = false
    var hasUnsavedChanges = false
    var closeIdentifier = "editor.close"
    @ViewBuilder var content: () -> Content
    @Environment(\.dismiss) private var dismiss
    @State private var confirmsDiscard = false

    var body: some View {
        NavigationStack {
            content()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { requestClose() }
                            .disabled(isBusy)
                            .accessibilityIdentifier(closeIdentifier)
                    }
                }
                .interactiveDismissDisabled(isBusy || hasUnsavedChanges)
        }
        .background {
            if hasUnsavedChanges {
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

    private func requestClose() {
        if hasUnsavedChanges { confirmsDiscard = true } else { dismiss() }
    }
}
