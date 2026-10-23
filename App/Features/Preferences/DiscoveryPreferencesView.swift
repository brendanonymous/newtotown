import NewToTownCore
import SwiftUI

struct DiscoveryPreferencesView: View {
    @State private var model: DiscoveryPreferencesModel
    let onSaved: () -> Void
    @Environment(\.dismiss) private var dismiss

    init(service: any DiscoveryPreferencesService, onSaved: @escaping () -> Void) {
        _model = State(initialValue: DiscoveryPreferencesModel(service: service))
        self.onSaved = onSaved
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Preferences").font(.system(.largeTitle, design: .serif))
                Text("Age range").font(.headline)
                Text(
                    "Choose who appears in Discovery. Your existing connections and conversations stay available."
                )
                .foregroundStyle(BrandTheme.secondaryInk)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Minimum age").font(.subheadline)
                    TextField("Minimum age", text: $model.minimumAge)
                        .keyboardType(.numberPad).textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("preferences.minimumAge")
                    Text("Maximum age").font(.subheadline)
                    TextField("No upper limit", text: $model.maximumAge)
                        .keyboardType(.numberPad).textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("preferences.maximumAge")
                    Text("Leave maximum age blank for no upper limit.")
                        .font(.caption).foregroundStyle(BrandTheme.secondaryInk)
                }
                .disabled(model.saved == nil || model.isBusy)
                if let validation = model.validationMessage {
                    Text(validation).font(.callout).foregroundStyle(.red)
                }
                if let error = model.errorMessage {
                    Text(error).font(.callout).foregroundStyle(.red)
                        .accessibilityIdentifier("preferences.error")
                    if model.saved == nil {
                        Button("Try again") { Task { await model.load() } }
                            .disabled(model.isBusy)
                    }
                }
                if model.isBusy { ProgressView("Please wait…") }
                Button("Save preferences") {
                    Task {
                        if await model.save() {
                            onSaved()
                            dismiss()
                        }
                    }
                }
                .buttonStyle(.borderedProminent).tint(BrandTheme.ink)
                .foregroundStyle(BrandTheme.background)
                .disabled(!model.canSave).opacity(model.canSave ? 1 : 0.4)
                .accessibilityIdentifier("preferences.save")
            }
            .padding(28).frame(maxWidth: 520).frame(maxWidth: .infinity)
        }
        .background(BrandTheme.background).foregroundStyle(BrandTheme.ink)
        .scrollDismissesKeyboard(.interactively)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { BrandNavigationLogo() }
        .toolbar(.hidden, for: .tabBar)
        .task { await model.load() }
        .onDisappear { model.reset() }
        .privacySensitive()
    }
}
