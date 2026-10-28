import SwiftUI

enum EditorPresentation { case sheet, navigation }

/// The same editor can open as a standalone sheet or push onto an existing stack.
struct EditorPage<Content: View>: View {
    var presentation: EditorPresentation = .sheet
    var isBusy = false
    var hasUnsavedChanges = false
    @ViewBuilder var content: () -> Content

    @ViewBuilder var body: some View {
        switch presentation {
        case .sheet:
            EditorSheet(isBusy: isBusy, hasUnsavedChanges: hasUnsavedChanges, content: content)
        case .navigation:
            content()
                .modifier(
                    EditorExitGuard(
                        action: .back, isBusy: isBusy, hasUnsavedChanges: hasUnsavedChanges,
                        identifier: "editor.back")
                )
                .toolbar(.hidden, for: .tabBar)
        }
    }
}
