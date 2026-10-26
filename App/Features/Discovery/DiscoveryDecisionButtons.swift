import NewToTownCore
import SwiftUI

/// A dedicated column beneath the photo; profile text never lays out behind it.
struct DiscoveryDecisionButtons: View {
    let name: String
    var pendingDecision: ConnectionChoice? = nil
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
            Group {
                if pendingDecision == choice {
                    ProgressView()
                        .tint(choice == .connect ? BrandTheme.background : BrandTheme.ink)
                        .accessibilityIdentifier("discovery.\(choice.rawValue).saving")
                } else {
                    Image(systemName: symbol).font(.title2.weight(.semibold))
                }
            }
            .frame(width: 56, height: 44)
            .foregroundStyle(choice == .connect ? BrandTheme.background : BrandTheme.ink)
            .background(choice == .connect ? BrandTheme.ink : BrandTheme.sage.opacity(0.3), in: RoundedRectangle(cornerRadius: 12)
            )
        }
        .accessibilityLabel(choice == .connect ? "Connect with \(name)" : "Pass on \(name)")
        .accessibilityValue(pendingDecision == choice ? "Saving decision" : "")
        .accessibilityIdentifier(choice == .connect ? "discovery.connect" : "discovery.pass")
    }
}
