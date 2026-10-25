import SwiftUI

/// Shared modal navigation for the profile's photo, interest, and detail editors.
struct EditorSheet<Content: View>: View {
    var isBusy = false
    @ViewBuilder var content: () -> Content
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            content()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { dismiss() }
                            .disabled(isBusy)
                            .accessibilityIdentifier("editor.close")
                    }
                }
                .interactiveDismissDisabled(isBusy)
        }
        .tint(BrandTheme.ink)
    }
}
