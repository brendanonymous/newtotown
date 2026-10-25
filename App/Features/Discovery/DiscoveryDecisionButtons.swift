import NewToTownCore
import SwiftUI

/// A dedicated column beneath the photo; profile text never lays out behind it.
struct DiscoveryDecisionButtons: View {
    let name: String
    let onDecision: (ConnectionChoice) -> Void

    var body: some View {
        VStack(spacing: 12) {
            decision(.connect, symbol: "checkmark")
            decision(.pass, symbol: "xmark")
        }
    }

    private func decision(_ choice: ConnectionChoice, symbol: String) -> some View {
        Button {
            onDecision(choice)
        } label: {
            Image(systemName: symbol).font(.title2.weight(.semibold))
                .frame(width: 64, height: 64)
                .foregroundStyle(choice == .connect ? BrandTheme.background : BrandTheme.ink)
                .background(choice == .connect ? BrandTheme.ink : BrandTheme.sage.opacity(0.3), in: Circle())
        }
        .accessibilityLabel(choice == .connect ? "Connect with \(name)" : "Pass on \(name)")
        .accessibilityIdentifier(choice == .connect ? "discovery.connect" : "discovery.pass")
    }
}
