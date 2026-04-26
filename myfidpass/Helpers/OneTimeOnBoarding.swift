//
//  OneTimeOnBoarding.swift
//  myfidpass
//
//  Adapté de User-Tutorial-Screen (Balaji Venkatesh, 10/08/25).
//  Version multi-écran : re-snapshot à chaque changement d'étape via onBeforeStep.
//

import SwiftUI
import UIKit

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
    var overlayWindow: UIWindow?
    var isOnBoardingFinished: Bool = false
    /// Snapshot courant affiché dans l'overlay (mis à jour à chaque étape).
    var currentSnapshot: UIImage?
    /// Appelé avant d'afficher l'étape `step` (index 0-based dans orderedItems) — navigation, attente, etc.
    var onBeforeStep: ((Int) async -> Void)?

    var orderedItems: [OnBoardingItem] {
        items.sorted { $0.id < $1.id }
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
    /// Calque plein écran le temps d’enregistrer la géométrie des onglets + 1ʳᵉ capture (évite l’enchaînement d’onglets visible).
    @State private var hidesAppDuringTutorialPreparation = false

    var body: some View {
        ZStack {
            content
                .environment(coordinator)
                .transaction { tx in
                    if tabRouter.isTutorialTabPriming { tx.disablesAnimations = true }
                }
            if hidesAppDuringTutorialPreparation {
                Color(red: 0.05, green: 0.06, blue: 0.1)
                    .ignoresSafeArea()
                    .allowsHitTesting(true)
            }
        }
        .task {
            if !isOnBoarded {
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
            await createWindow()
            await MainActor.run {
                tabRouter.isTutorialTabPriming = false
            }
        }
        .onChange(of: coordinator.isOnBoardingFinished) { _, newValue in
            if newValue {
                isOnBoarded = true
                onBoardingFinished()
                hideWindow()
            }
        }
    }

    private func createWindow() async {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              !isOnBoarded,
              coordinator.overlayWindow == nil else { return }

        coordinator.onBeforeStep = onBeforeStep

        if let existing = scene.windows.first(where: { $0.tag == 1009 }) {
            existing.rootViewController = nil
            existing.isHidden = false
            existing.isUserInteractionEnabled = true
            coordinator.overlayWindow = existing
        } else {
            let window = UIWindow(windowScene: scene)
            window.backgroundColor = .clear
            window.isHidden = false
            window.isUserInteractionEnabled = true
            window.tag = 1009
            coordinator.overlayWindow = window
        }

        // Laisse onGeometryChange peupler les items.
        try? await Task.sleep(for: .seconds(0.1))

        if coordinator.items.isEmpty {
            hideWindow()
            return
        }

        // Stabilise le layout de l'étape 0 avant le snapshot initial : données résolues,
        // animations terminées, onGeometryChange à jour. Sans cet appel, le snapshot peut
        // être pris alors que la carte est encore en placeholder ou en cours d'animation.
        if let prep = coordinator.onBeforeStep {
            await prep(0)
        }

        guard let snapshot = snapshotScreen() else {
            hideWindow()
            return
        }
        coordinator.currentSnapshot = snapshot

        let hostController = UIHostingController(
            rootView: OverlayWindowView().environment(coordinator)
        )
        hostController.view.backgroundColor = .clear
        coordinator.overlayWindow?.rootViewController = hostController
    }

    private func hideWindow() {
        coordinator.overlayWindow?.rootViewController = nil
        coordinator.overlayWindow?.isHidden = true
        coordinator.overlayWindow?.isUserInteractionEnabled = false
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

// MARK: - Overlay animé

fileprivate struct OverlayWindowView: View {
    @Environment(OnBoardingCoordinator.self) var coordinator
    @State private var animate: Bool = false
    @State private var currentIndex: Int = 0
    @State private var isTransitioning: Bool = false

    var body: some View {
        GeometryReader {
            let safeArea = $0.safeAreaInsets
            let isHomeButtoniPhone = safeArea.bottom == 0
            let cornerRadius: CGFloat = isHomeButtoniPhone ? 15 : 35

            ZStack {
                Rectangle().fill(.black)

                if let snapshot = coordinator.currentSnapshot {
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
                        .background(alignment: .bottom) { bottomView(safeArea) }
                }
            }
            .ignoresSafeArea()
        }
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
            .frame(height: 70)
            .frame(maxWidth: 280)

            HStack(spacing: 6) {
                if currentIndex > 0 {
                    Button {
                        navigateTo(currentIndex - 1)
                    } label: {
                        Image(systemName: "chevron.left.circle.fill")
                            .font(.system(size: 38))
                            .foregroundStyle(.white, .gray.opacity(0.4))
                    }
                    .disabled(isTransitioning)
                }

                Button {
                    if currentIndex == orderedItems.count - 1 {
                        closeWindow()
                    } else {
                        navigateTo(currentIndex + 1)
                    }
                } label: {
                    Group {
                        if isTransitioning {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.8)
                        } else {
                            Text(currentIndex == orderedItems.count - 1 ? "Terminer" : "Suivant")
                                .fontWeight(.semibold)
                                .contentTransition(.numericText())
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(.white)
                    .padding(.vertical, 10)
                    .background(.blue.gradient, in: .capsule)
                }
                .disabled(isTransitioning)
            }
            .frame(maxWidth: 250)
            .frame(height: 50)
            .padding(.leading, currentIndex > 0 ? -45 : 0)

            Button(action: closeWindow) {
                Text("Passer")
                    .font(.callout)
                    .underline()
            }
            .foregroundStyle(.gray)
            .disabled(isTransitioning)
        }
        .padding(.horizontal, 15)
        .padding(.bottom, safeArea.bottom + 10)
    }

    /// Navigue vers une étape : appelle onBeforeStep, re-snapshot, puis avance.
    private func navigateTo(_ targetIndex: Int) {
        guard !isTransitioning else { return }
        isTransitioning = true
        Task {
            // Callback : navigation onglet, attente animation, etc.
            if let prep = coordinator.onBeforeStep {
                await prep(targetIndex)
            }
            // Nouveau snapshot après que la bonne page est visible.
            if let newSnap = snapshotScreen() {
                coordinator.currentSnapshot = newSnap
            }
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.28)) {
                    if targetIndex < orderedItems.count {
                        currentIndex = targetIndex
                    }
                }
                isTransitioning = false
            }
        }
    }

    private func closeWindow() {
        withAnimation(.easeInOut(duration: 0.25), completionCriteria: .removed) {
            animate = false
        } completion: {
            coordinator.isOnBoardingFinished = true
        }
    }

    var orderedItems: [OnBoardingItem] { coordinator.orderedItems }
}

// MARK: - Extensions utilitaires

extension View {
    fileprivate func snapshotScreen() -> UIImage? {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return nil }
        // Jamais 1009 (tutoriel). Préférer la fenêtre clé, sinon la plus grande = contenu app.
        let pool = scene.windows.filter { $0.tag != 1009 && !$0.isHidden }
        let window: UIWindow? = {
            if let w = pool.first(where: { $0.isKeyWindow }) { return w }
            return pool.max(by: { $0.bounds.width * $0.bounds.height < $1.bounds.width * $1.bounds.height })
        }()
        guard let window else { return nil }
        let renderer = UIGraphicsImageRenderer(size: window.bounds.size)
        return renderer.image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
    }

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
