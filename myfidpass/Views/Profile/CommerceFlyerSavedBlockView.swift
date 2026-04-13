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
    /// Ratio canvas flyer (embed) — miniature alignée sur l’aperçu studio, pas un carré arbitraire.
    private static let flyerThumbAspect: CGFloat = 2400.0 / 3600.0

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

    private var rasterThumbnail: UIImage? { cachedDataURLThumbnail ?? loadedPublicThumbnail }

    private var hasBootstrapComposite: Bool {
        let b = bootstrapPreviewBase64?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !b.isEmpty
    }

    var body: some View {
        Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onOpenFlyerHub()
            } label: {
                HStack(alignment: .center, spacing: 14) {
                    Group {
                        if hasBootstrapComposite,
                           let rawB64 = bootstrapPreviewBase64?.trimmingCharacters(in: .whitespacesAndNewlines),
                           !rawB64.isEmpty
                        {
                            let under: UIImage? = cachedDataURLThumbnail ?? loadedPublicThumbnail
                            // Utilise le bootstrap allégé (sans bg) si l’image bg est affichée en UIImage dessous.
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
                                        .scaleEffect(0.85)
                                }
                            }
                            .aspectRatio(Self.flyerThumbAspect, contentMode: .fit)
                            .frame(width: 76)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                            )
                            .allowsHitTesting(false)
                        } else if let ui = rasterThumbnail {
                            Image(uiImage: ui)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 76, height: 76 / Self.flyerThumbAspect)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                                )
                        } else {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(AppTheme.Colors.textSecondary.opacity(0.1))
                                .aspectRatio(Self.flyerThumbAspect, contentMode: .fit)
                                .frame(width: 76)
                                .overlay {
                                    if isLoadingPublicThumbnail {
                                        ProgressView()
                                            .scaleEffect(0.9)
                                    } else {
                                        Image(systemName: "qrcode")
                                            .font(.title2)
                                            .foregroundStyle(AppTheme.Colors.primary.opacity(0.85))
                                    }
                                }
                        }
                    }
                    .shadow(color: .black.opacity(0.12), radius: 10, y: 4)

                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(AppTheme.Colors.success)
                            Text("Flyer enregistré")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(AppTheme.Colors.textPrimary)
                        }
                        Text("Appuyez pour voir le flyer en grand")
                            .font(.caption)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(AppTheme.Colors.textSecondary.opacity(0.85))
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(AppTheme.Colors.background.opacity(0.75))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(AppTheme.Colors.textSecondary.opacity(0.15), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        .task(id: "\(bootstrapPreviewBase64 ?? "")-\(customBgDataURL ?? "")-\(businessSlug ?? "")") {
            // Réinitialise avant recalcul
            cachedDataURLThumbnail = nil
            cachedStrippedBootstrapB64 = nil
            loadedPublicThumbnail = nil

            // 1. Décode le data URL bg hors du main thread (peut être > 1 Mo de base64)
            let bgURL = customBgDataURL
            let decoded: UIImage? = await Task.detached(priority: .userInitiated) {
                CommerceFlyerDataURLImage.uiImage(fromDataURLString: bgURL)
            }.value
            cachedDataURLThumbnail = decoded

            // 2. Si pas d’image inline, charge depuis l’endpoint public
            let bgImage: UIImage?
            if let img = decoded {
                bgImage = img
                isLoadingPublicThumbnail = false
            } else if let slug = businessSlug, !slug.isEmpty {
                isLoadingPublicThumbnail = true
                let pub = await CommerceFlyerPublicBgThumbnail.loadUIImage(slug: slug)
                loadedPublicThumbnail = pub
                isLoadingPublicThumbnail = false
                bgImage = pub
            } else {
                isLoadingPublicThumbnail = false
                bgImage = nil
            }

            // 3. Strip bg du bootstrap hors main thread (parse JSON + ré-encode = coûteux)
            let rawB64 = bootstrapPreviewBase64
            if bgImage != nil, let raw = rawB64, !raw.isEmpty {
                cachedStrippedBootstrapB64 = await Task.detached(priority: .userInitiated) {
                    FlyerPreviewWebView.stripCustomBgFromBootstrapBase64(raw) ?? raw
                }.value
            } else {
                cachedStrippedBootstrapB64 = rawB64
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

    // ── Résultats calculés hors du view body (off main thread) ─────────────────
    @State private var cachedDataURLThumbnail: UIImage?
    @State private var cachedStrippedBootstrapB64: String?
    @State private var compositeWebLoading = false
    @State private var loadedPublicThumbnail: UIImage?
    @State private var isLoadingPublicThumbnail = false

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

                        Text("Pincement pour faire défiler · partagez l’image ou le lien clients")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.55))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
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
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        let items = buildShareItems()
                        if !items.isEmpty {
                            CommerceNativeSharePresenter.present(activityItems: items)
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(!canShare)
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .task(id: "\(bootstrapPreviewBase64 ?? "")-\(customBgDataURL ?? "")-\(businessSlug ?? "")") {
            cachedDataURLThumbnail = nil
            cachedStrippedBootstrapB64 = nil
            loadedPublicThumbnail = nil

            // 1. Décode le data URL bg hors du main thread
            let bgURL = customBgDataURL
            let decoded: UIImage? = await Task.detached(priority: .userInitiated) {
                CommerceFlyerDataURLImage.uiImage(fromDataURLString: bgURL)
            }.value
            cachedDataURLThumbnail = decoded

            // 2. Si pas d’image inline, charge depuis l’endpoint public
            let bgImage: UIImage?
            if let img = decoded {
                bgImage = img
                isLoadingPublicThumbnail = false
            } else if let slug = businessSlug, !slug.isEmpty {
                isLoadingPublicThumbnail = true
                let pub = await CommerceFlyerPublicBgThumbnail.loadUIImage(slug: slug)
                loadedPublicThumbnail = pub
                isLoadingPublicThumbnail = false
                bgImage = pub
            } else {
                isLoadingPublicThumbnail = false
                bgImage = nil
            }

            // 3. Strip bg du bootstrap hors main thread
            let rawB64 = bootstrapPreviewBase64
            if bgImage != nil, let raw = rawB64, !raw.isEmpty {
                cachedStrippedBootstrapB64 = await Task.detached(priority: .userInitiated) {
                    FlyerPreviewWebView.stripCustomBgFromBootstrapBase64(raw) ?? raw
                }.value
            } else {
                cachedStrippedBootstrapB64 = rawB64
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
