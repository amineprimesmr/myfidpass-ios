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

    /// Pastille rouge menu / navigation — persiste même si la feuille promo a été fermée sans créer le flyer.
    static func showsCreationAttentionBadge(for slugRaw: String?) -> Bool {
        guard let slugRaw else { return false }
        return stillNeedsFlyerPromo(for: slugRaw)
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
struct PostCardFlyerPromoSheet: View {
    let slug: String
    @Binding var isPresented: Bool
    var onCreateFlyerTapped: () -> Void

    private static let contentHorizontalInset: CGFloat = 22
    private static let imageCornerRadius: CGFloat = 40
    /// Aperçu flyer — large et coins bien arrondis.
    private static let previewMaxHeight: CGFloat = 368
    private static let sectionSpacing: CGFloat = 20

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            titleSection
                .padding(.bottom, Self.sectionSpacing)

            flyersheetPreview
                .frame(maxWidth: .infinity)

            Spacer(minLength: 28)

            createFlyerSlider
        }
        .padding(.horizontal, Self.contentHorizontalInset)
        .padding(.top, 28)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .safeAreaPadding(.bottom, 18)
        .accessibilityIdentifier("post_card_flyer_promo_\(slug)")
        .preferredColorScheme(.dark)
        .presentationDetents([.fraction(0.82)])
        .presentationDragIndicator(.visible)
        .presentationBackgroundInteraction(.enabled(upThrough: .fraction(0.82)))
        .modifier(LiquidGlassSheetModifier())
        .presentationBackground {
            FlyerEditorCanvasBackdrop()
                .ignoresSafeArea()
        }
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "doc.richtext.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.96))
                .symbolRenderingMode(.hierarchical)

            Text("Créez et affichez votre flyer de jeu")
                .font(.system(size: 26, weight: .bold, design: .default))
                .foregroundStyle(Color.white.opacity(0.96))
                .multilineTextAlignment(.leading)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Aperçu centré, grand format, coins arrondis.
    private var flyersheetPreview: some View {
        Image("flyersheet")
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(maxWidth: .infinity, maxHeight: Self.previewMaxHeight)
            .clipShape(RoundedRectangle(cornerRadius: Self.imageCornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Self.imageCornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.32), radius: 22, y: 12)
            .frame(maxWidth: .infinity, alignment: .center)
            .accessibilityLabel("Aperçu d’un flyer de jeu en caisse")
    }

    private var createFlyerSlider: some View {
        SlideToConfirm(config: slideConfig) {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            UIAccessibility.post(notification: .announcement, argument: "Ouverture de la création de flyer.")
            isPresented = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                onCreateFlyerTapped()
            }
        }
    }

    private var slideConfig: SlideToConfirm.Config {
        SlideToConfirm.Config(
            idleText: "Glisser pour créer le flyer",
            onSwipeText: "Créer mon flyer",
            confirmationText: "C’est parti",
            tint: AppTheme.Colors.primary,
            foregroundColor: .white,
            height: 68,
            knobPadding: 6
        )
    }
}
