//
//  MerchantMotion.swift
//  myfidpass
//
//  Courbes d’animation et retour tactile cohérents pour navigation + boutons (UX fluide).
//

import AVFoundation
import SwiftUI
import UIKit

// MARK: - Aperçu carte accueil (pression tactile)

/// Contexte tactile optionnel pour **`MerchantPressableButtonStyle`** (zoom immédiat sans bloquer un scroll voisin).
/// Sur l’accueil commerçant : `.inactive`. Conservé pour d’éventuels écrans avec paging horizontal à côté d’un bouton.
struct HomeCarouselPressContext: Equatable {
    /// Petit mouvement encore traité comme « doigt à l’écran » pour l’effet visuel press.
    var fingerDownForVisual: Bool = false
    /// Scroll / swipe horizontal prioritaire : désactive l’effet press sur la carte.
    var horizontalPageSwipe: Bool = false

    static let inactive = HomeCarouselPressContext()
}

private struct HomeCarouselPressKey: EnvironmentKey {
    static let defaultValue = HomeCarouselPressContext.inactive
}

extension EnvironmentValues {
    var homeCarouselPress: HomeCarouselPressContext {
        get { self[HomeCarouselPressKey.self] }
        set { self[HomeCarouselPressKey.self] = newValue }
    }
}

/// Animations partagées — ressorts légèrement amortis pour éviter l’effet « ressort trop nerveux ».
enum MerchantMotion {
    /// Changement d’onglet (TabView) — ressort proche de l’onboarding.
    static let tabSwitch: Animation = .spring(response: 0.42, dampingFraction: 0.88, blendDuration: 0)

    /// Push / pop dans un `NavigationStack` (profondeur de pile).
    static let navigationPath: Animation = .spring(response: 0.42, dampingFraction: 0.88, blendDuration: 0)

    /// Apparition de contenu (listes, cartes).
    static let contentReveal: Animation = .spring(response: 0.48, dampingFraction: 0.82, blendDuration: 0)

    /// Bouton : press / release — réactif, peu de rebond.
    static let buttonPress: Animation = .spring(response: 0.3, dampingFraction: 0.78, blendDuration: 0)

    /// Menu latéral style X (Accueil).
    static let sidebar: Animation = .interactiveSpring(duration: 0.2, extraBounce: 0.02)

    /// Overlay plein écran / feuille modale lourde.
    static let overlayPresent: Animation = .spring(response: 0.42, dampingFraction: 0.88, blendDuration: 0)

    /// Morphing barre de recherche ↔ icônes top bar.
    static let searchBarMorph: Animation = .spring(response: 0.38, dampingFraction: 0.86, blendDuration: 0)

    /// Crossfade léger entre états racine (ex. auth ↔ app).
    static let rootCrossfade: Animation = .easeInOut(duration: 0.22)

    /// Zoom logo Ma Carte (entrée).
    static let cardLogoZoomIn: Animation = .spring(response: 0.26, dampingFraction: 0.86, blendDuration: 0)

    /// Dézoom logo Ma Carte — rapide, sans rebond (tap retour / autre zone / fermeture feuille).
    static let cardLogoZoomOut: Animation = .easeOut(duration: 0.14)
}

extension NavigationPath {
    /// Push animé dans une pile SwiftUI.
    mutating func appendAnimated<T>(_ value: T, animation: Animation = MerchantMotion.navigationPath) where T: Hashable {
        withAnimation(animation) {
            append(value)
        }
    }
}

/// Style de bouton « press » pour cartes et CTA : léger zoom + assombrissement.
///
/// - Par défaut : suit `configuration.isPressed`.
/// - `recognizeTouchImmediately` : combine `isPressed` avec `Environment.homeCarouselPress` (souvent `.inactive`).
struct MerchantPressableButtonStyle: ButtonStyle {
    var scalePressed: CGFloat = 0.97
    var opacityPressed: Double = 0.9
    var recognizeTouchImmediately: Bool = false
    /// Son + haptique léger à l’appui (désactiver sur listes très denses si besoin).
    var playsUXFeedback: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        PressBody(
            configuration: configuration,
            scalePressed: scalePressed,
            opacityPressed: opacityPressed,
            recognizeTouchImmediately: recognizeTouchImmediately,
            playsUXFeedback: playsUXFeedback
        )
    }

    private struct PressBody: View {
        let configuration: Configuration
        let scalePressed: CGFloat
        let opacityPressed: Double
        let recognizeTouchImmediately: Bool
        let playsUXFeedback: Bool

        @Environment(\.homeCarouselPress) private var homeCarouselPress

        private var pressedEffective: Bool {
            if !recognizeTouchImmediately {
                return configuration.isPressed
            }
            if homeCarouselPress.horizontalPageSwipe {
                return false
            }
            return configuration.isPressed || homeCarouselPress.fingerDownForVisual
        }

        var body: some View {
            configuration.label
                .scaleEffect(pressedEffective ? scalePressed : 1)
                .brightness(pressedEffective ? -0.035 : 0)
                .opacity(pressedEffective ? opacityPressed : 1)
                .animation(MerchantMotion.buttonPress, value: pressedEffective)
                .onChange(of: pressedEffective) { wasPressed, isPressed in
                    guard playsUXFeedback, isPressed, !wasPressed else { return }
                    MerchantUXFeedback.shared.play(.tap)
                }
        }
    }
}

// MARK: - Onboarding flyer (secousse CTA)

/// Secousse horizontale du seul CTA « Créer mon flyer de jeu » (onglet Commerce) quand l’utilisateur tente un autre onglet.
struct FlyerPrimaryCTAShakeModifier: ViewModifier {
    let shakeToken: Int
    @State private var offsetX: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .offset(x: offsetX)
            .onChange(of: shakeToken) { _, _ in
                guard shakeToken > 0 else { return }
                Task { @MainActor in
                    // Assez long à l’écran (~1,1 s de pauses + ressort) pour que la secousse se lise clairement.
                    let pattern: [CGFloat] = [0, -20, 20, -18, 18, -16, 16, -12, 12, -8, 8, -4, 4, 0]
                    for x in pattern {
                        withAnimation(MerchantMotion.flyerCTAShakeStep) {
                            offsetX = x
                        }
                        try? await Task.sleep(nanoseconds: 80_000_000)
                    }
                }
            }
    }
}

extension MerchantMotion {
    /// Pulsations lisibles (chaque impulsion a le temps d’aller au point avant la suivante).
    static let flyerCTAShakeStep: Animation = .interpolatingSpring(
        mass: 0.3,
        stiffness: 300,
        damping: 16,
        initialVelocity: 0
    )
}

extension View {
    func flyerPrimaryCTAShake(shakeToken: Int) -> some View {
        modifier(FlyerPrimaryCTAShakeModifier(shakeToken: shakeToken))
    }
}

// MARK: - Haptiques (+ son `soun2` uniquement à l’envoi d’une notif)

/// Retour sensoriel unifié pour l’app commerçant (et onboarding via `HapticManager`).
@MainActor
final class MerchantUXFeedback {
    static let shared = MerchantUXFeedback()

    enum Kind: Equatable {
        case tap
        case selection
        case emphasis
        case confirm
        case tabSwitch
        case scan
        case save
        case success
        case warning
        case error
    }

    private static let soundEnabledKey = "myfidpass.merchantUX.soundEnabled"
    private static let notificationSoundFileName = "soun2"
    private static let minPlayInterval: TimeInterval = 0.055

    private var notificationPlayer: AVAudioPlayer?
    private var lastPlayAt = Date.distantPast
    private var isPrepared = false

    var isSoundEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: Self.soundEnabledKey) == nil { return true }
            return UserDefaults.standard.bool(forKey: Self.soundEnabledKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: Self.soundEnabledKey) }
    }

    private init() {}

    func prepare() {
        guard !isPrepared else { return }
        isPrepared = true
        configureAudioSession()
    }

    /// Haptique seule — pas de son (évite le bruit à chaque tap / onglet / scan).
    func play(_ kind: Kind) {
        emitHaptic(for: kind)
    }

    /// Son signature quand une campagne / notification est envoyée aux clients.
    func playNotificationSent() {
        prepare()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        playNotificationSound(volume: 0.88)
    }

    func playImpact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        switch style {
        case .light: play(.tap)
        case .medium: play(.emphasis)
        case .heavy: play(.confirm)
        case .soft: play(.tabSwitch)
        case .rigid: play(.scan)
        @unknown default: play(.tap)
        }
    }

    func playNotification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        switch type {
        case .success: play(.success)
        case .warning: play(.warning)
        case .error: play(.error)
        @unknown default: play(.emphasis)
        }
    }

    func playSelection() {
        play(.selection)
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true, options: [])
    }

    private func playNotificationSound(volume: Float) {
        guard isSoundEnabled else { return }
        if notificationPlayer == nil {
            guard let url = Bundle.main.url(forResource: Self.notificationSoundFileName, withExtension: "mp3") else { return }
            notificationPlayer = try? AVAudioPlayer(contentsOf: url)
            notificationPlayer?.prepareToPlay()
        }
        guard let player = notificationPlayer else { return }
        let now = Date()
        guard now.timeIntervalSince(lastPlayAt) >= Self.minPlayInterval else { return }
        lastPlayAt = now
        player.volume = volume
        player.currentTime = 0
        player.play()
    }

    private func emitHaptic(for kind: Kind) {
        switch kind {
        case .tap:
            impact(.light, intensity: 0.52)
        case .selection:
            UISelectionFeedbackGenerator().selectionChanged()
        case .emphasis:
            impact(.medium, intensity: 0.72)
        case .confirm:
            impact(.heavy, intensity: 0.85)
        case .tabSwitch:
            impact(.soft, intensity: 0.58)
        case .scan:
            impact(.rigid, intensity: 0.78)
        case .save, .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .warning:
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case .error:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    private func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle, intensity: CGFloat) {
        let g = UIImpactFeedbackGenerator(style: style)
        g.prepare()
        g.impactOccurred(intensity: intensity)
    }
}
