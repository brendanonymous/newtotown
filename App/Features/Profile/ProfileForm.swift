import NewToTownCore
import SwiftUI

struct ProfileForm: View {
    @Binding var draft: ProfileDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            field("First name", placeholder: "What should we call you?", text: $draft.firstName)
                .textContentType(.givenName)
                .accessibilityIdentifier("profile.firstName")
            field("Job title", placeholder: "e.g. Designer, teacher, retired", text: $draft.jobTitle)
            VStack(alignment: .leading, spacing: 8) {
                Text("What are you up for?").font(.headline)
                TextField(
                    "e.g. Looking for someone to grab a beer with in Old Town.", text: $draft.goal,
                    axis: .vertical
                )
                .lineLimit(3...6)
                .textFieldStyle(BrandTextFieldStyle())
                Text("10–280 characters").font(.caption).foregroundStyle(BrandTheme.secondaryInk)
            }
            DatePicker("Birthday", selection: birthday, in: ...Date.now, displayedComponents: .date)
                .environment(\.calendar, BirthDate.calendar)
                .environment(\.timeZone, BirthDate.calendar.timeZone)
            Text("Your birthday stays private.")
                .font(.footnote)
                .foregroundStyle(BrandTheme.secondaryInk)
            Label("Scottsdale, Arizona", systemImage: "mappin")
        }
    }

    private var birthday: Binding<Date> {
        Binding(
            get: { BirthDate.parse(draft.dateOfBirth) ?? Date.now },
            set: { draft.dateOfBirth = BirthDate.string(from: $0) }
        )
    }

    private func field(_ title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            TextField(placeholder, text: text).textFieldStyle(BrandTextFieldStyle())
        }
    }
}
