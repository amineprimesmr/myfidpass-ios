//
//  HealthDataAnimationStepView.swift
//  Process
//
//  Created by ENNASRI Amine on 22/09/2025.
//
//  Voir aussi : HealthDataAnimationRowViews ; +AnimationLogic (chargement / animations) ; +Sections (UI Sources / Aujourd'hui).
//

import SwiftUI
import FirebaseAuth
import HealthKit

struct HealthDataAnimationStepView: View {
    @EnvironmentObject var healthManager: HealthManager
    @EnvironmentObject var dataManager: DataManager
    /// `internal` : utilisés par `HealthDataAnimationStepView+AnimationLogic`.
    @StateObject var appleWatchService = AppleWatchService.shared
    @StateObject var watchAvailabilityManager = WatchAvailabilityManager.shared
    @StateObject var hapticManager = HapticManager.shared
    @State var animationProgress: Double = 0.0
    @State var showData = false
    @State var currentDataIndex = 0
    @State var isLoadingData = true
    @State var dataRefreshTrigger = UUID()
    @State var animationTimer: Timer?

    var onComplete: (() -> Void)?
    var onBack: (() -> Void)?

    // ✨ États pour les sections d'animation
    @State var currentSection: AnimationSection = .sources
    @State var completedSources: Set<String> = []
    @State var daysFound: Int = 0
    @State var showContinueButton: Bool = false

    // ✨ États pour l'affichage progressif des sections
    @State var showSourcesContent: Bool = false
    @State var showMyViewpointContent: Bool = false
    @State var showDataSection: Bool = false
    @State var sourcesAnimationComplete: Bool = false // ✨ Contrôle la transition vers le mode compact
    @State var showCompletionText: Bool = false // ✨ Afficher le texte de complétion

    // Données stockées pour l'affichage
    @State var displaySteps = 0
    @State var displayCalories = 0.0
    @State var displayFloors = 0
    @State var displayHeartRate = 0.0
    @State var displayEffortScore = 0.0
    @State var displayBedtime: Date?
    @State var displaySleepDuration: Double = 0.0 // en heures
    @State var displaySleepDebt: Double = 0.0 // en heures

    // ✅ Flags pour savoir si on a vraiment des données
    @State var hasValidStepsData = false
    @State var hasValidCaloriesData = false
    @State var hasValidSleepData = false
    @State var hasValidEffortScoreData = false

    // ✨ Sources de données réelles (sera rempli dynamiquement)
    @State var realDataSources: [String] = []

    // ✨ États pour les sous-parties "Sources de données"
    @State var phoneMovementProgress: Double = 0.0
    @State var appleHealthProgress: Double = 0.0
    @State var completedDataTypes: Set<String> = []
    @State var completedHealthSources: Set<String> = []
    @State var loadingHealthSources: Set<String> = [] // ✨ Sources en cours de chargement

    // ✨ États pour les sous-parties "Aujourd'hui"
    @State var sleepPatternProgress: Double = 0.0
    @State var completedSleepPattern: Set<String> = []

    // ✨ États pour les sous-parties "DATA"
    @State var sleepNeedProgress: Double = 0.0
    @State var sleepDebtProgress: Double = 0.0
    @State var completedSleepNeed: Set<String> = []
    @State var completedSleepDebt: Set<String> = []

    // ✨ Types de données sous "Santé Apple" (toujours les mêmes)
    let healthDataTypes: [String] = [
        "Minutes d'exercice",
        "Entraînements",
        "Sommeil"
    ]

    // ✨ Sources par défaut à afficher sous "Santé Apple" (toujours les mêmes)
    let defaultHealthSources: [String] = [
        "WHOOP",
        "Apple Watch",
        "Bevel"
    ]

    // ✨ Types de données "Besoin de sommeil"
    let sleepNeedTypes: [String] = [
        "Trouvé les jours précoces et tardifs",
        "Moyenne de la différence"
    ]

    // ✨ Types de données "Capacité d'entrainement" (dynamiques avec valeurs réelles)

    // Données à afficher (section finale)
    let dataItems = [
        ("Pas aujourd'hui", "steps", "steps"),
        ("Calories brûlées", "activeEnergyBurned", "kcal"),
        ("Étages montés", "flightsClimbed", "étages"),
        ("BPM moyen", "heartRate", "bpm"),
        ("Score d'effort", "effortScore", "%")
    ]

    enum AnimationSection {
        case sources
        case myViewpoint
    }

    struct DataItem: Identifiable {
        let id = UUID()
        let name: String
        let icon: String
        var hasProgress: Bool = false
        var isPending: Bool = false
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    // ✨ Encadré principal pour toute l'animation - Bouton Liquid Glass
                    Button(action: {
                        // Action vide - juste pour le style Liquid Glass
                    }) {
                        VStack(spacing: 20) {
                            // ✨ Section 1 : Sources de données (titre toujours visible, contenu progressif)
                            sourcesSection

                            // ✨ Section 2 : Aujourd'hui (titre toujours visible, contenu progressif)
                            // ✨ Les sections DATA sont intégrées dans myViewpointSection
                            myViewpointSection
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity)
                    }
                    .glassStyle()
                    .buttonBorderShape(.roundedRectangle(radius: 20))
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, showContinueButton ? 120 : 100)
                }

            // ✨ Bouton Continuer (apparaît à la fin de l'animation)
            if showContinueButton {
                Button(action: {
                    HapticManager.shared.impact(.medium)
                    onComplete?()
                }) {
                    Text("Continuer")
                        .font(.system(size: 20, weight: .black))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .glassStyle()
                .buttonBorderShape(.roundedRectangle(radius: 50))
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: showContinueButton)
            }
            }
        }
        .onAppear {
            Task {
                await loadHealthData()
            }
        }
        .onDisappear {
            stopAnimation()
        }
    }

}
