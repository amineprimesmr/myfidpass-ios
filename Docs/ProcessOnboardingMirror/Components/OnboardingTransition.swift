//
//  OnboardingTransition.swift
//  Process
//
//  Système de transition ultra fluide pour l'onboarding
//  Animations incroyables avec slide, fade et parallaxe
//

import SwiftUI

// MARK: - Direction de transition
enum TransitionDirection {
    case forward  // Vers l'avant (next)
    case backward // Vers l'arrière (previous)
}

// MARK: - Modifier de transition personnalisé
struct OnboardingTransitionModifier: ViewModifier {
    let direction: TransitionDirection
    let isActive: Bool

    func body(content: Content) -> some View {
        content
            // ✅ Plus d'offset pour une transition plus visuelle
            .offset(x: isActive ? 0 : (direction == .forward ? 80 : -80))
            .opacity(isActive ? 1 : 0)
            .scaleEffect(isActive ? 1 : 0.92)
            .blur(radius: isActive ? 0 : 3)
    }
}

extension View {
    func onboardingTransition(direction: TransitionDirection, isActive: Bool) -> some View {
        modifier(OnboardingTransitionModifier(direction: direction, isActive: isActive))
    }
}

// MARK: - Container avec transition fluide
struct OnboardingTransitionContainer<Content: View>: View {
    let content: Content
    let currentStep: Int
    let previousStep: Int?
    let isTransitioning: Bool

    init(
        currentStep: Int,
        previousStep: Int?,
        isTransitioning: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.currentStep = currentStep
        self.previousStep = previousStep
        self.isTransitioning = isTransitioning
        self.content = content()
    }

    private var direction: TransitionDirection {
        guard let previous = previousStep else { return .forward }
        return currentStep > previous ? .forward : .backward
    }

    var body: some View {
        content
            .id("step_\(currentStep)") // Force le re-render pour chaque étape
            .transition(.asymmetric(
                // ✅ Transitions plus visuelles avec offset et scale
                insertion: .move(edge: direction == .forward ? .trailing : .leading)
                    .combined(with: .opacity)
                    .combined(with: .scale(scale: 0.92)),
                removal: .move(edge: direction == .forward ? .leading : .trailing)
                    .combined(with: .opacity)
                    .combined(with: .scale(scale: 0.92))
            ))
    }
}

// MARK: - Transition personnalisée avec parallaxe
struct ParallaxTransition: ViewModifier {
    let progress: CGFloat // 0.0 à 1.0

    func body(content: Content) -> some View {
        content
            .offset(x: (1.0 - progress) * 30)
            .opacity(progress)
            .scaleEffect(0.95 + (progress * 0.05))
    }
}

extension View {
    func parallaxTransition(progress: CGFloat) -> some View {
        modifier(ParallaxTransition(progress: progress))
    }
}

// MARK: - Animation personnalisée ultra fluide
extension Animation {
    // ✅ Animation principale ULTRA VISUELLE - plus longue et plus fluide
    static var onboardingTransition: Animation {
        .spring(response: 0.55, dampingFraction: 0.82, blendDuration: 0.4)
    }

    // Animation rapide pour interactions immédiates
    static var onboardingTransitionFast: Animation {
        .spring(response: 0.4, dampingFraction: 0.9, blendDuration: 0.2)
    }

    // Animation lente pour transitions importantes
    static var onboardingTransitionSlow: Animation {
        .spring(response: 0.7, dampingFraction: 0.8, blendDuration: 0.4)
    }

    // Animation ultra fluide avec courbe personnalisée (ease-in-out-cubic)
    static var onboardingUltraSmooth: Animation {
        .timingCurve(0.25, 0.1, 0.25, 1.0, duration: 0.55)
    }

    // Animation pour éléments d'entrée avec bounce subtil
    static var onboardingEntrance: Animation {
        .spring(response: 0.6, dampingFraction: 0.75, blendDuration: 0.3)
    }
}

// MARK: - View Modifier pour animation d'entrée progressive
struct StaggeredEntranceModifier: ViewModifier {
    let delay: Double
    let direction: TransitionDirection
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(
                x: isVisible ? 0 : (direction == .forward ? 30 : -30),
                y: isVisible ? 0 : 20
            )
            .scaleEffect(isVisible ? 1 : 0.9)
            .blur(radius: isVisible ? 0 : 5)
            .onAppear {
                withAnimation(.onboardingTransition.delay(delay)) {
                    isVisible = true
                }
            }
    }
}

extension View {
    func staggeredEntrance(delay: Double = 0, direction: TransitionDirection = .forward) -> some View {
        modifier(StaggeredEntranceModifier(delay: delay, direction: direction))
    }
}

// MARK: - Transition avec blur et fade ultra fluide
struct UltraSmoothTransition: ViewModifier {
    let isActive: Bool
    let direction: TransitionDirection

    func body(content: Content) -> some View {
        content
            .opacity(isActive ? 1 : 0)
            .offset(x: isActive ? 0 : (direction == .forward ? 40 : -40))
            .scaleEffect(isActive ? 1 : 0.96)
            .blur(radius: isActive ? 0 : 8)
    }
}

extension View {
    func ultraSmoothTransition(isActive: Bool, direction: TransitionDirection = .forward) -> some View {
        modifier(UltraSmoothTransition(isActive: isActive, direction: direction))
    }
}
