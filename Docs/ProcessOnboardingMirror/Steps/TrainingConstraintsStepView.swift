//
//  TrainingConstraintsStepView.swift
//  Process
//
//  Contraintes d'entraînement (temps, équipement, disponibilité)
//

import SwiftUI

struct TrainingConstraintsStepView: View {
    @Binding var sessionsPerWeek: Int
    @Binding var sessionDuration: Int
    @Binding var selectedLocation: TrainingLocation
    @Binding var selectedEquipment: Set<PlanEquipment>
    var onValidationChanged: ((Bool) -> Void)?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 40) {
                // Titre
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tes contraintes")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)

                    Text("d'entraînement")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 30)
                .padding(.top, 60) // ✅ Grand espacement pour éviter le débordement haut

                // Sessions par semaine - SCROLLVIEW HORIZONTAL
                VStack(alignment: .leading, spacing: 16) {
                    Text("Sessions par semaine")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, 30)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(1...7, id: \.self) { number in
                                Button(action: {
                                    HapticManager.shared.selection()
                                    sessionsPerWeek = number
                                    onValidationChanged?(true)
                                }) {
                                    Text("\(number)")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(width: 50, height: 50)
                                }
                                .glassStyle()
                                .buttonBorderShape(.circle)
                                .opacity(sessionsPerWeek == number ? 1.0 : 0.4)
                                .scaleEffect(sessionsPerWeek == number ? 1.1 : 1.0)
                            }
                        }
                        .padding(.horizontal, 30)
                    }
                }

                // Durée max session - LISTE VERTICALE
                VStack(alignment: .leading, spacing: 16) {
                    Text("Durée max par session")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))

                    VStack(spacing: 10) {
                        ForEach([30, 45, 60, 75, 90, 120], id: \.self) { minutes in
                            Button(action: {
                                HapticManager.shared.selection()
                                sessionDuration = minutes
                                onValidationChanged?(true)
                            }) {
                                HStack {
                                    Text("\(minutes) min")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.white)

                                    Spacer()

                                    if sessionDuration == minutes {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 14)
                            }
                            .glassStyle()
                            .buttonBorderShape(.roundedRectangle(radius: 12))
                            .opacity(sessionDuration == minutes ? 1.0 : 0.5)
                        }
                    }
                }
                .padding(.horizontal, 30)

                // Lieu d'entraînement
                VStack(alignment: .leading, spacing: 16) {
                    Text("Où t'entraînes-tu ?")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))

                    VStack(spacing: 10) {
                        ForEach([TrainingLocation.home, .gym, .outdoor, .mixed], id: \.self) { location in
                            Button(action: {
                                HapticManager.shared.selection()
                                selectedLocation = location
                                onValidationChanged?(true)
                            }) {
                                HStack {
                                    Image(systemName: location.icon)
                                        .font(.system(size: 20))
                                        .foregroundColor(selectedLocation == location ? .blue : .white.opacity(0.7))

                                    Text(location.rawValue)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.white)

                                    Spacer()

                                    if selectedLocation == location {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 14)
                            }
                            .glassStyle()
                            .buttonBorderShape(.roundedRectangle(radius: 12))
                            .opacity(selectedLocation == location ? 1.0 : 0.5)
                        }
                    }
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 100) // ✅ Grand espacement pour éviter le débordement bas
            }
        }
        .onAppear {
            // Valider par défaut (valeurs par défaut déjà sélectionnées)
            onValidationChanged?(true)
        }
}
}
