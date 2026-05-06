//
//  OneTimeOnBoarding.swift
//  myfidpass
//
//  Adapté de User-Tutorial-Screen (Balaji Venkatesh, 10/08/25).
//  Version multi-écran : re-snapshot à chaque changement d'étape via onBeforeStep.
//

import SwiftUI
import UIKit

/// Tutoriel d'accueil (overlay) : `true` = désactivé temporairement. Repasser à `false` pour réactiver l'overlay et le bouton « Relancer le tutoriel ».
enum HomeTutorialTemporaryDisable {
    static let isOn = true
}

// MARK: - Modèle item

fileprivate struct OnBoardingItem: Identifiable {
    var id: Int
    var view: AnyView
    var maskLocation: CGRect
    var cornerRadius: CGFloat
}

// MARK: - Coordinator

@Observable
fileprivate class OnBoardingCoordinator {
    var items: [OnBoardingItem] = []
    var isOnBoardingFinished: Bool = false
    /// Snapshot courant affiché dans l'overlay (mis à jour à chaque étape).
    var currentSnapshot: UIImage?
    /// Appelé avant d'afficher l'étape `step` (index 0-based dans orderedItems) — navigation, attente, etc.
    var onBeforeStep: ((Int) async -> Void)?

    var orderedItems: [OnBoardingItem] {
        items.sorted { $0.id < $1.id }
    }
}

// MARK: - Coordinator fourni quand l’overlay tutoriel est **désactivé**

/// Si `HomeTutorialTemporaryDisable` saute `OneTimeOnBoarding`, le contenu des onglets reçoit quand
/// même un `OnBoardingCoordinator` — les modificateurs `.onBoarding()` sur `DashboardView`, etc. lisent
/// `@Environment(OnBoardingCoordinator.self)` : sans cela, l’app plante au 1ʳᵉ layout.
struct OnBoardingEnvironmentPlaceholder<Content: View>: View {
    @ViewBuilder var content: () -> Content
    @State private var coordinator = OnBoardingCoordinator()

    var body: some View {
        content()
            .environment(coordinator)
    }
}

// MARK: - Wrapper principal

struct OneTimeOnBoarding<Content: View>: View {
    @AppStorage var isOnBoarded: Bool
    @EnvironmentObject private var tabRouter: MainTabRouter
    var content: Content
    var beginOnboarding: () async -> Void
    var onBoardingFinished: () -> Void
    /// Callback appelé avant d'afficher chaque étape (index 0-based). Permet de naviguer vers le bon onglet puis de laisser le temps au snapshot.
    var onBeforeStep: ((Int) async -> Void)?

    init(
        appStorageID: String,
        @ViewBuilder content: @escaping () -> Content,
        beginOnboarding: @escaping () async -> Void,
        onBoardingFinished: @escaping () -> Void,
        onBeforeStep: ((Int) async -> Void)? = nil
    ) {
        self._isOnBoarded = .init(wrappedValue: false, appStorageID)
        self.content = content()
        self.beginOnboarding = beginOnboarding
        self.onBoardingFinished = onBoardingFinished
        self.onBeforeStep = onBeforeStep
    }

    // @State préserve le coordinator entre les re-renders du parent.
    @State private var coordinator = OnBoardingCoordinator()
    /// Tant que vrai, le contenu sous-jacent (onglets) ne reçoit **aucun** toucher — évite d’agir sur la
    /// pastille d’essai / paywall / UI située *au-dessus* ou derrière (plus de 2e UIWindow).
    @State private var tutorialAbsorbsAllTouches = false
    /// Calque plein écran le temps d’enregistrer la géométrie des onglets + 1ʳᵉ capture (évite l’enchaînement d’onglets visible).
    @State private var hidesAppDuringTutorialPreparation = false
    /// Accueil visible pleinement, avec une entrée douce (offset) avant le tutoriel — pas d’assombrissement.
    @State private var homePrewarmPresentation = false

    private var homeIntroOffsetY: CGFloat {
        if isOnBoarded { return 0 }
        return homePrewarmPresentation ? 0 : 12
    }

    var body: some View {
        ZStack {
            content
                .environment(coordinator)
                .transaction { tx in
                    if tabRouter.isTutorialTabPriming { tx.disablesAnimations = true }
                }
                .offset(y: homeIntroOffsetY)
                /// Bloque toute l’app sous le tutoriel (même feuilles / surcouches parentes non maîtrisées 100 %).
                .allowsHitTesting(!tutorialAbsorbsAllTouches)
            if tutorialAbsorbsAllTouches, coordinator.currentSnapshot != nil {
                HomeTutorialOverlayContent()
                    .environment(coordinator)
                    .zIndex(20_000)
            }
            if hidesAppDuringTutorialPreparation {
                // Fond système (pas un noir) : on masque le « pilote auto » des onglets, sans ressembler à un plantage.
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()
                    .allowsHitTesting(true)
                    .zIndex(20_001)
            }
        }
        .onAppear {
            if isOnBoarded {
                homePrewarmPresentation = true
            } else {
                withAnimation(MerchantMotion.contentReveal) {
                    homePrewarmPresentation = true
                }
            }
        }
        .task {
            if !isOnBoarded {
                // D’abord l’onglet 0 (Accueil) seul, avec animation — puis **1 s** calme avant
                // toute capture / cycle d’onglets (évite le flash « bricolage technique »).
                try? await Task.sleep(for: .seconds(1))
                await MainActor.run {
                    tabRouter.isTutorialTabPriming = true
                    hidesAppDuringTutorialPreparation = true
                }
                await beginOnboarding()
                // Indispensable : le snapshot est pris **pendant** `createWindow()`. Tant que ce
                // calque est actif, `drawHierarchy` capte l’écran de masquage (noir) au lieu du
                // dashboard — 1ʳᵉ étape = carte noire. On lève le masque **avant** la capture.
                await MainActor.run {
                    hidesAppDuringTutorialPreparation = false
                }
                // 1–2 frames + marge (carte / WebView / images) pour que l’image réelle se peigne.
                try? await Task.sleep(nanoseconds: 320_000_000)
            }
            await mountTutorialInAppOverlay()
            await MainActor.run {
                tabRouter.isTutorialTabPriming = false
            }
        }
        .onChange(of: coordinator.isOnBoardingFinished) { _, newValue in
            if newValue {
                isOnBoarded = true
                tutorialAbsorbsAllTouches = false
                coordinator.currentSnapshot = nil
                onBoardingFinished()
            }
        }
    }

    /// Tutoriel **dans** la même `UIWindow` : plus de 2e fenêtre (les touchers tombaient sur le paywall / pastille).
    private func mountTutorialInAppOverlay() async {
        guard !isOnBoarded else { return }

        coordinator.onBeforeStep = onBeforeStep

        try? await Task.sleep(for: .seconds(0.1))

        if coordinator.items.isEmpty {
            return
        }

        if let prep = coordinator.onBeforeStep {
            await prep(0)
        }

        let snapshot = await MainActor.run { tutorialSnapshotMainAppWindow() }
        guard let snapshot else { return }
        await MainActor.run {
            coordinator.currentSnapshot = snapshot
            tutorialAbsorbsAllTouches = true
        }
    }
}

// MARK: - Modificateur .onBoarding()

extension View {
    @ViewBuilder
    func onBoarding<Content: View>(
        _ position: Int,
        cornerRadius: CGFloat = 35,
        /// Décalage visuel appliqué via `.offset()` sur la vue parente : `.offset()` est purement
        /// visuel et ne modifie pas `frame(in: .global)`, donc le masque doit être ajusté manuellement.
        visualOffset: CGSize = .zero,
        /// Resserre le trou de lumière (valeurs **positives** = rétrécit le rect par rapport au `frame` mesuré).
        /// Utile quand le modificateur est sur un `Button` plein largeur alors que seule la carte est visible.
        maskInsets: EdgeInsets = EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0),
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        self.modifier(OnBoardingItemSetter(
            position: position,
            cornerRadius: cornerRadius,
            visualOffset: visualOffset,
            maskInsets: maskInsets,
            onBoardingContent: content
        ))
    }
}

fileprivate struct OnBoardingItemSetter<OnBoardingContent: View>: ViewModifier {
    var position: Int
    var cornerRadius: CGFloat
    var visualOffset: CGSize = .zero
    var maskInsets: EdgeInsets = EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
    @ViewBuilder var onBoardingContent: OnBoardingContent

    @Environment(OnBoardingCoordinator.self) var coordinator
    /// Dernier rect valide connu : permet de re-enregistrer l'item dans onAppear sans attendre
    /// onGeometryChange (qui ne se déclenche que si la géométrie change).
    @State private var lastRect: CGRect = .zero

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGRect.self) {
                $0.frame(in: .global)
            } action: { newValue in
                guard newValue.width > 10, newValue.height > 10 else { return }
                lastRect = newValue
                register(rect: newValue)
            }
            .onAppear {
                // onGeometryChange ne se re-déclenche pas si la géométrie n'a pas changé
                // (ex : reset du tutoriel, l'onglet re-apparaît avec le même layout).
                // onAppear garantit que l'item est bien enregistré dans le nouveau coordinator.
                guard lastRect.width > 10 else { return }
                register(rect: lastRect)
            }
        // No onDisappear removal: items must survive tab switches so that all tabs'
        // items stay registered for the single multi-tab tutorial overlay.
    }

    private func register(rect: CGRect) {
        let l = maskInsets.leading
        let t = maskInsets.top
        let b = maskInsets.bottom
        let r = maskInsets.trailing
        let w = max(24, rect.width - l - r)
        let h = max(24, rect.height - t - b)
        let adjusted = CGRect(
            x: rect.minX + visualOffset.width + l,
            y: rect.minY + visualOffset.height + t,
            width: w,
            height: h
        )
        coordinator.items.removeAll(where: { $0.id == position })
        coordinator.items.append(OnBoardingItem(
            id: position,
            view: .init(onBoardingContent),
            maskLocation: adjusted,
            cornerRadius: cornerRadius
        ))
    }
}

// MARK: - Bouton retour (style material — le Suivant utilise `LiquidGlassCapsuleButtonModifier`)

fileprivate struct HomeTutorialOverlayBackButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        return configuration.label
            .background {
                ZStack {
                    Circle().fill(.ultraThinMaterial)
                    Circle().fill(LiquidGlassNativeTint.darkRegular.opacity(0.88))
                }
            }
            .clipShape(Circle())
            .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
            .scaleEffect(pressed ? 0.94 : 1)
    }
}

// MARK: - Overlay (même arbre que l’app — plein écran, absorbe les touchers)

fileprivate struct HomeTutorialOverlayContent: View {
    @Environment(OnBoardingCoordinator.self) var coordinator
    @State private var animate: Bool = false
    @State private var currentIndex: Int = 0
    @State private var isTransitioning: Bool = false
    /// Spinner seulement si l’étape met > ~200 ms (évite un flash inutile sur transitions rapides).
    @State private var showStepTransitionSpinner: Bool = false

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
                .contentShape(Rectangle())
            GeometryReader { proxy in
                let safeArea = proxy.safeAreaInsets
                let isHomeButtoniPhone = safeArea.bottom == 0
                let cornerRadius: CGFloat = isHomeButtoniPhone ? 15 : 35

                ZStack {
                    Rectangle()
                        .fill(.black.opacity(0.001))
                        .contentShape(Rectangle())

                    if let snapshot = coordinator.currentSnapshot {
                        // Les boutons doivent être **au-dessus** de l’image (pas en `.background`) sinon
                        // l’`Image` plein cadre capte les touchers et « Suivant » ne réagit pas.
                        ZStack(alignment: .bottom) {
                            Image(uiImage: snapshot)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .overlay {
                                    Rectangle()
                                        .fill(.black.opacity(0.5))
                                        .reverseMask(alignment: .topLeading) {
                                            if !orderedItems.isEmpty, currentIndex < orderedItems.count {
                                                let item = orderedItems[currentIndex]
                                                RoundedRectangle(cornerRadius: item.cornerRadius, style: .continuous)
                                                    .frame(width: item.maskLocation.width, height: item.maskLocation.height)
                                                    .offset(x: item.maskLocation.minX, y: item.maskLocation.minY)
                                            }
                                        }
                                        .opacity(animate ? 1 : 0)
                                }
                                .clipShape(.rect(cornerRadius: animate ? cornerRadius : 0, style: .circular))
                                .overlay { iPhoneShape(safeArea) }
                                .scaleEffect(animate ? 0.65 : 1, anchor: .top)
                                .offset(y: animate ? safeArea.top + 25 : 0)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .allowsHitTesting(false)

                            bottomView(safeArea)
                                .zIndex(1_000)
                        }
                    }
                }
                .ignoresSafeArea()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            guard !animate else { return }
            // Ressort « smooth » + image plein écran = saccades sur appareil moins récent.
            withAnimation(.easeInOut(duration: 0.32)) {
                animate = true
            }
        }
    }

    @ViewBuilder
    private func iPhoneShape(_ safeArea: EdgeInsets) -> some View {
        let isHomeButtoniPhone = safeArea.bottom == 0
        let cornerRadius: CGFloat = isHomeButtoniPhone ? 20 : 45

        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: animate ? cornerRadius : 0, style: .continuous)
                .stroke(.white, lineWidth: animate ? 15 : 0)
                .padding(-6)
            if safeArea.bottom != 0 {
                Capsule()
                    .fill(.black)
                    .frame(width: 120, height: 40)
                    .offset(y: 20)
                    .opacity(animate ? 1 : 0)
            }
        }
    }

    @ViewBuilder
    private func bottomView(_ safeArea: EdgeInsets) -> some View {
        VStack(spacing: 10) {
            ZStack {
                ForEach(orderedItems) { info in
                    if currentIndex == orderedItems.firstIndex(where: { $0.id == info.id }) {
                        info.view
                            .transition(.opacity)
                            .environment(\.colorScheme, .dark)
                    }
                }
            }
            .frame(minHeight: 100)
            .frame(maxWidth: 300)

            HStack(spacing: 6) {
                if currentIndex > 0 {
                    Button {
                        navigateTo(currentIndex - 1)
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .contentShape(Circle())
                    }
                    .buttonStyle(HomeTutorialOverlayBackButtonStyle())
                    .disabled(isTransitioning)
                }

                Button {
                    if currentIndex == orderedItems.count - 1 {
                        completeTutorial()
                    } else {
                        navigateTo(currentIndex + 1)
                    }
                } label: {
                    HStack(spacing: 10) {
                        Text(currentIndex == orderedItems.count - 1 ? "Terminer" : "Suivant")
                            .font(.body.weight(.semibold))
                            .contentTransition(.numericText())
                        if showStepTransitionSpinner {
                            ProgressView()
                                .tint(.white)
                                .controlSize(.small)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .foregroundStyle(.white)
                    .opacity(isTransitioning ? 0.92 : 1)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 12)
                    .contentShape(Capsule())
                }
                .modifier(LiquidGlassCapsuleButtonModifier(tint: LiquidGlassNativeTint.darkRegular, controlSize: .regular))
                .disabled(isTransitioning)
            }
            .frame(maxWidth: 300)
            .padding(.leading, currentIndex > 0 ? -45 : 0)
        }
        .padding(.horizontal, 15)
        .padding(.bottom, safeArea.bottom + 10)
    }

    /// Navigue vers une étape : appelle onBeforeStep, re-snapshot, puis avance.
    /// Tout le travail async est **@MainActor** : sinon `drawHierarchy` / fin de transition peuvent partir
    /// d’un pool d’exécution arbitraire → UIKit plante silencieusement et `isTransitioning` ne repasse jamais à `false`.
    private func navigateTo(_ targetIndex: Int) {
        guard !isTransitioning else { return }
        isTransitioning = true
        showStepTransitionSpinner = false
        Task { @MainActor in
            let spinnerTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(220))
                guard !Task.isCancelled else { return }
                if isTransitioning { showStepTransitionSpinner = true }
            }
            defer {
                spinnerTask.cancel()
                showStepTransitionSpinner = false
                withAnimation(.easeInOut(duration: 0.28)) {
                    if targetIndex < orderedItems.count {
                        currentIndex = targetIndex
                    }
                }
                isTransitioning = false
            }
            if let prep = coordinator.onBeforeStep {
                await prep(targetIndex)
            }
            if let newSnap = tutorialSnapshotMainAppWindow() {
                coordinator.currentSnapshot = newSnap
            }
        }
    }

    private func completeTutorial() {
        withAnimation(.easeInOut(duration: 0.25), completionCriteria: .removed) {
            animate = false
        } completion: {
            coordinator.isOnBoardingFinished = true
        }
    }

    var orderedItems: [OnBoardingItem] { coordinator.orderedItems }
}

// MARK: - Capture écran (app principale, hors overlay tutoriel)

/// **Obligatoirement sur le main thread** : `UIGraphicsImageRenderer` / `drawHierarchy` hors MainActor = blocages / échecs silencieux quand on appuie sur « Suivant ».
@MainActor
fileprivate func tutorialSnapshotMainAppWindow() -> UIImage? {
    guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return nil }
    // Exclure la fenêtre toast `PassThroughWindow` (tag 1009) — pas le contenu des onglets.
    let pool = scene.windows.filter { $0.tag != 1009 && !$0.isHidden }
    let window: UIWindow? = {
        let normals = pool.filter { $0.windowLevel == .normal }
        let candidates = normals.isEmpty ? pool : normals
        return candidates.max(by: { $0.bounds.width * $0.bounds.height < $1.bounds.width * $1.bounds.height })
    }()
    guard let window else { return nil }
    let renderer = UIGraphicsImageRenderer(size: window.bounds.size)
    return renderer.image { _ in
        window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
    }
}

// MARK: - Extensions utilitaires

extension View {

    @ViewBuilder
    fileprivate func reverseMask<Content: View>(
        alignment: Alignment = .center,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        self.mask {
            Rectangle()
                .overlay(alignment: alignment) {
                    content().blendMode(.destinationOut)
                }
        }
    }
}
