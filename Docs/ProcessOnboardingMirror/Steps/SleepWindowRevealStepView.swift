//
//  SleepWindowRevealStepView.swift
//  Process
//
//  Page révélant la fenêtre de sommeil personnalisée basée sur l'heure de coucher de la veille
//

import SwiftUI
import HealthKit

struct SleepWindowRevealStepView: View {
    @EnvironmentObject var healthManager: HealthManager

    var onComplete: (() -> Void)?
    var onValidationChanged: ((Bool) -> Void)?
    var onBack: (() -> Void)?

    @State private var showContent: Bool = false
    @State private var windowStart: Date?
    @State private var windowEnd: Date?
    @State private var recommendedBedtime: Date?
    @State private var sleepNeedHours: Double = 8.0
    @StateObject private var alarmService = AlarmService.shared
    @StateObject private var hapticManager = HapticManager.shared

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: OnboardingConstants.titleAreaHeight)

                Spacer()
                    .frame(height: OnboardingConstants.titleToContentSpacing)

                VStack(spacing: 40) {
                    Spacer()
                        .frame(height: 40)

                    VStack(spacing: 24) {
                        // Titre principal
                        Text("Ta fenêtre de sommeil")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .opacity(showContent ? 1.0 : 0.0)
                            .offset(y: showContent ? 0 : 20)

                        // Fenêtre de sommeil
                        if let start = windowStart, let end = windowEnd, let recommended = recommendedBedtime {
                            SleepWindowCard(
                                windowStart: start,
                                windowEnd: end,
                                recommendedBedtime: recommended,
                                wakeTime: getWakeTime()
                            )
                            .opacity(showContent ? 1.0 : 0.0)
                            .offset(y: showContent ? 0 : 20)
                        }

                        // Texte explicatif
                        Text("Basée sur ton heure de coucher d'hier soir, cette fenêtre te permettra de couvrir environ 75% de ton besoin de sommeil.")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .padding(.horizontal, 20)
                            .opacity(showContent ? 1.0 : 0.0)
                            .offset(y: showContent ? 0 : 20)
                    }
                    .padding(.horizontal, 20)

                    Spacer()
                }
            }

            // Titre invisible pour garder l'espace
            VStack {
                OnboardingTitleView("", "")
                    .padding(.top, OnboardingConstants.titleTopPaddingAfterPrimaryGoal)
                    .opacity(0)
                Spacer()
            }
        }
        .onAppear {
            onValidationChanged?(true)

            // ✅ Charger les vraies données d'hier dès le début
            Task {
                await loadSleepWindowWithRealData()
            }
        }
    }

    // MARK: - Load Sleep Window

    /// ✅ Charger la fenêtre de sommeil avec les vraies données d'hier
    private func loadSleepWindowWithRealData() async {
        // 1. Récupérer l'heure de réveil configurée
        let wakeTime = getWakeTime()

        // 2. Récupérer le besoin de sommeil depuis le cache
        await loadSleepNeed()

        // 3. Récupérer l'heure de coucher de la veille depuis HealthKit
        let yesterdayBedtime = await fetchYesterdayBedtime()

        // 4. Calculer la fenêtre avec les vraies données
        let window = calculatePersonalizedSleepWindow(
            wakeTime: wakeTime,
            yesterdayBedtime: yesterdayBedtime,
            sleepNeedHours: sleepNeedHours
        )

        // 5. Afficher la fenêtre
        await MainActor.run {
            windowStart = window.start
            windowEnd = window.end
            recommendedBedtime = window.recommended

            // Animation d'apparition
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.2)) {
                showContent = true
            }

            hapticManager.impact(.light)
        }
    }

    private func getWakeTime() -> Date {
        let calendar = Calendar.current
        let now = Date()
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        let tomorrowStart = calendar.startOfDay(for: tomorrow)

        // Récupérer l'alarme configurée
        if let alarm = alarmService.alarms.first(where: { $0.isEnabled }),
           let nextRing = alarm.nextRingDate,
           nextRing >= tomorrowStart {
            return nextRing
        }

        // Fallback : 7h30 par défaut
        return calendar.date(bySettingHour: 7, minute: 30, second: 0, of: tomorrow) ?? tomorrow
    }

    private func fetchYesterdayBedtime() async -> Date? {
        let calendar = Calendar.current
        let now = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now) ?? now

        // ✅ Utiliser fetchSleepDataIntelligent qui est optimisé
        let sleepSamples = await healthManager.fetchSleepDataIntelligent(for: yesterday)

        // ✅ Filtrer pour ne garder que la nuit qui se termine le jour d'hier
        let sleepSamplesForNight = SleepScoreCalculator.filterSleepSamplesForNightEndingOn(yesterday, from: sleepSamples)

        // ✅ Utiliser extractSleepOnsetTimes pour obtenir l'heure d'endormissement RÉEL
        // Cette fonction retourne le premier échantillon asleep (asleepCore, asleepDeep, asleepREM)
        // et NON l'heure au lit (inBed)
        if let sleepOnsetTimes = SleepScoreCalculator.extractSleepOnsetTimes(from: sleepSamplesForNight) {
            Logger.debug("Heure de coucher d'hier (réel): \(sleepOnsetTimes.sleepOnset.formatted(date: .omitted, time: .shortened))", category: "SleepWindow")
            return sleepOnsetTimes.sleepOnset
        }

        Logger.warning("Impossible de récupérer l'heure de coucher d'hier", category: "SleepWindow")
        return nil
    }

    private func loadSleepNeed() async {
        // ✅ MIGRÉ: Utiliser SleepNeedScoreService (nouveau système simple)
        let sleepNeedService = SleepNeedScoreService.shared

        // ✅ Essayer d'abord le cache (rapide)
        if let cachedNeed = sleepNeedService.getCachedSleepNeed(for: Date()), cachedNeed > 0 {
            await MainActor.run {
                sleepNeedHours = cachedNeed
            }
            return
        }

        // ✅ Sinon calculer (peut être lent)
        let calculatedNeed = await sleepNeedService.getSleepNeed(for: Date())
        await MainActor.run {
            sleepNeedHours = calculatedNeed
        }
    }

    // MARK: - Calculate Personalized Sleep Window

    private func calculatePersonalizedSleepWindow(
        wakeTime: Date,
        yesterdayBedtime: Date?,
        sleepNeedHours: Double
    ) -> (start: Date, end: Date, recommended: Date) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today

        // ✅ Si on a l'heure de coucher d'hier, l'utiliser comme référence PRINCIPALE
        if let yesterdayBedtime = yesterdayBedtime {
            // Extraire l'heure et les minutes de l'heure de coucher d'hier
            let bedtimeComponents = calendar.dateComponents([.hour, .minute], from: yesterdayBedtime)
            let hour = bedtimeComponents.hour ?? 22
            let minute = bedtimeComponents.minute ?? 30

            // ✅ Normaliser l'heure de coucher d'hier à ce soir
            // Si l'heure de coucher était après minuit (0h-6h), c'était tôt ce matin
            // On va suggérer la même heure ce soir (qui sera techniquement demain matin)
            var baseBedtime: Date

            if hour >= 0 && hour < 6 {
                // C'était après minuit (ex: 1h30), donc on suggère la même heure ce soir
                // qui sera demain matin à la même heure (ex: demain à 1h30)
                baseBedtime = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: tomorrow) ?? tomorrow
            } else {
                // Heure normale (soir, ex: 22h30), utiliser la même heure ce soir
                baseBedtime = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: today) ?? today
                // Si ça donne une date dans le passé (avant maintenant), c'est pour ce soir, donc OK
                // Mais si c'est trop tôt dans la journée (avant 18h), c'est pour ce soir
                let now = Date()
                if baseBedtime < now {
                    // C'est déjà passé aujourd'hui, donc c'est pour ce soir (déjà correct)
                } else {
                    // C'est dans le futur aujourd'hui, donc c'est pour ce soir (déjà correct)
                }
            }

            // ✅ Heure recommandée : légèrement plus tôt que l'heure de coucher d'hier (10-15 minutes)
            // Pour encourager une amélioration progressive et réaliste
            let recommendedBedtime = baseBedtime.addingTimeInterval(-12 * 60) // 12 minutes plus tôt

            // ✅ Fenêtre de 20-25 minutes (centrée sur l'heure recommandée)
            let windowDuration: TimeInterval = 22.5 * 60 // 22.5 minutes (entre 20 et 25)
            let windowStart = recommendedBedtime.addingTimeInterval(-windowDuration / 2)
            let windowEnd = recommendedBedtime.addingTimeInterval(windowDuration / 2)

            // ✅ Vérifier que la fenêtre est réaliste par rapport au réveil
            // S'assurer qu'on a au moins 6 heures de sommeil
            let minSleepHours: Double = 6.0
            let maxBedtime = wakeTime.addingTimeInterval(-TimeInterval(minSleepHours * 3600))

            // Si la fenêtre est trop tardive, l'ajuster
            if windowEnd > maxBedtime {
                // Ajuster la fenêtre pour qu'elle se termine au maximum autorisé
                let adjustedWindowEnd = maxBedtime
                let adjustedRecommended = adjustedWindowEnd.addingTimeInterval(-windowDuration / 2)
                let adjustedWindowStart = adjustedRecommended.addingTimeInterval(-windowDuration / 2)

                return (
                    start: adjustedWindowStart,
                    end: adjustedWindowEnd,
                    recommended: adjustedRecommended
                )
            }

            Logger.debug("Fenêtre de sommeil basée sur l'heure de coucher d'hier (\(hour):\(String(format: "%02d", minute)))", category: "SleepWindow")
            Logger.debug("   Heure recommandée: \(recommendedBedtime.formatted(date: .omitted, time: .shortened))", category: "SleepWindow")
            Logger.debug("   Fenêtre: \(windowStart.formatted(date: .omitted, time: .shortened)) - \(windowEnd.formatted(date: .omitted, time: .shortened))", category: "SleepWindow")

            return (
                start: windowStart,
                end: windowEnd,
                recommended: recommendedBedtime
            )
        }

        // ✅ Fallback : Pas de données d'hier, utiliser l'heure idéale basée sur le besoin de sommeil
        let need = TimeInterval(sleepNeedHours * 3600)
        let perfectBedtime = wakeTime.addingTimeInterval(-need)

        // Fenêtre de 20-25 minutes autour de l'heure idéale
        let windowDuration: TimeInterval = 22.5 * 60 // 22.5 minutes
        let windowStart = perfectBedtime.addingTimeInterval(-windowDuration / 2)
        let windowEnd = perfectBedtime.addingTimeInterval(windowDuration / 2)

        Logger.debug("Pas de données d'hier, utilisation de l'heure idéale", category: "SleepWindow")

        return (
            start: windowStart,
            end: windowEnd,
            recommended: perfectBedtime
        )
    }
}

// MARK: - Sleep Window Card

struct SleepWindowCard: View {
    let windowStart: Date
    let windowEnd: Date
    let recommendedBedtime: Date
    let wakeTime: Date

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }

    var body: some View {
        VStack(spacing: 20) {
            // Heure recommandée en grand
            VStack(spacing: 8) {
                Text("Heure recommandée")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))

                Text(timeFormatter.string(from: recommendedBedtime))
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.white)
            }

            // Fenêtre de sommeil
            VStack(spacing: 12) {
                Text("Fenêtre de sommeil")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))

                HStack(spacing: 16) {
                    VStack(spacing: 4) {
                        Text("Début")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                        Text(timeFormatter.string(from: windowStart))
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                    }

                    Text("→")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))

                    VStack(spacing: 4) {
                        Text("Fin")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                        Text(timeFormatter.string(from: windowEnd))
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.3),
                                .white.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )

            // Heure de réveil
            HStack(spacing: 8) {
                Image(systemName: "sunrise.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))

                Text("Réveil à \(timeFormatter.string(from: wakeTime))")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.2),
                            .white.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}
