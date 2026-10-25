import NewToTownCore
import SwiftUI

struct ReportProfileView: View {
    let name: String
    let onSubmitted: () -> Void
    @State private var model: ReportProfileModel
    @Environment(\.dismiss) private var dismiss

    init(profile: DiscoveryProfile, service: any ProfileReportingService, onSubmitted: @escaping () -> Void) {
        name = profile.firstName
        self.onSubmitted = onSubmitted
        _model = State(initialValue: ReportProfileModel(targetID: profile.id, service: service))
    }

    var body: some View {
        NavigationStack {
            Form {
                if model.receiptID != nil {
                    Section {
                        Label("Report submitted", systemImage: "checkmark.circle")
                        Text("Your connection has been removed. You can no longer see or message each other.")
                        Button("Done") { dismiss() }
                    }
                } else {
                    Section("What happened?") {
                        Picker("Reason", selection: $model.reason) {
                            Text("Choose a reason").tag(Optional<ReportReason>.none)
                            ForEach(ReportReason.allCases, id: \.self) { reason in
                                Text(reason.title).tag(Optional(reason))
                            }
                        }
                        .disabled(model.pending != nil || model.isSending)
                        .accessibilityIdentifier("report.reason")
                        TextField("Details (optional)", text: $model.details, axis: .vertical)
                            .lineLimit(3...7)
                            .textFieldStyle(BrandTextFieldStyle())
                            .disabled(model.pending != nil || model.isSending)
                            .accessibilityIdentifier("report.details")
                        Text("\(model.details.unicodeScalars.count)/\(ProfileReport.maximumDetailsLength)")
                            .font(.caption).foregroundStyle(BrandTheme.secondaryInk)
                    }
                    Section {
                        Text(
                            "Submitting a report removes this connection and prevents further contact between you. The report is private."
                        )
                        .font(.callout)
                        if let error = model.errorMessage { Text(error).foregroundStyle(.red) }
                        Button(model.pending == nil ? "Submit report" : "Retry submission") {
                            Task { await model.submit() }
                        }
                        .disabled(model.isSending || (model.pending == nil && !model.canSubmit))
                        .accessibilityIdentifier("report.submit")
                        if model.isSending { ProgressView("Submitting…") }
                    }
                }
            }
            .navigationTitle("Report \(name)").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }.disabled(model.isSending)
                }
            }
            .scrollContentBackground(.hidden)
            .background(BrandTheme.background).foregroundStyle(BrandTheme.ink)
        }
        .interactiveDismissDisabled(model.isSending)
        .onDisappear {
            let submitted = model.receiptID != nil
            model.reset()
            if submitted { onSubmitted() }
        }
        .privacySensitive()
    }
}
