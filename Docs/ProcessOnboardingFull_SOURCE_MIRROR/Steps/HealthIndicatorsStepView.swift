//
//  HealthIndicatorsStepView.swift
//  Process
//
//  Sélection des indicateurs de santé à suivre
//

import SwiftUI

struct HealthIndicatorsStepView: View {
    @EnvironmentObject var profileService: UnifiedProfileService
    @State private var selectedIndicators: Set<String> = []

    var onValidationChanged: ((Bool) -> Void)?

    private let indicators = [
        ("Fréquence cardiaque au repos", "heart.fill"),
        ("Variabilité de la fréquence cardiaque (HRV)", "waveform.path.ecg"),
        ("Qualité du sommeil", "moon.fill"),
        ("Niveau de stress", "brain.head.profile"),
        ("Calories brûlées", "flame.fill"),
        ("Pas quotidiens", "figure.walk")
    ]

    var body: some View {
        VStack(spacing: 50) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Quels indicateurs")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)

                Text("veux-tu suivre ?")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 40)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    ForEach(indicators, id: \.0) { indicator in
                        Button(action: {
                            toggleIndicator(indicator.0)
                        }) {
                            HStack {
                                Image(systemName: indicator.1)
                                    .font(.title3)
                                    .foregroundColor(selectedIndicators.contains(indicator.0) ? .purple : .white.opacity(0.7))

                                Text(indicator.0)
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                Spacer()

                                if selectedIndicators.contains(indicator.0) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                } else {
                                    Image(systemName: "circle")
                                        .foregroundColor(.white.opacity(0.5))
                                }
                            }
                            .padding(20)
                        }
                        .glassStyle()
                        .buttonBorderShape(.roundedRectangle(radius: 16))
                        .opacity(selectedIndicators.contains(indicator.0) ? 1.0 : 0.6)
                    }
                }
                .padding(.horizontal, 40)
            }
            .frame(maxHeight: 500)
        }
    }

    private func toggleIndicator(_ indicator: String) {
        HapticManager.shared.selection()

        if selectedIndicators.contains(indicator) {
            selectedIndicators.remove(indicator)
        } else {
            selectedIndicators.insert(indicator)
        }

        onValidationChanged?(!selectedIndicators.isEmpty)
    }
}
