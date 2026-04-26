//
//  CommerceFlyerSavedBlockView.swift
//  myfidpass
//
//  Bloc checklist Commerce : aperçu « Flyer enregistré » (tap → aperçu plein écran) une fois le flyer enregistré.
//

import SwiftUI
import UIKit
import ImageIO
import Photos

/// Décodage de l’état flyer (dégradé / voile) à partir du bootstrap embarqué.
private enum CommerceFlyerBootstrapUnderlayState {
    static func resolved(from bootstrapBase64: String?) -> FlyerStateDTO {
        let t = bootstrapBase64?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !t.isEmpty, let s = FlyerBootstrapPreviewPayloadBuilder.flyerStateFromBootstrapBase64(t) { return s }
        var d = FlyerStateDTO.default
        d.normalizeClamps()
        return d
    }
}

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

/// Enregistrement direct : photothèque + dossier Documents (exposé dans l’app Fichiers quand le partage iTunes / fichiers est activé).
private enum CommerceFlyerSaveToDevice {
    struct Outcome {
        let message: String
        let anySuccess: Bool
    }

    static func save(image: UIImage) async -> Outcome {
        var photosOK = false
        var fileOK = false
        var fileName: String?
        var errors: [String] = []

        let status = await withCheckedContinuation { (c: CheckedContinuation<PHAuthorizationStatus, Never>) in
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { c.resume(returning: $0) }
        }
        if status == .authorized {
            do {
                try await PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                }
                photosOK = true
            } catch {
                errors.append("Photos : \(error.localizedDescription)")
            }
        } else {
            // Accès refusé : rappelé plus bas si l’enregistrement disque a réussi.
        }

        do {
            let (_, name) = try writeJpegToDocumentsFolder(image: image)
            fileOK = true
            fileName = name
        } catch {
            errors.append("Fichier : \(error.localizedDescription)")
        }

        var parts: [String] = []
        if photosOK {
            parts.append("L’image a été enregistrée dans votre photothèque (Photos).")
        }
        if fileOK, let name = fileName {
            parts.append("Un fichier a été enregistré : « \(name) ». Ouvrez l’app Fichiers, onglet « Sur mon iPhone », dossier « MyFidpass », sous-dossier « Flyer ».")
        }
        if !photosOK, fileOK, status != .authorized {
            parts.append("L’enregistrement dans Photos a été refusé. Vous pouvez l’autoriser dans Réglages > MyFidpass > Photos (ajout à la photothèque).")
        }
        if !photosOK, !fileOK, status == .authorized {
            parts.append(contentsOf: errors)
        }
        if !photosOK, !fileOK, status != .authorized {
            if errors.isEmpty {
                parts.append("L’enregistrement dans Photos a été refusé et le fichier n’a pas pu être créé. Vérifiez l’espace de stockage et les autorisations dans Réglages > MyFidpass > Photos.")
            } else {
                parts = errors
            }
        } else if !fileOK, photosOK {
            parts.append(contentsOf: errors)
        }
        if parts.isEmpty {
            parts = ["Enregistrement impossible. Réessayez plus tard."]
        }
        return Outcome(
            message: parts.joined(separator: "\n\n"),
            anySuccess: photosOK || fileOK
        )
    }

    private static func writeJpegToDocumentsFolder(image: UIImage) throws -> (URL, String) {
        guard let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw NSError(domain: "CommerceFlyer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Dossier documents indisponible."])
        }
        let flyer = dir.appendingPathComponent("Flyer", isDirectory: true)
        try FileManager.default.createDirectory(at: flyer, withIntermediateDirectories: true)
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = TimeZone.current
        fmt.dateFormat = "yyyy-MM-dd-HHmmss"
        let name = "MyFidpass-flyer-\(fmt.string(from: Date())).jpg"
        let url = flyer.appendingPathComponent(name)
        guard let data = image.jpegData(compressionQuality: 0.92) else {
            throw NSError(domain: "CommerceFlyer", code: 2, userInfo: [NSLocalizedDescriptionKey: "Export JPEG indisponible."])
        }
        try data.write(to: url, options: .atomic)
        return (url, name)
    }
}

/// Même fichier que `custom_bg_data_url` dans les prefs : `GET …/public/flyer-custom-bg` (robuste si le GET JSON ne renvoie pas le data URL complet côté app).
private enum CommerceFlyerPublicBgThumbnail {
    private static func uiImageFromImageData(_ data: Data, screenScale: CGFloat) -> UIImage? {
        if let u = UIImage(data: data) { return u }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cg = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        return UIImage(cgImage: cg, scale: screenScale, orientation: .up)
    }

    /// Mémoire → disque (dernier GET) → réseau ; remplit cache pour la prochaine ouverture Commerce.
    static func loadUIImage(slug: String) async -> UIImage? {
        let trimmed = slug.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let mem = CommerceFlyerRasterCache.image(forPublicFlyerBgSlug: trimmed) {
            return mem
        }
        let screenScale = await MainActor.run { UIScreen.main.scale }
        if let disk = CommerceFlyerStateCache.readPublicFlyerBackgroundImageData(slug: trimmed) {
            let ui = await Task.detached(priority: .userInitiated) {
                uiImageFromImageData(disk, screenScale: screenScale)
            }.value
            if let ui {
                await MainActor.run { CommerceFlyerRasterCache.setPublicFlyerBgImage(ui, slug: trimmed) }
                return ui
            }
        }
        let enc = trimmed.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? trimmed
        let base = APIConfig.baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(base)/api/businesses/\(enc)/public/flyer-custom-bg") else { return nil }
        do {
            var req = URLRequest(url: url)
            req.timeoutInterval = 25
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, (200 ... 299).contains(http.statusCode), !data.isEmpty else { return nil }
            let ui = await Task.detached(priority: .userInitiated) {
                uiImageFromImageData(data, screenScale: screenScale)
            }.value
            guard let ui else { return nil }
            await MainActor.run {
                CommerceFlyerRasterCache.setPublicFlyerBgImage(ui, slug: trimmed)
            }
            CommerceFlyerStateCache.writePublicFlyerBackgroundImageData(data, slug: trimmed)
            return ui
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
    @State private var cachedUnderlayState: FlyerStateDTO = CommerceFlyerBootstrapUnderlayState.resolved(from: nil)

    private var rasterThumbnail: UIImage? { cachedDataURLThumbnail ?? loadedPublicThumbnail }

    /// Lecture disque + mémoire (sans attente async) : fond IA visible dès le 1ʳᵉ frame si déjà en cache.
    private func syncHydratePublicBgFromCachesIfNeeded() {
        let slug = businessSlug?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !slug.isEmpty, loadedPublicThumbnail == nil, cachedDataURLThumbnail == nil else { return }
        if let mem = CommerceFlyerRasterCache.image(forPublicFlyerBgSlug: slug) {
            loadedPublicThumbnail = mem
            isLoadingPublicThumbnail = false
            return
        }
        guard let d = CommerceFlyerStateCache.readPublicFlyerBackgroundImageData(slug: slug) else { return }
        let scale = UIScreen.main.scale
        let ui: UIImage? = {
            if let u = UIImage(data: d) { return u }
            guard let source = CGImageSourceCreateWithData(d as CFData, nil),
                  let cg = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
            return UIImage(cgImage: cg, scale: scale, orientation: .up)
        }()
        if let ui {
            loadedPublicThumbnail = ui
            CommerceFlyerRasterCache.setPublicFlyerBgImage(ui, slug: slug)
            isLoadingPublicThumbnail = false
        }
        let rawT = bootstrapPreviewBase64?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !rawT.isEmpty {
            cachedUnderlayState = CommerceFlyerBootstrapUnderlayState.resolved(from: rawT)
        }
    }

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
                        FlyerNativeUnderlayStack(state: cachedUnderlayState, image: u)
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
            .onAppear { syncHydratePublicBgFromCachesIfNeeded() }

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
                            .font(.system(.title3, design: .default, weight: .bold))
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

            cachedUnderlayState = CommerceFlyerBootstrapUnderlayState.resolved(from: rawB64)

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
    /// Ferme l’aperçu et ouvre le hub Flyer (textes, couleurs, aperçu — comme « Modifier » dans le studio).
    let onEditFlyer: () -> Void
    /// Après confirmation dans l’alerte : fermer cet écran et ouvrir l’assistant (parent).
    let onConfirmRecreate: () -> Void

    @State private var showRecreateConfirm = false
    @State private var isSavingFlyerDownload = false
    @State private var showDownloadResult = false
    @State private var downloadResultText = ""

    // ── Résultats calculés hors du view body (off main thread) ─────────────────
    @State private var cachedDataURLThumbnail: UIImage?
    @State private var cachedStrippedBootstrapB64: String?
    @State private var compositeWebLoading = false
    @State private var loadedPublicThumbnail: UIImage?
    @State private var isLoadingPublicThumbnail = false
    @State private var hydratedForSlug: String?
    @State private var cachedUnderlayState: FlyerStateDTO = CommerceFlyerBootstrapUnderlayState.resolved(from: nil)

    private var rasterThumbnail: UIImage? { cachedDataURLThumbnail ?? loadedPublicThumbnail }

    private var hasBootstrapComposite: Bool {
        let b = bootstrapPreviewBase64?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !b.isEmpty
    }

    private var canSaveFlyerToDevice: Bool { rasterThumbnail != nil }

    private var commerceRecreateRegenerationAlreadyUsed: Bool {
        let s = businessSlug?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !s.isEmpty else { return false }
        return FlyerCommerceRecreateOnceGuard.hasConsumedRegenerateSession(slug: s)
    }

    private func largePreviewSyncHydratePublicBgFromCachesIfNeeded() {
        let slug = businessSlug?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !slug.isEmpty, loadedPublicThumbnail == nil, cachedDataURLThumbnail == nil else { return }
        if let mem = CommerceFlyerRasterCache.image(forPublicFlyerBgSlug: slug) {
            loadedPublicThumbnail = mem
            isLoadingPublicThumbnail = false
        } else if let d = CommerceFlyerStateCache.readPublicFlyerBackgroundImageData(slug: slug) {
            let scale = UIScreen.main.scale
            let ui: UIImage? = {
                if let u = UIImage(data: d) { return u }
                guard let source = CGImageSourceCreateWithData(d as CFData, nil),
                      let cg = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
                return UIImage(cgImage: cg, scale: scale, orientation: .up)
            }()
            if let ui {
                loadedPublicThumbnail = ui
                CommerceFlyerRasterCache.setPublicFlyerBgImage(ui, slug: slug)
                isLoadingPublicThumbnail = false
            }
        }
        let rawT = bootstrapPreviewBase64?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !rawT.isEmpty {
            cachedUnderlayState = CommerceFlyerBootstrapUnderlayState.resolved(from: rawT)
        }
    }

    @MainActor
    private func performFlyerDownload() async {
        guard let image = rasterThumbnail, !isSavingFlyerDownload else { return }
        isSavingFlyerDownload = true
        let outcome = await CommerceFlyerSaveToDevice.save(image: image)
        isSavingFlyerDownload = false
        downloadResultText = outcome.message
        showDownloadResult = true
        UINotificationFeedbackGenerator().notificationOccurred(outcome.anySuccess ? .success : .error)
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
                                        FlyerNativeUnderlayStack(state: cachedUnderlayState, image: u)
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

                        HStack(spacing: 12) {
                            Button {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                Task { await performFlyerDownload() }
                            } label: {
                                Group {
                                    if isSavingFlyerDownload {
                                        HStack(spacing: 8) {
                                            ProgressView()
                                                .tint(.black)
                                            Text("Enregistrement…")
                                        }
                                    } else {
                                        Label("Télécharger", systemImage: "square.and.arrow.down")
                                    }
                                }
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.white)
                            .foregroundStyle(.black)
                            .disabled(!canSaveFlyerToDevice || isSavingFlyerDownload)

                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                guard !commerceRecreateRegenerationAlreadyUsed else { return }
                                showRecreateConfirm = true
                            } label: {
                                Label("Recréer", systemImage: "arrow.triangle.2.circlepath")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                            }
                            .buttonStyle(.bordered)
                            .tint(.white)
                            .disabled(commerceRecreateRegenerationAlreadyUsed)
                            .opacity(commerceRecreateRegenerationAlreadyUsed ? 0.4 : 1)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }
                    .padding(.vertical, 12)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack {
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            onDismiss()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 40, height: 40)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Retour")
                        .glassStyleDark(cornerRadius: 20)
                        Spacer()
                    }
                    .frame(width: 120, alignment: .leading)
                }
                ToolbarItem(placement: .principal) {
                    Text("Votre flyer")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack {
                        Spacer()
                        Button {
                            onEditFlyer()
                        } label: {
                            Text("Modifier")
                                .fontWeight(.semibold)
                        }
                        .tint(AppTheme.Colors.primary)
                    }
                    .frame(width: 120, alignment: .trailing)
                }
            }
            .onAppear { largePreviewSyncHydratePublicBgFromCachesIfNeeded() }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .alert("Téléchargement", isPresented: $showDownloadResult) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(downloadResultText)
            }
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

            cachedUnderlayState = CommerceFlyerBootstrapUnderlayState.resolved(from: rawB64)

            if !slug.isEmpty {
                hydratedForSlug = slug
            }
        }
    }

}

// MARK: - Précache GET public (remplit le fichier disque pour l’ouverture suivante de l’onglet Commerce)

enum CommerceFlyerPublicBackgroundWarmup {
    /// Quand le dashboard ne fournit pas de `data:` complet, l’app charge `…/public/flyer-custom-bg` : on remplit le cache tôt.
    static func prefetchFromNetworkIfNoCustomBgInPrefs(slug: String, customBgDataUrl: String?) {
        let c = (customBgDataUrl ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !c.isEmpty { return }
        let s = slug.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return }
        Task(priority: .utility) {
            if CommerceFlyerRasterCache.image(forPublicFlyerBgSlug: s) != nil { return }
            if CommerceFlyerStateCache.readPublicFlyerBackgroundImageData(slug: s) != nil { return }
            _ = await CommerceFlyerPublicBgThumbnail.loadUIImage(slug: s)
        }
    }
}
