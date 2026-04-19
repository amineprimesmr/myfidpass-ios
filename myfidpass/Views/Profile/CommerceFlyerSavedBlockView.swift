//
//  CommerceFlyerSavedBlockView.swift
//  myfidpass
//
//  Bloc checklist Commerce : aperçu « Flyer enregistré » (tap → aperçu plein écran) une fois le flyer enregistré.
//

import SwiftUI
import UIKit
import ImageIO

/// Décode `data:image/…;base64,…` pour miniature (PNG / JPEG / WebP).
private enum CommerceFlyerDataURLImage {
    static func uiImage(fromDataURLString s: String?) -> UIImage? {
        let t = s?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard t.hasPrefix("data:image/"), let comma = t.firstIndex(of: ",") else { return nil }
        let b64 = String(t[t.index(after: comma)...])
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")
        guard let data = Data(base64Encoded: b64, options: [.ignoreUnknownCharacters]), !data.isEmpty else { return nil }
        if let u = UIImage(data: data) { return u }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cg = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        return UIImage(cgImage: cg, scale: UIScreen.main.scale, orientation: .up)
    }
}

/// Présente `UIActivityViewController` depuis le VC racine — pas comme contenu d’une `.sheet` SwiftUI (écran noir / rendu incorrect sur iOS récents).
private enum CommerceNativeSharePresenter {
    @MainActor
    static func present(activityItems: [Any]) {
        guard !activityItems.isEmpty else { return }
        let vc = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        guard let anchor = topViewController() else { return }
        if let pop = vc.popoverPresentationController {
            pop.sourceView = anchor.view
            pop.sourceRect = CGRect(
                x: anchor.view.bounds.midX - 0.5,
                y: anchor.view.bounds.midY - 0.5,
                width: 1,
                height: 1
            )
            pop.permittedArrowDirections = []
        }
        anchor.present(vc, animated: true)
    }

    @MainActor
    private static func topViewController(base: UIViewController? = nil) -> UIViewController? {
        let root: UIViewController? = {
            if let base { return base }
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            let scene = scenes.first { $0.activationState == .foregroundActive }
                ?? scenes.first
            let window = scene?.windows.first { $0.isKeyWindow } ?? scene?.windows.first
            return window?.rootViewController
        }()
        guard let root else { return nil }
        if let nav = root as? UINavigationController {
            return topViewController(base: nav.visibleViewController)
        }
        if let tab = root as? UITabBarController {
            return topViewController(base: tab.selectedViewController)
        }
        if let presented = root.presentedViewController {
            return topViewController(base: presented)
        }
        return root
    }
}

/// Même fichier que `custom_bg_data_url` dans les prefs : `GET …/public/flyer-custom-bg` (robuste si le GET JSON ne renvoie pas le data URL complet côté app).
private enum CommerceFlyerPublicBgThumbnail {
    static func loadUIImage(slug: String) async -> UIImage? {
        let trimmed = slug.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let enc = trimmed.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? trimmed
        let base = APIConfig.baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(base)/api/businesses/\(enc)/public/flyer-custom-bg") else { return nil }
        do {
            var req = URLRequest(url: url)
            req.timeoutInterval = 25
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, (200 ... 299).contains(http.statusCode), !data.isEmpty else { return nil }
            if let u = UIImage(data: data) { return u }
            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let cg = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
            let scale = await MainActor.run { UIScreen.main.scale }
            return UIImage(cgImage: cg, scale: scale, orientation: .up)
        } catch {
            return nil
        }
    }
}

/// Remplace la ligne « Créer le flyer » lorsque le flyer est personnalisé / enregistré.
struct CommerceFlyerSavedBlockView: View {
    @Environment(\.colorScheme) private var colorScheme

    /// Ratio canvas flyer (embed) — miniature alignée sur l’aperçu studio, pas un carré arbitraire.
    private static let flyerThumbAspect: CGFloat = 2400.0 / 3600.0
    /// Teaser : ~80 % du flyer visible ; le bas disparaît en alpha (pas de calque couleur par-dessus).
    private static let flyerTeaserVisibleFraction: CGFloat = 0.8
    private static let flyerTeaserFadeBand: CGFloat = 0.14
    /// Hauteur max du bloc teaser (flyer un peu plus compact sur la page Commerce).
    private static let flyerTeaserMaxHeight: CGFloat = 330

    let customBgDataURL: String?
    /// Même JSON que l’éditeur (`FlyerBootstrapPreviewPayload` en base64) : QR, roue, textes, logo — pas seulement le PNG de fond.
    let bootstrapPreviewBase64: String?
    /// Slug commerce : repli miniature via endpoint public si le data URL n’est pas décodable en local.
    let businessSlug: String?
    let onOpenFlyerHub: () -> Void

    // ── Résultats calculés hors du view body (off main thread) ─────────────────
    /// UIImage décodée depuis customBgDataURL — chargée de façon asynchrone.
    @State private var cachedDataURLThumbnail: UIImage?
    /// Bootstrap sans le champ `custom_bg_data_url` (allégé pour injection WebView).
    @State private var cachedStrippedBootstrapB64: String?
    @State private var loadedPublicThumbnail: UIImage?
    @State private var isLoadingPublicThumbnail = false
    @State private var compositeWebLoading = false
    /// Évite d’afficher le fond d’un autre commerce si le slug change sans recréer la vue.
    @State private var hydratedForSlug: String?

    private var rasterThumbnail: UIImage? { cachedDataURLThumbnail ?? loadedPublicThumbnail }

    private var hasBootstrapComposite: Bool {
        let b = bootstrapPreviewBase64?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !b.isEmpty
    }

    /// Masque alpha sur la hauteur du flyer : haut opaque, puis fondu jusqu’à transparent (le bas du flyer « s’efface »).
    private static func flyerTeaserAlphaMask(visibleFraction r: CGFloat, fadeBand: CGFloat) -> LinearGradient {
        let fadeStart = max(0, r - fadeBand)
        return LinearGradient(
            stops: [
                .init(color: .white, location: 0),
                .init(color: .white, location: fadeStart),
                .init(color: .clear, location: r)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Aperçu flyer large (composite WebView + fond ou image seule).
    @ViewBuilder
    private var commerceFlyerHeroPreview: some View {
        Group {
            if hasBootstrapComposite,
               let rawB64 = bootstrapPreviewBase64?.trimmingCharacters(in: .whitespacesAndNewlines),
               !rawB64.isEmpty {
                let under: UIImage? = cachedDataURLThumbnail ?? loadedPublicThumbnail
                let webB64 = (under != nil ? cachedStrippedBootstrapB64 : nil) ?? rawB64
                ZStack {
                    if let u = under {
                        Image(uiImage: u)
                            .resizable()
                            .scaledToFit()
                    }
                    FlyerPreviewWebView(
                        bootstrapBase64: webB64,
                        isLoading: $compositeWebLoading,
                        skipCanvasSolidBackground: under != nil
                    )
                    if compositeWebLoading {
                        ProgressView()
                            .scaleEffect(1.05)
                            .tint(AppTheme.Colors.primary)
                    }
                }
                .allowsHitTesting(false)
            } else if let ui = rasterThumbnail {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFit()
            } else {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                AppTheme.Colors.textSecondary.opacity(0.06),
                                AppTheme.Colors.textSecondary.opacity(0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .aspectRatio(Self.flyerThumbAspect, contentMode: .fit)
                    .overlay {
                        if isLoadingPublicThumbnail {
                            ProgressView()
                                .scaleEffect(1.1)
                        } else {
                            VStack(spacing: 10) {
                                Image(systemName: "qrcode")
                                    .font(.system(size: 40, weight: .medium))
                                    .foregroundStyle(AppTheme.Colors.primary.opacity(0.8))
                                Text("Chargement de l’aperçu…")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(AppTheme.Colors.textSecondary)
                            }
                        }
                    }
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                GeometryReader { geo in
                    let w = geo.size.width
                    let fullH = w / Self.flyerThumbAspect
                    let r = Self.flyerTeaserVisibleFraction
                    let shownH = fullH * r
                    commerceFlyerHeroPreview
                        .frame(width: w, height: fullH, alignment: .top)
                        .mask(
                            Self.flyerTeaserAlphaMask(visibleFraction: r, fadeBand: Self.flyerTeaserFadeBand)
                        )
                        .frame(width: w, height: shownH, alignment: .top)
                        .clipped()
                }
                .aspectRatio(Self.flyerThumbAspect / Self.flyerTeaserVisibleFraction, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .frame(maxHeight: Self.flyerTeaserMaxHeight)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.14 : 0.32),
                                Color.white.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: AppTheme.Colors.shadow, radius: 22, y: 12)
            .contentShape(Rectangle())
            .onTapGesture {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onOpenFlyerHub()
            }

            VStack(spacing: 14) {
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [AppTheme.Colors.accent, AppTheme.Colors.primary],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        Text("Votre flyer de jeu est prêt")
                            .font(.system(.title3, design: .rounded, weight: .bold))
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)

                    Text("Partagez-le en magasin ou en ligne : vos clients scannent le QR, ajoutent votre carte et jouent à la roue.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .padding(.horizontal, 4)
                }

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onOpenFlyerHub()
                } label: {
                    Text("Voir le flyer")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.black, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(MerchantPressableButtonStyle())
                .accessibilityLabel("Voir le flyer")
                .accessibilityHint("Ouvre l’aperçu plein écran du flyer.")
            }
            .padding(.top, 20)
            .padding(.horizontal, 2)
        }
        .accessibilityElement(children: .contain)
        .task(
            id: CommerceFlyerHydrationFingerprint.token(
                slug: businessSlug,
                customBg: customBgDataURL,
                bootstrapB64: bootstrapPreviewBase64
            )
        ) {
            let slug = businessSlug?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !slug.isEmpty, let prev = hydratedForSlug, prev != slug {
                cachedDataURLThumbnail = nil
                cachedStrippedBootstrapB64 = nil
                loadedPublicThumbnail = nil
            }

            let bgURL = customBgDataURL
            let bgImage: UIImage?

            if let bg = bgURL, !bg.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if let mem = CommerceFlyerRasterCache.image(forCustomBgDataURL: bg) {
                    cachedDataURLThumbnail = mem
                    loadedPublicThumbnail = nil
                    isLoadingPublicThumbnail = false
                    bgImage = mem
                } else {
                    let decoded: UIImage? = await Task.detached(priority: .userInitiated) {
                        CommerceFlyerDataURLImage.uiImage(fromDataURLString: bg)
                    }.value
                    guard !Task.isCancelled else { return }
                    cachedDataURLThumbnail = decoded
                    if let decoded {
                        CommerceFlyerRasterCache.setImage(decoded, forCustomBgDataURL: bg)
                    }
                    loadedPublicThumbnail = nil
                    isLoadingPublicThumbnail = false
                    bgImage = decoded
                }
            } else {
                cachedDataURLThumbnail = nil
                if !slug.isEmpty {
                    isLoadingPublicThumbnail = true
                    let pub = await CommerceFlyerPublicBgThumbnail.loadUIImage(slug: slug)
                    guard !Task.isCancelled else { return }
                    loadedPublicThumbnail = pub
                    isLoadingPublicThumbnail = false
                    bgImage = pub
                } else {
                    isLoadingPublicThumbnail = false
                    loadedPublicThumbnail = nil
                    bgImage = nil
                }
            }

            let rawB64 = bootstrapPreviewBase64
            if bgImage != nil, let raw = rawB64, !raw.isEmpty {
                cachedStrippedBootstrapB64 = await Task.detached(priority: .userInitiated) {
                    FlyerPreviewWebView.stripCustomBgFromBootstrapBase64(raw) ?? raw
                }.value
            } else {
                cachedStrippedBootstrapB64 = rawB64
            }

            if !slug.isEmpty {
                hydratedForSlug = slug
            }
        }
    }
}

// MARK: - Aperçu plein écran (Commerce : tap « Flyer enregistré » — pas le studio IA)

/// Même rendu que la miniature checklist, en grand — sans ouvrir `MerchantProgramHubView` (formulaire création IA).
struct CommerceSavedFlyerLargePreviewView: View {
    private static let flyerAspect: CGFloat = 2400.0 / 3600.0

    let shareURL: String
    let customBgDataURL: String?
    let bootstrapPreviewBase64: String?
    let businessSlug: String?
    let onDismiss: () -> Void
    /// Après confirmation dans l’alerte : fermer cet écran et ouvrir l’assistant (parent).
    let onConfirmRecreate: () -> Void

    @State private var showRecreateConfirm = false

    // ── Résultats calculés hors du view body (off main thread) ─────────────────
    @State private var cachedDataURLThumbnail: UIImage?
    @State private var cachedStrippedBootstrapB64: String?
    @State private var compositeWebLoading = false
    @State private var loadedPublicThumbnail: UIImage?
    @State private var isLoadingPublicThumbnail = false
    @State private var hydratedForSlug: String?

    private var rasterThumbnail: UIImage? { cachedDataURLThumbnail ?? loadedPublicThumbnail }

    private var hasBootstrapComposite: Bool {
        let b = bootstrapPreviewBase64?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !b.isEmpty
    }

    private var canShare: Bool {
        if rasterThumbnail != nil { return true }
        let link = shareURL.trimmingCharacters(in: .whitespacesAndNewlines)
        return !link.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        Group {
                            if hasBootstrapComposite,
                               let rawB64 = bootstrapPreviewBase64?.trimmingCharacters(in: .whitespacesAndNewlines),
                               !rawB64.isEmpty {
                                let under: UIImage? = cachedDataURLThumbnail ?? loadedPublicThumbnail
                                let webB64 = (under != nil ? cachedStrippedBootstrapB64 : nil) ?? rawB64
                                ZStack {
                                    if let u = under {
                                        Image(uiImage: u)
                                            .resizable()
                                            .scaledToFit()
                                    }
                                    FlyerPreviewWebView(
                                        bootstrapBase64: webB64,
                                        isLoading: $compositeWebLoading,
                                        skipCanvasSolidBackground: under != nil
                                    )
                                    if compositeWebLoading {
                                        ProgressView()
                                            .tint(.white)
                                    }
                                }
                                .aspectRatio(Self.flyerAspect, contentMode: .fit)
                                .frame(maxWidth: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                                )
                            } else if let ui = rasterThumbnail {
                                Image(uiImage: ui)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: .infinity)
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            } else if isLoadingPublicThumbnail {
                                ProgressView()
                                    .tint(.white)
                                    .padding(.top, 80)
                            } else {
                                ContentUnavailableView(
                                    "Aperçu indisponible",
                                    systemImage: "doc.richtext",
                                    description: Text("Synchronisez ou rouvrez l’app dans un instant.")
                                )
                                .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal, 16)

                        Text("Pincement pour faire défiler")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.55))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)

                        VStack(spacing: 14) {
                            HStack(spacing: 12) {
                                Button {
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    let items = buildShareItems()
                                    if !items.isEmpty {
                                        CommerceNativeSharePresenter.present(activityItems: items)
                                    }
                                } label: {
                                    Label("Télécharger", systemImage: "square.and.arrow.down")
                                        .font(.subheadline.weight(.semibold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.white)
                                .foregroundStyle(.black)
                                .disabled(!canShare)

                                Button {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    showRecreateConfirm = true
                                } label: {
                                    Label("Recréer", systemImage: "arrow.triangle.2.circlepath")
                                        .font(.subheadline.weight(.semibold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                }
                                .buttonStyle(.bordered)
                                .tint(.white)
                            }

                            Text("Télécharger ouvre le partage (image + lien page clients). Recréer : une seule régénération gratuite — réfléchissez à votre brief.")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.45))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 8)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }
                    .padding(.vertical, 12)
                }
            }
            .navigationTitle("Votre flyer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") {
                        onDismiss()
                    }
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .alert("Recréer votre flyer ?", isPresented: $showRecreateConfirm) {
                Button("Annuler", role: .cancel) {}
                Button("Continuer vers l’assistant", role: .destructive) {
                    onConfirmRecreate()
                }
            } message: {
                Text(
                    "Vous n’avez droit qu’à une seule régénération gratuite avec l’assistant. Soyez précis : nom du commerce, style visuel, textes et consignes importantes. Vérifiez votre brief avant de lancer — il sera utilisé pour générer le nouveau flyer."
                )
            }
        }
        .preferredColorScheme(.dark)
        .task(
            id: CommerceFlyerHydrationFingerprint.token(
                slug: businessSlug,
                customBg: customBgDataURL,
                bootstrapB64: bootstrapPreviewBase64
            )
        ) {
            let slug = businessSlug?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !slug.isEmpty, let prev = hydratedForSlug, prev != slug {
                cachedDataURLThumbnail = nil
                cachedStrippedBootstrapB64 = nil
                loadedPublicThumbnail = nil
            }

            let bgURL = customBgDataURL
            let bgImage: UIImage?

            if let bg = bgURL, !bg.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if let mem = CommerceFlyerRasterCache.image(forCustomBgDataURL: bg) {
                    cachedDataURLThumbnail = mem
                    loadedPublicThumbnail = nil
                    isLoadingPublicThumbnail = false
                    bgImage = mem
                } else {
                    let decoded: UIImage? = await Task.detached(priority: .userInitiated) {
                        CommerceFlyerDataURLImage.uiImage(fromDataURLString: bg)
                    }.value
                    guard !Task.isCancelled else { return }
                    cachedDataURLThumbnail = decoded
                    if let decoded {
                        CommerceFlyerRasterCache.setImage(decoded, forCustomBgDataURL: bg)
                    }
                    loadedPublicThumbnail = nil
                    isLoadingPublicThumbnail = false
                    bgImage = decoded
                }
            } else {
                cachedDataURLThumbnail = nil
                if !slug.isEmpty {
                    isLoadingPublicThumbnail = true
                    let pub = await CommerceFlyerPublicBgThumbnail.loadUIImage(slug: slug)
                    guard !Task.isCancelled else { return }
                    loadedPublicThumbnail = pub
                    isLoadingPublicThumbnail = false
                    bgImage = pub
                } else {
                    isLoadingPublicThumbnail = false
                    loadedPublicThumbnail = nil
                    bgImage = nil
                }
            }

            let rawB64 = bootstrapPreviewBase64
            if bgImage != nil, let raw = rawB64, !raw.isEmpty {
                cachedStrippedBootstrapB64 = await Task.detached(priority: .userInitiated) {
                    FlyerPreviewWebView.stripCustomBgFromBootstrapBase64(raw) ?? raw
                }.value
            } else {
                cachedStrippedBootstrapB64 = rawB64
            }

            if !slug.isEmpty {
                hydratedForSlug = slug
            }
        }
    }

    private func buildShareItems() -> [Any] {
        var items: [Any] = []
        if let u = rasterThumbnail {
            items.append(u)
        }
        let link = shareURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !link.isEmpty, let url = URL(string: link) {
            items.append(url)
        }
        return items
    }
}
