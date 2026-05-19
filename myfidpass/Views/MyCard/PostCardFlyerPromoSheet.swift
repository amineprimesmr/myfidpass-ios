//
//  PostCardFlyerPromoSheet.swift
//  myfidpass
//
//  Feuille modale système (« Créer le flyer ») tant que le flyer n’est pas enregistré.
//

import SwiftUI

/// Présente la feuille « Créer le flyer » après carte complète, tant que le flyer n’est pas enregistré.
enum PostCardFlyerPromoEligibility {
    /// File : après « Ma carte » enregistrée, priorité jusqu’à l’accueil.
    private static let pendingMerchantHomeFlagKey = "myfidpass.postCardFlyerPromo.pendingMerchantHome"
    private static let pendingMerchantHomeSlugKey = "myfidpass.postCardFlyerPromo.pendingSlug"

    /// Feuille fermée sans flyer terminé : ne pas réafficher avant la prochaine ouverture d’app (retour arrière-plan).
    private static var suppressedUntilNextAppOpen = false

    private static func sanitizedSlug(_ slug: String) -> String {
        slug.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "\\", with: "_")
    }

    private static func flyerLooksRegistered(slug: String) -> Bool {
        CommerceFlyerStore.shared.hydrateFromDiskIfNeeded(slug: slug)
        if CommerceFlyerStore.shared.snapshot(for: slug)?.flyerRegistered == true { return true }
        if CommerceFlyerStateCache.load(slug: slug)?.flyerRegistered == true { return true }
        return false
    }

    /// Carte complète et flyer pas encore enregistré (sans tenir compte de la fermeture de session).
    static func stillNeedsFlyerPromo(for slugRaw: String) -> Bool {
        let slug = sanitizedSlug(slugRaw)
        guard !slug.isEmpty else { return false }
        guard CardPreviewDisplaySnapshotStore.isMerchantCardConfigured(slug: slug) else { return false }
        return !flyerLooksRegistered(slug: slug)
    }

    static func shouldOffer(for slugRaw: String) -> Bool {
        guard !suppressedUntilNextAppOpen else { return false }
        return stillNeedsFlyerPromo(for: slugRaw)
    }

    /// Appelé quand l’utilisateur quitte la feuille sans avoir finalisé le flyer (swipe ou fond).
    static func markDismissedWithoutCompletingFlyer() {
        suppressedUntilNextAppOpen = true
    }

    /// Nouvelle session utilisateur : retour depuis l’arrière-plan ou relance.
    static func resetSessionSuppressionForAppOpen() {
        suppressedUntilNextAppOpen = false
    }

    static func queuePresentationOnMerchantHome(for slugRaw: String) {
        guard stillNeedsFlyerPromo(for: slugRaw) else { return }
        let slug = sanitizedSlug(slugRaw)
        guard !slug.isEmpty else { return }
        suppressedUntilNextAppOpen = false
        UserDefaults.standard.set(true, forKey: pendingMerchantHomeFlagKey)
        UserDefaults.standard.set(slug, forKey: pendingMerchantHomeSlugKey)
    }

    static func hasQueuedPendingMerchantHomeSlug() -> Bool {
        UserDefaults.standard.bool(forKey: pendingMerchantHomeFlagKey)
    }

    static func dequeuePendingSlugIfEligible() -> String? {
        guard UserDefaults.standard.bool(forKey: pendingMerchantHomeFlagKey) else { return nil }
        let slug = sanitizedSlug(UserDefaults.standard.string(forKey: pendingMerchantHomeSlugKey) ?? "")
        clearPendingSlugQueuedForMerchantHome()
        guard !slug.isEmpty, shouldOffer(for: slug) else { return nil }
        return slug
    }

    static func clearPendingSlugQueuedForMerchantHome() {
        UserDefaults.standard.set(false, forKey: pendingMerchantHomeFlagKey)
        UserDefaults.standard.removeObject(forKey: pendingMerchantHomeSlugKey)
    }
}

/// Contenu présenté par **`UISheetPresentationController`** via SwiftUI `.sheet`.
/// Point clé : **pas de `GeometryReader` en racine** (ça cassait la largeur utile ⇒ titres coupés au milieu d’un mot).
struct PostCardFlyerPromoSheet: View {
    let slug: String
    @Binding var isPresented: Bool
    var onCreateFlyerTapped: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .center, spacing: 14) {
                Text("Créez et affichez votre flyer de jeu")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.white.opacity(0.96))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .frame(maxWidth: .infinity, alignment: .center)
                    /// Force le retour à la ligne sur toute la largeur « texte », pas une seule ligne tronquée.
                    .layoutPriority(1)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Mettez en avant vos récompenses et votre QR sur une affiche pensée pour le terrain.")
                    .font(.subheadline)
                    .foregroundStyle(Color.white.opacity(0.62))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .fixedSize(horizontal: false, vertical: true)

                createFlyerButton
                    .padding(.top, 8)
            }
            .padding(.horizontal, 24)
            /// Marge top sans poignée système : remplace l’espace que prenait `.presentationDragIndicator(.visible)`.
            .padding(.top, 26)
            .padding(.bottom, 14)
            .frame(maxWidth: .infinity)

            flyersheetHero
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        /// L’image de fond du flyer doit toucher le bord bas du sheet (sous le home indicator).
        .ignoresSafeArea(.container, edges: .bottom)
        .accessibilityIdentifier("post_card_flyer_promo_\(slug)")
        .preferredColorScheme(.dark)
        /// Un seul detent : pas de « grand » format, la feuille ne se développe pas au drag.
        .presentationDetents([.medium])
        /// Le tiret/poignée système est masqué : la promo ne doit pas paraître « brouillonne » en haut.
        .presentationDragIndicator(.hidden)
        .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        .presentationCornerRadius(28)
        .presentationBackground {
            FlyerEditorCanvasBackdrop()
                .ignoresSafeArea()
        }
    }

    private var createFlyerButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            UIAccessibility.post(notification: .announcement, argument: "Ouverture de la création de flyer.")
            isPresented = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                onCreateFlyerTapped()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "sparkles.rectangle.stack.fill")
                    .font(.system(size: 15, weight: .semibold))
                Text("Créer mon flyer")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(Color.black)
            .padding(.horizontal, 26)
            .padding(.vertical, 13)
            .background(Color.white, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    /// Bande basse : l’image remplit toute la place restante sous le bouton et descend jusqu’au bord du sheet.
    private var flyersheetHero: some View {
        GeometryReader { geo in
            let bleed: CGFloat = 6
            let w = geo.size.width + bleed * 2
            ZStack(alignment: .top) {
                Image("flyersheet")
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fill)
                    .frame(width: w, height: geo.size.height, alignment: .top)
                    .clipped()

                FlyersheetCupolaFadeOverlay(canvasColor: FlyerEditorSurfaceColors.canvas, referenceWidth: geo.size.width)
            }
            .frame(width: w, height: geo.size.height, alignment: .top)
            .offset(x: -bleed)
        }
        .clipped()
    }
}

private struct FlyersheetCupolaFadeOverlay: View {
    let canvasColor: Color
    let referenceWidth: CGFloat

    var body: some View {
        ZStack {
            RadialGradient(
                stops: [
                    .init(color: canvasColor.opacity(1), location: 0),
                    .init(color: canvasColor.opacity(0.78), location: 0.2),
                    .init(color: canvasColor.opacity(0.42), location: 0.4),
                    .init(color: canvasColor.opacity(0.06), location: 0.58),
                    .init(color: Color.clear, location: 1),
                ],
                center: UnitPoint(x: 0.5, y: 0),
                startRadius: 4,
                endRadius: referenceWidth * 0.74
            )
            .scaleEffect(x: 1.02, y: 0.34, anchor: .top)

            LinearGradient(
                stops: [
                    .init(color: canvasColor.opacity(0.93), location: 0),
                    .init(color: Color.clear, location: 1),
                ],
                startPoint: UnitPoint(x: 0.02, y: 0.02),
                endPoint: UnitPoint(x: 0.55, y: 0.94)
            )
            LinearGradient(
                stops: [
                    .init(color: canvasColor.opacity(0.93), location: 0),
                    .init(color: Color.clear, location: 1),
                ],
                startPoint: UnitPoint(x: 0.98, y: 0.02),
                endPoint: UnitPoint(x: 0.45, y: 0.94)
            )

            LinearGradient(
                colors: [canvasColor.opacity(0.9), canvasColor.opacity(0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .blendMode(.softLight)
            .opacity(0.38)
            .blur(radius: 5)
        }
        .allowsHitTesting(false)
    }
}
