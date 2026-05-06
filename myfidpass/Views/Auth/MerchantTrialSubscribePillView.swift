//
//  MerchantTrialSubscribePillView.swift
//  myfidpass
//
//  Bandeau flottant au-dessus du tab bar : CTA abonnement + temps restant sur l’accès offert (compte, pas l’App Store).
//

import SwiftUI

struct MerchantTrialSubscribePillView: View {
    let trialEndsAt: Date
    var onSubscribe: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            pillContent(now: context.date)
        }
    }

    private func pillContent(now: Date) -> some View {
        let remaining = Self.remainingLabel(until: trialEndsAt, now: now)
        return Button(action: onSubscribe) {
            HStack {
                Spacer(minLength: 0)
                HStack(alignment: .center, spacing: 9) {
                    Text("Profitez du mois à 1€")
                        .font(.system(size: 14, weight: .medium, design: .default))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.68)
                        .multilineTextAlignment(.leading)
                        .layoutPriority(1)

                    HStack(spacing: 5) {
                        Circle()
                            .fill(Self.statusDotColor)
                            .frame(width: 7, height: 7)
                        Text(remaining)
                            .font(.system(size: 12, weight: .medium, design: .default))
                            .foregroundStyle(.white.opacity(0.95))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Self.innerCapsuleFill, in: Capsule())
                    .fixedSize(horizontal: true, vertical: false)
                }
                .padding(.leading, 13)
                .padding(.trailing, 11)
                .padding(.vertical, 14)
                .frame(maxWidth: 304, alignment: .leading)
                .background(Capsule().fill(Color.black))
                .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
                Spacer(minLength: 0)
            }
        }
        .buttonStyle(PressableSubscribePillStyle())
        .accessibilityLabel("Profitez du mois à 1€. \(remaining). Touchez pour choisir l’abonnement.")
    }

    /// Pastille intérieure type capture (gris anthracite, distinct du fond noir).
    private static var innerCapsuleFill: Color {
        Color(red: 28 / 255, green: 28 / 255, blue: 30 / 255)
    }

    /// Point d’état « temps restant » (vert lime, comme la maquette).
    private static var statusDotColor: Color {
        Color(red: 163 / 255, green: 230 / 255, blue: 53 / 255)
    }

    /// Libellé court type « 12 h restantes » / « 2 jours restants » (réutilisé par le bandeau Commerce).
    static func remainingLabel(until end: Date, now: Date) -> String {
        let secs = end.timeIntervalSince(now)
        if secs <= 0 { return "Accès terminé" }
        if secs < 60 { return "Moins d’1 min" }
        if secs < 3600 {
            let m = Int(floor(secs / 60))
            return m <= 1 ? "1 min restante" : "\(m) min restantes"
        }
        let h = Int(floor(secs / 3600))
        if secs < 86400 {
            return h <= 1 ? "1 h restante" : "\(h) h restantes"
        }
        let d = Int(floor(secs / 86400))
        return d <= 1 ? "1 jour restant" : "\(d) jours restants"
    }
}

private struct PressableSubscribePillStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.82), value: configuration.isPressed)
    }
}

#Preview {
    MerchantTrialSubscribePillView(
        trialEndsAt: Date().addingTimeInterval(3600 * 5 + 120),
        onSubscribe: {}
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}
