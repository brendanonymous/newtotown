import NewToTownCore
import SwiftUI

struct InterestEditorView: View {
    @State private var model: InterestsModel
    enum Presentation { case navigation, sheet }
    let presentation: Presentation
    let onSaved: () -> Void
    @Environment(\.dismiss) private var dismiss

    init(
        service: any InterestsService, kind: InterestSelectionKind,
        presentation: Presentation = .navigation, onSaved: @escaping () -> Void
    ) {
        self.presentation = presentation
        _model = State(initialValue: InterestsModel(service: service, kind: kind))
        self.onSaved = onSaved
    }

    @ViewBuilder var body: some View {
        switch presentation {
        case .navigation: editor
        case .sheet: EditorSheet(isBusy: model.isBusy) { editor }
        }
    }

    private var editor: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(model.kind == .profile ? "Your interests" : "Discovery interests")
                    .font(.system(.largeTitle, design: .serif))
                Text(
                    model.kind == .profile
                        ? "Choose up to three in each category. These appear on your profile. Every category is optional."
                        : "Choose up to three in each category. People with any selected interest can appear in Discovery. Leave everything unselected to see everyone."
                )
                .foregroundStyle(BrandTheme.secondaryInk)
                if let snapshot = model.snapshot {
                    ForEach(snapshot.categories) { category in
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(category.title).font(.headline)
                                Spacer()
                                Text("\(model.count(in: category))/3").font(.caption)
                                    .foregroundStyle(BrandTheme.secondaryInk)
                            }
                            LazyVGrid(
                                columns: [GridItem(.adaptive(minimum: 130), alignment: .leading)],
                                alignment: .leading, spacing: 10
                            ) {
                                ForEach(category.options) { option in
                                    Button {
                                        model.toggle(option.id)
                                    } label: {
                                        HStack(alignment: .top, spacing: 8) {
                                            Image(
                                                systemName: model.selected.contains(option.id)
                                                    ? "checkmark.circle.fill" : "circle")
                                            Text(option.title).multilineTextAlignment(.leading)
                                        }
                                        .font(.subheadline).frame(
                                            maxWidth: .infinity, minHeight: 44, alignment: .leading
                                        )
                                        .padding(10)
                                        .background(
                                            BrandTheme.sage.opacity(
                                                model.selected.contains(option.id) ? 0.3 : 0.1),
                                            in: RoundedRectangle(cornerRadius: BrandTheme.textCornerRadius))
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(!model.canToggle(option.id))
                                    .opacity(model.canToggle(option.id) ? 1 : 0.45)
                                    .accessibilityIdentifier("interest.\(option.id)")
                                    .accessibilityValue(
                                        model.selected.contains(option.id) ? "Selected" : "Not selected")
                                }
                            }
                        }
                    }
                }
                if model.isBusy { ProgressView() }
                if let error = model.errorMessage {
                    Text(error).font(.callout).foregroundStyle(.red)
                    if model.snapshot == nil { Button("Try again") { Task { await model.load() } } }
                }
                Button(model.kind == .profile ? "Save interests" : "Save filters") {
                    Task {
                        if await model.save() {
                            onSaved()
                            dismiss()
                        }
                    }
                }
                .buttonStyle(.borderedProminent).tint(BrandTheme.ink)
                .foregroundStyle(BrandTheme.background).disabled(!model.canSave)
                .accessibilityIdentifier("interests.save")
            }
            .padding(28).frame(maxWidth: 520).frame(maxWidth: .infinity)
        }
        .background(BrandTheme.background).foregroundStyle(BrandTheme.ink)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { BrandNavigationLogo() }.toolbar(.hidden, for: .tabBar)
        .task { await model.load() }.onDisappear { model.reset() }
        .privacySensitive()
    }
}
