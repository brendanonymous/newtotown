import NewToTownCore
import SwiftUI

struct PersonalInfoView: View {
    let contactsService: (any ContactDetailsService)?
    @State private var model: PersonalInfoModel

    init(service: any PersonalInfoService, contactsService: (any ContactDetailsService)? = nil) {
        self.contactsService = contactsService
        _model = State(initialValue: PersonalInfoModel(service: service))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Personal info").font(.system(.largeTitle, design: .serif))
                Text("Your contact details are private and aren’t shown in discovery.")
                    .foregroundStyle(BrandTheme.secondaryInk)
                if let info = model.info {
                    detail("Email", symbol: "envelope", value: info.email, identifier: "account.email")
                    if info.email == nil { addContact(.email) }
                    Divider()
                    detail("Phone number", symbol: "phone", value: info.phone, identifier: "account.phone")
                    if info.phone == nil { addContact(.phone) }
                }
                if model.isBusy { ProgressView() }
                if let error = model.errorMessage {
                    Text(error).font(.callout).foregroundStyle(.red)
                    Button("Try again") { Task { await model.load() } }
                }
            }
            .padding(28).frame(maxWidth: 520).frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.always, axes: .vertical)
        .refreshable { await model.load() }
        .foregroundStyle(BrandTheme.ink)
        .background(BrandTheme.background)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { BrandNavigationLogo() }
        .task { await model.load() }
    }

    @ViewBuilder private func addContact(_ kind: ContactDetailKind) -> some View {
        if let contactsService {
            NavigationLink {
                ContactDetailsView(kind: kind, service: contactsService) {
                    Task { await model.load() }
                }
            } label: {
                Label(kind == .email ? "Add email" : "Add phone number", systemImage: "plus.circle")
                    .frame(minHeight: 44)
            }
            .disabled(model.isBusy)
            .accessibilityIdentifier("account.add.\(kind.rawValue)")
        }
    }

    private func detail(_ title: String, symbol: String, value: String?, identifier: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: symbol).font(.headline)
            Text(value ?? "Not provided")
                .foregroundStyle(value == nil ? BrandTheme.secondaryInk : BrandTheme.ink)
                .textSelection(.enabled)
                .accessibilityIdentifier(identifier)
                .privacySensitive()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
