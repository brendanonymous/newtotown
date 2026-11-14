import SwiftUI

/// A modal entry point. Pushed sections reuse this stack through EditorPage.
struct EditorSheet<Content: View>: View {
    var isBusy = false
    var hasUnsavedChanges = false
    var closeIdentifier = "editor.close"
    @ViewBuilder var content: () -> Content

    var body: some View {
        NavigationStack {
            content()
                .modifier(
                    EditorExitGuard(
                        action: .close, isBusy: isBusy, hasUnsavedChanges: hasUnsavedChanges,
                        identifier: closeIdentifier))
        }
        .tint(BrandTheme.ink)
    }
}
